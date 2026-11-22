# vsc / vsz — for the ~/.bashrc (or .zshrc) of the SERVERS.
# Requires: export VSC_HOST="<alias in your local ~/.ssh/config>"
# Usage: vsc [path]   → VS Code      vsz [path]   → Zed
# (defaults to the current directory). Prints the local command to run, copies it
# to the local clipboard (OSC 52) and shows a clickable link (OSC 8).

# pct_encode STRING → percent-encoded bytes (keeps / . _ ~ - and alphanumerics).
# Works on raw bytes via od, so it does not depend on the locale or bash version.
pct_encode() {
  local hex b n i out=""
  hex=$(printf '%s' "$1" | od -An -v -tx1 | tr -d ' \n' | tr 'a-f' 'A-F')
  for ((i = 0; i < ${#hex}; i += 2)); do
    b="${hex:$i:2}"; n=$((16#$b))
    if (( (n >= 48 && n <= 57) || (n >= 65 && n <= 90) || (n >= 97 && n <= 122) \
          || n == 45 || n == 46 || n == 47 || n == 95 || n == 126 )); then
      out+=$(printf "\\x$b")
    else
      out+="%$b"
    fi
  done
  printf '%s' "$out"
}

# _vsc_open <vscode|zed> [path]
_vsc_open() {
  local editor="$1"
  if [ -z "${VSC_HOST:-}" ]; then
    echo "vsc: set VSC_HOST (alias of this server in your local ~/.ssh/config)" >&2
    return 1
  fi
  local p="${2:-$PWD}"
  p=$(cd -- "$p" 2>/dev/null && pwd -P) || { echo "vsc: does not exist: ${2:-$PWD}" >&2; return 1; }

  local cmd uri label enc q
  q=$(printf '%q' "$p")
  enc=$(pct_encode "$p")

  case "$editor" in
    zed)
      cmd="zed ssh://$VSC_HOST$enc"
      uri="zed://ssh/$VSC_HOST$enc"
      label="▶ Open in Zed ($VSC_HOST:$p)" ;;
    *)
      cmd="code --remote ssh-remote+$VSC_HOST $q"
      uri="vscode://vscode-remote/ssh-remote+$VSC_HOST$enc"
      label="▶ Open in VS Code ($VSC_HOST:$p)" ;;
  esac

  # OSC 52 → local clipboard (inside tmux you need `set -g allow-passthrough on`)
  local b64 osc
  b64=$(printf '%s' "$cmd" | base64 | tr -d '\n')
  osc=$(printf '\033]52;c;%s\a' "$b64")
  if [ -n "${TMUX:-}" ]; then
    printf '\033Ptmux;\033%s\033\\' "$osc"
  else
    printf '%s' "$osc"
  fi

  printf '%s\n' "$cmd"
  # OSC 8 → hyperlink
  printf '\033]8;;%s\a%s\033]8;;\a\n' "$uri" "$label"
  printf '(command copied to the clipboard if your terminal supports OSC 52)\n' >&2
}

vsc() { _vsc_open vscode "$@"; }
vsz() { _vsc_open zed "$@"; }
