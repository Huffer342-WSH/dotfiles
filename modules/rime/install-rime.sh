#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_SRC="$REPO_ROOT/configs/home/.local/share/fcitx5/rime"
RIME_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/fcitx5/rime"

RIME_READY_INSTALLER="https://raw.githubusercontent.com/Huffer342-WSH/rime-ready/main/install.sh"
CONFIG_ARCHIVE_URL="https://github.com/Huffer342-WSH/dotfiles/archive/refs/heads/linux.tar.gz"
CONFIG_FETCH_MODE=auto
RUN_INSTALL=1
RUN_CONFIG=1
START_FRONTEND=1
TMP_DIR=""

usage() {
  cat <<EOF
用法：$0 [选项]

默认安装 Fcitx5、Rime、雾凇拼音和万象 Gram，然后复制本仓库中的 Rime 配置。

选项：
  --install-only          只安装输入法，不复制个人配置
  --config-only           只复制个人配置并重新部署 Rime
  --config-src DIR        本地配置目录（默认：$CONFIG_SRC）
  --rime-dir DIR          Rime 用户目录（默认：$RIME_DIR）
  --fetch-mode MODE       配置来源：auto、local、remote（默认：auto）
  --config-archive URL    远程 dotfiles 压缩包地址
  --installer FILE_OR_URL rime-ready 安装脚本路径或 URL
  --no-start              完成后不启动 Fcitx5
  -h, --help              显示帮助
EOF
}

die() {
  echo "[rime] $*" >&2
  exit 1
}

log() {
  echo "[rime] $*"
}

cleanup() {
  [[ -z $TMP_DIR ]] || rm -rf -- "$TMP_DIR"
}
trap cleanup EXIT

while (($#)); do
  case $1 in
    --install-only)
      RUN_CONFIG=0
      shift
      ;;
    --config-only)
      RUN_INSTALL=0
      shift
      ;;
    --config-src)
      CONFIG_SRC=${2:?--config-src 缺少目录}
      shift 2
      ;;
    --rime-dir)
      RIME_DIR=${2:?--rime-dir 缺少目录}
      shift 2
      ;;
    --fetch-mode)
      CONFIG_FETCH_MODE=${2:?--fetch-mode 缺少值}
      shift 2
      ;;
    --config-archive)
      CONFIG_ARCHIVE_URL=${2:?--config-archive 缺少 URL}
      shift 2
      ;;
    --installer)
      RIME_READY_INSTALLER=${2:?--installer 缺少路径或 URL}
      shift 2
      ;;
    --no-start)
      START_FRONTEND=0
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "未知参数：$1"
      ;;
  esac
done

case $CONFIG_FETCH_MODE in
  auto | local | remote) ;;
  *) die "不支持配置来源：$CONFIG_FETCH_MODE" ;;
esac
((RUN_INSTALL || RUN_CONFIG)) || die "没有需要执行的操作"
[[ $EUID -ne 0 ]] || die "请以普通桌面用户运行，不要使用 sudo"

prepare_tmp_dir() {
  if [[ -z $TMP_DIR ]]; then
    TMP_DIR=$(mktemp -d)
  fi
}

run_rime_ready() {
  local installer=$RIME_READY_INSTALLER
  local -a args=(--preset ice-gram --frontend fcitx5)

  # 默认流程要在复制个人配置后再部署和启动，避免 Fcitx5 读取中间状态。
  if ((RUN_CONFIG || !START_FRONTEND)); then
    args+=(--no-start)
  fi

  if [[ $installer =~ ^https?:// ]]; then
    command -v curl >/dev/null 2>&1 || die "下载安装脚本需要 curl"
    prepare_tmp_dir
    log "下载 rime-ready 安装脚本"
    curl -fsSL --retry 3 "$installer" -o "$TMP_DIR/rime-ready-install.sh"
    installer="$TMP_DIR/rime-ready-install.sh"
  else
    [[ -f $installer ]] || die "找不到 rime-ready 安装脚本：$installer"
  fi

  log "安装 Fcitx5、Rime、雾凇拼音和万象 Gram"
  bash "$installer" "${args[@]}"
}

download_remote_config() {
  local archive extract_root remote_config

  command -v curl >/dev/null 2>&1 || die "下载远程配置需要 curl"
  command -v tar >/dev/null 2>&1 || die "解压远程配置需要 tar"
  prepare_tmp_dir
  archive="$TMP_DIR/dotfiles.tar.gz"
  extract_root="$TMP_DIR/dotfiles"
  mkdir -p "$extract_root"

  log "下载远程 Rime 配置" >&2
  curl -fL --retry 3 "$CONFIG_ARCHIVE_URL" -o "$archive"
  tar -xzf "$archive" -C "$extract_root"
  remote_config=$(find "$extract_root" -type d \
    -path '*/configs/home/.local/share/fcitx5/rime' -print -quit)
  [[ -n $remote_config ]] || die "远程压缩包中没有 Rime 配置目录"
  printf '%s\n' "$remote_config"
}

resolve_config_src() {
  case $CONFIG_FETCH_MODE in
    local)
      [[ -d $CONFIG_SRC ]] || die "找不到本地配置目录：$CONFIG_SRC"
      printf '%s\n' "$CONFIG_SRC"
      ;;
    remote)
      download_remote_config
      ;;
    auto)
      if [[ -d $CONFIG_SRC ]]; then
        printf '%s\n' "$CONFIG_SRC"
      else
        download_remote_config
      fi
      ;;
  esac
}

stop_fcitx5() {
  if command -v fcitx5-remote >/dev/null 2>&1; then
    fcitx5-remote -e 2>/dev/null || true
    for _ in $(seq 1 40); do
      pgrep -x fcitx5 >/dev/null 2>&1 || return 0
      sleep 0.25
    done
  fi
}

start_fcitx5() {
  local cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}
  command -v fcitx5 >/dev/null 2>&1 || die "找不到 fcitx5"
  mkdir -p "$cache_dir"
  nohup fcitx5 -d >"$cache_dir/dotfiles-fcitx5.log" 2>&1 &
  log "已启动 Fcitx5"
}

copy_and_deploy_config() {
  local source_dir
  source_dir=$(resolve_config_src)

  [[ -d $RIME_DIR ]] || die "Rime 用户目录不存在，请先安装输入法：$RIME_DIR"
  command -v rime_deployer >/dev/null 2>&1 || die "找不到 rime_deployer，请先安装 Rime 工具"

  stop_fcitx5
  log "复制 Rime 配置：$source_dir -> $RIME_DIR"
  cp -a "$source_dir/." "$RIME_DIR/"

  log "重新部署 Rime"
  rm -rf "$RIME_DIR/build"
  mkdir -p "$RIME_DIR/build"
  rime_deployer --build "$RIME_DIR" /usr/share/rime-data "$RIME_DIR/build"
  [[ -f $RIME_DIR/build/rime_ice.schema.yaml ]] || die "雾凇拼音部署产物缺失"

  if ((START_FRONTEND)); then
    start_fcitx5
  else
    log "已按要求跳过启动 Fcitx5"
  fi
}

((RUN_INSTALL)) && run_rime_ready
((RUN_CONFIG)) && copy_and_deploy_config
log "完成"
