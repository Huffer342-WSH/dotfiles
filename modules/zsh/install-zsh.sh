#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

CONFIG_SRC="$REPO_ROOT/configs/home/.zsh"

# remote fallback source
CONFIG_REMOTE_REPO="https://github.com/Huffer342-WSH/dotfiles.git"
CONFIG_REMOTE_REF="archlinux"
CONFIG_FETCH_MODE="auto"

ZSH_HOME="$HOME/.zsh"
ZSHRC="$HOME/.zshrc"
SKIP_ZSHRC=0
SKIP_CHSH=0
SKIP_PACKAGES=0
DOWNLOAD_LOG=1
DOWNLOAD_VERBOSE=1

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --config-src DIR        Local .zsh config directory (default: $CONFIG_SRC)
  --zsh-home DIR          Target .zsh directory (default: $ZSH_HOME)
  --zshrc FILE            Target .zshrc file (default: $ZSHRC)
  --fetch-mode MODE       Config fetch mode: auto, local, remote (default: auto)
  --remote-repo URL       Git repository used for remote config (default: $CONFIG_REMOTE_REPO)
  --remote-ref REF        Git ref for remote config download (default: $CONFIG_REMOTE_REF)
  --skip-zshrc            Skip .zshrc injection
  --skip-chsh             Skip default shell switch reminder
  --skip-packages         Do not install missing system packages
  --quiet-download        Hide network download/request logs
  --simple-download-log   Hide command outputs in download logs
  -h, --help              Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config-src)
      CONFIG_SRC="$2"
      shift 2
      ;;
    --zsh-home)
      ZSH_HOME="$2"
      shift 2
      ;;
    --zshrc)
      ZSHRC="$2"
      shift 2
      ;;
    --fetch-mode)
      CONFIG_FETCH_MODE="$2"
      shift 2
      ;;
    --remote-repo)
      CONFIG_REMOTE_REPO="$2"
      shift 2
      ;;
    --remote-ref)
      CONFIG_REMOTE_REF="$2"
      shift 2
      ;;
    --skip-zshrc)
      SKIP_ZSHRC=1
      shift
      ;;
    --skip-chsh)
      SKIP_CHSH=1
      shift
      ;;
    --skip-packages)
      SKIP_PACKAGES=1
      shift
      ;;
    --quiet-download)
      DOWNLOAD_LOG=0
      shift
      ;;
    --simple-download-log)
      DOWNLOAD_VERBOSE=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

case "$CONFIG_FETCH_MODE" in
  auto|local|remote) ;;
  *)
    echo "[ERROR] invalid --fetch-mode: $CONFIG_FETCH_MODE"
    echo "Expected: auto, local, remote"
    exit 1
    ;;
esac

VENDOR="$ZSH_HOME/vendor"

# ----------------------------
# OS detection helpers
# ----------------------------

detect_pkg_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "apt"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  else
    echo "unknown"
  fi
}

print_install_hint() {
  case "$1" in
    apt) echo "apt-get update && apt-get install -y ca-certificates curl git zsh" ;;
    pacman) echo "pacman -Sy --needed --noconfirm ca-certificates curl git zsh" ;;
    dnf) echo "dnf install -y ca-certificates curl git zsh" ;;
    *) echo "Please install ca-certificates, curl, git and zsh manually." ;;
  esac
}

run_as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo "[ERROR] installing packages requires root privileges or sudo"
    return 1
  fi
}

install_system_dependencies() {
  local pm="$1"

  echo "[INFO] installing required packages with $pm"
  case "$pm" in
    apt)
      run_as_root apt-get update
      run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl git zsh
      ;;
    pacman)
      run_as_root pacman -Sy --needed --noconfirm ca-certificates curl git zsh
      ;;
    dnf)
      run_as_root dnf install -y ca-certificates curl git zsh
      ;;
    *)
      echo "[ERROR] unsupported package manager"
      print_install_hint "$pm"
      return 1
      ;;
  esac
}

