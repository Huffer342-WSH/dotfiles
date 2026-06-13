#!/bin/sh
set -eu

PUBLIC_BASE_URL="https://uv.agentsmirror.com"

append_managed_block() {
  target_file="$1"
  managed_block=$(cat <<'EOF'
# >>> uv mirror managed block >>>
export UV_INSTALLER_GITHUB_BASE_URL="https://uv.agentsmirror.com/github"
export UV_PYTHON_DOWNLOADS_JSON_URL="https://uv.agentsmirror.com/metadata/python-downloads.json"
export UV_DEFAULT_INDEX="https://uv.agentsmirror.com/pypi/simple"
# <<< uv mirror managed block <<<
EOF
)

  mkdir -p "$(dirname "$target_file")"
  touch "$target_file"

  if grep -qF "# >>> uv mirror managed block >>>" "$target_file"; then
    awk '
      BEGIN {skip=0}
      /^# >>> uv mirror managed block >>>/ {skip=1; next}
      /^# <<< uv mirror managed block <<</ {skip=0; next}
      !skip {print}
    ' "$target_file" > "$target_file.tmp"
    mv "$target_file.tmp" "$target_file"
  fi

  printf '\n%s\n' "$managed_block" >> "$target_file"
}

write_uv_config() {
  config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/uv"
  config_file="$config_dir/uv.toml"
  timestamp=$(date +%Y%m%d%H%M%S)
  tmp_file=$(mktemp)
  mkdir -p "$config_dir"

  if [ -f "$config_file" ]; then
    cp "$config_file" "$config_file.$timestamp.bak"
    while IFS= read -r line || [ -n "$line" ]; do
      trimmed=$(printf '%s' "$line" | sed 's/^[[:space:]]*//')
      case "$trimmed" in
        python-downloads-json-url\ =*|pypy-install-mirror\ =*)
          continue
          ;;
      esac
      printf '%s\n' "$line" >> "$tmp_file"
    done < "$config_file"
  fi

  if [ -s "$tmp_file" ]; then
    printf '\n' >> "$tmp_file"
  fi

  printf 'python-downloads-json-url = "%s/metadata/python-downloads.json"\n' "$PUBLIC_BASE_URL" >> "$tmp_file"
  mv "$tmp_file" "$config_file"
}

install_uv() {
  installer_file=$(mktemp)
  trap 'rm -f "$installer_file"' EXIT HUP INT TERM
  curl -LsSf "$PUBLIC_BASE_URL/github/astral-sh/uv/releases/download/latest/uv-installer.sh" -o "$installer_file"
  env UV_INSTALLER_GITHUB_BASE_URL="$PUBLIC_BASE_URL/github" sh "$installer_file"
  rm -f "$installer_file"
  trap - EXIT HUP INT TERM
}

install_uv
write_uv_config

if [ -n "${SHELL:-}" ]; then
  case "${SHELL##*/}" in
    zsh) append_managed_block "$HOME/.zshrc" ;;
    bash) append_managed_block "$HOME/.bashrc" ;;
  esac
fi

append_managed_block "$HOME/.profile"
