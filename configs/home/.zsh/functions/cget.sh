# Reliable curl downloader with resume support.
# Usage:
#   cget <url>
#   cget -o <output_file> <url>
cget() {
  local output=""
  local url=""

  while [ $# -gt 0 ]; do
    case "$1" in
      -o|--output)
        if [ -z "${2:-}" ]; then
          echo "Usage: cget [-o output_file] <url>"
          return 1
        fi
        output="$2"
        shift 2
        ;;
      -h|--help)
        echo "Usage: cget [-o output_file] <url>"
        return 0
        ;;
      -*)
        echo "Unknown option: $1"
        echo "Usage: cget [-o output_file] <url>"
        return 1
        ;;
      *)
        if [ -n "$url" ]; then
          echo "Only one URL is supported."
          echo "Usage: cget [-o output_file] <url>"
          return 1
        fi
        url="$1"
        shift
        ;;
    esac
  done

  if [ -z "$url" ]; then
    echo "Usage: cget [-o output_file] <url>"
    return 1
  fi

  local curl_opts=(
    -L
    -C -
    --connect-timeout 60
    --speed-time 120
    --speed-limit 1024
    --retry 20
    --retry-delay 10
    --retry-max-time 0
    --retry-all-errors
    --fail-with-body
  )

  if [ -n "$output" ]; then
    curl "${curl_opts[@]}" -o "$output" "$url"
  else
    curl "${curl_opts[@]}" -O "$url"
  fi
}