install_optional_tools() {
  local pm=""
  local tool=""
  local -a missing_tools=()

  for tool in fzf eza; do
    if command -v "$tool" >/dev/null 2>&1; then
      echo "[OK] optional command found: $tool"
    else
      missing_tools+=("$tool")
    fi
  done

  if [[ "${#missing_tools[@]}" -eq 0 ]]; then
    return
  fi

  if [[ "$SKIP_PACKAGES" -eq 1 ]]; then
    for tool in "${missing_tools[@]}"; do
      print_optional_tool_warning "$tool"
    done
    return
  fi

  pm="$(detect_pkg_manager)"
  echo "[INFO] attempting to install optional commands: ${missing_tools[*]}"

  if [[ "$pm" == "apt" ]] && ! run_as_root apt-get update; then
    for tool in "${missing_tools[@]}"; do
      print_optional_tool_warning "$tool"
    done
    return
  fi

  for tool in "${missing_tools[@]}"; do
    if install_optional_tool "$pm" "$tool"; then
      echo "[OK] optional command installed: $tool"
    else
      print_optional_tool_warning "$tool"
    fi
  done
}

install_optional_tool() {
  local pm="$1"
  local package="$2"

  case "$pm" in
    apt)
      run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "$package"
      ;;
    pacman)
      run_as_root pacman -Sy --needed --noconfirm "$package"
      ;;
    dnf)
      run_as_root dnf install -y "$package"
      ;;
    *) return 1 ;;
  esac
}

print_optional_tool_warning() {
  case "$1" in
    fzf) echo "[WARN] fzf is not installed; fzf-tab will be disabled" ;;
    eza) echo "[WARN] eza is not installed; ls aliases will use the system ls" ;;
  esac
}

log_download() {
  if [[ "$DOWNLOAD_LOG" -eq 1 ]]; then
    echo "[DOWNLOAD] $*"
  fi
}

log_download_detail() {
  if [[ "$DOWNLOAD_LOG" -eq 1 && "$DOWNLOAD_VERBOSE" -eq 1 ]]; then
    echo "$@"
  fi
}

# ----------------------------
# git sync function
# ----------------------------

git_sync_repo() {
  local repo_url="$1"
  local target_dir="$2"

  echo ""
  echo "==> $target_dir"

  local branch=""

  if [[ -d "$target_dir/.git" ]]; then
    branch="$(git -C "$target_dir" branch --show-current 2>/dev/null || true)"

    if [[ -z "$branch" ]]; then
      log_download "git remote show origin -> $target_dir"
      branch="$(git -C "$target_dir" remote show origin 2>/dev/null \
        | awk '/HEAD branch/ {print $NF}' || true)"
    fi

    if [[ -z "$branch" ]]; then
      branch="$(git -C "$target_dir" rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null \
        | sed 's@^[^/]*/@@' || true)"
    fi

    if [[ -z "$branch" ]]; then
      branch="$(git -C "$target_dir" for-each-ref --format='%(refname:short)' refs/remotes/origin \
        | sed 's@^origin/@@' \
        | grep -v '^HEAD$' \
        | head -n 1)"
    fi

    if [[ -z "$branch" ]]; then
      echo "[ERROR] unable to detect branch for: $target_dir"
      exit 1
    fi

    echo "detected branch: $branch"

    log_download "git fetch --all --prune -> $target_dir"
    git -C "$target_dir" fetch --all --prune
    git -C "$target_dir" checkout "$branch" 2>/dev/null || true
    git -C "$target_dir" reset --hard "origin/$branch"
    return
  fi

  log_download "git ls-remote --symref $repo_url HEAD"
  branch="$(git ls-remote --symref "$repo_url" HEAD 2>/dev/null \
    | awk '/ref:/ {print $2}' \
    | sed 's@refs/heads/@@')"

  [[ -z "$branch" ]] && branch="main"

  log_download "git ls-remote --heads $repo_url $branch"
  if ! git ls-remote --heads "$repo_url" "$branch" | grep -q "$branch"; then
    log_download "git ls-remote --heads $repo_url master"
    if git ls-remote --heads "$repo_url" master | grep -q master; then
      branch="master"
    fi
  fi

  echo "cloning branch: $branch"

  log_download "git clone --depth=1 --branch $branch $repo_url -> $target_dir"
  git clone --depth=1 --branch "$branch" \
    "$repo_url" "$target_dir"
}

# ----------------------------
# 1. install/check system dependencies
# ----------------------------

missing_dependencies=()
for command_name in curl git zsh; do
  command -v "$command_name" >/dev/null 2>&1 || missing_dependencies+=("$command_name")
done

if [[ "${#missing_dependencies[@]}" -gt 0 ]]; then
  PM="$(detect_pkg_manager)"
  echo "[INFO] missing dependencies: ${missing_dependencies[*]}"

  if [[ "$SKIP_PACKAGES" -eq 1 ]]; then
    echo "[ERROR] required packages are missing"
    print_install_hint "$PM"
    exit 1
  fi

  install_system_dependencies "$PM"
fi

echo "[OK] system dependencies found"

install_optional_tools

# ----------------------------
# 2. prepare dirs
# ----------------------------

mkdir -p "$VENDOR"

# ----------------------------
# 3. install vendor deps
# ----------------------------

git_sync_repo "https://github.com/mattmc3/antidote.git" "$VENDOR/.antidote"
git_sync_repo "https://github.com/romkatv/powerlevel10k.git" "$VENDOR/powerlevel10k"

# ----------------------------
# 4. load config (local or remote fallback)
# ----------------------------

echo ""
echo "[CONFIG] preparing zsh config..."

mkdir -p "$ZSH_HOME"

copy_config_dir() {
  local source_dir="$1"
  local target_dir="$2"
  local source_path=""
  local name=""
  local restore_dotglob=""
  local restore_nullglob=""

  restore_dotglob="$(shopt -p dotglob || true)"
  restore_nullglob="$(shopt -p nullglob || true)"
  shopt -s dotglob nullglob

  for source_path in "$source_dir"/*; do
    name="$(basename "$source_path")"
    case "$name" in
      vendor|.zsh_plugins.zsh|.zsh_plugins.fzf.zsh) continue ;;
    esac
    cp -R "$source_path" "$target_dir/"
  done

  eval "$restore_dotglob"
  eval "$restore_nullglob"
}

download_remote_config_via_git() {
  local checkout_dir=""
  local remote_config_src=""

  checkout_dir="$(mktemp -d)"
  remote_config_src="$checkout_dir/configs/home/.zsh"

  log_download "git sparse clone $CONFIG_REMOTE_REPO ($CONFIG_REMOTE_REF)"
  if ! git clone --quiet --depth=1 --filter=blob:none --sparse \
    --branch "$CONFIG_REMOTE_REF" "$CONFIG_REMOTE_REPO" "$checkout_dir"; then
    rm -rf -- "$checkout_dir"
    echo "[ERROR] failed to download remote zsh config"
    return 1
  fi

  if ! git -C "$checkout_dir" sparse-checkout set configs/home/.zsh ||
    [[ ! -f "$remote_config_src/init.zsh" ]]; then
    rm -rf -- "$checkout_dir"
    echo "[ERROR] remote zsh config is incomplete"
    return 1
  fi

  copy_config_dir "$remote_config_src" "$ZSH_HOME"
  rm -rf -- "$checkout_dir"
  echo "downloaded remote config: $CONFIG_REMOTE_REPO ($CONFIG_REMOTE_REF)"
}

sync_config_dir() {
  case "$CONFIG_FETCH_MODE" in
    auto)
      if [[ -d "$CONFIG_SRC" ]]; then
        copy_config_dir "$CONFIG_SRC" "$ZSH_HOME"
        echo "copied local dir: $CONFIG_SRC"
        return
      fi

      download_remote_config_via_git
      ;;
    local)
      if [[ ! -d "$CONFIG_SRC" ]]; then
        echo "[ERROR] local config dir not found: $CONFIG_SRC"
        exit 1
      fi

      copy_config_dir "$CONFIG_SRC" "$ZSH_HOME"
      echo "copied local dir: $CONFIG_SRC"
      ;;
    remote)
      download_remote_config_via_git
      ;;
  esac
}

sync_config_dir

# ----------------------------
# 5. inject .zshrc
# ----------------------------

BEGIN="# >>> zsh bootstrap >>>"
END="# <<< zsh bootstrap <<<"

BLOCK="
$BEGIN
export ZSH_HOME=\"\$HOME/.zsh\"
source \"\$ZSH_HOME/init.zsh\"
$END
"

if [[ "$SKIP_ZSHRC" -eq 1 ]]; then
  echo "[SKIP] .zshrc injection"
elif grep -q "$BEGIN" "$ZSHRC" 2>/dev/null; then
  echo ".zshrc already configured"
else
  echo "injecting .zshrc..."
  cat >> "$ZSHRC" <<EOF

$BLOCK
EOF
fi

# ----------------------------
# 6. optional shell switch
# ----------------------------

if [[ "$SKIP_CHSH" -eq 1 ]]; then
  echo "[SKIP] chsh reminder"
else
  zsh_bin="$(command -v zsh)"
  echo "[INFO] default shell not changed automatically."
  echo "[INFO] To switch manually, run: chsh -s \"$zsh_bin\""
fi

echo ""
echo "done -> restart: exec zsh"
