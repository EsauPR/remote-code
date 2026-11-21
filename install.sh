#!/usr/bin/env bash
# remote-code installer (rcode / rzed / vsc / vsz).
#
#   ./install.sh                       install rcode and rzed in ~/.local
#   ./install.sh --prefix DIR          install in DIR (bin/ and share/rcode/)
#   ./install.sh --uninstall           uninstall the local files
#   ./install.sh --server HOST         install vsc/vsz on a server (ssh)
#       [--alias NAME]                   alias of that server in your local ~/.ssh/config
#                                        (defaults to HOST)
#       [--zoxide]                       also add `zoxide init` on the server
#       [--yes]                          do not ask (by default shows the diff and asks for OK)
#   ./install.sh --server HOST --uninstall   remove the block from the server
#
# Without cloning:  curl -fsSL https://raw.githubusercontent.com/EsauPR/remote-code/main/install.sh | bash
#              curl -fsSL .../install.sh | bash -s -- --server my-host
set -euo pipefail

REPO="${RCODE_REPO:-EsauPR/remote-code}"
REF="${RCODE_REF:-main}"
PREFIX="${PREFIX:-$HOME/.local}"
MODE=install SERVER="" ALIAS="" ZOXIDE=0 YES=0
BEGIN="# >>> rcode >>>"; END="# <<< rcode <<<"

say()  { printf '%s\n' "$*"; }
warn() { printf 'install: ⚠ %s\n' "$*" >&2; }
die()  { printf 'install: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --prefix)    PREFIX="${2:?missing DIR}"; shift;;
    --uninstall) MODE=uninstall;;
    --server)    SERVER="${2:?missing HOST}"; shift;;
    --alias)     ALIAS="${2:?missing NAME}"; shift;;
    --zoxide)    ZOXIDE=1;;
    --yes|-y)    YES=1;;
    -h|--help)   sed -n '2,15p' "${BASH_SOURCE[0]:-$0}" | sed 's/^# \{0,1\}//'; exit 0;;
    *) die "unknown option: $1";;
  esac
  shift
done
ALIAS="${ALIAS:-$SERVER}"
BIN="$PREFIX/bin"; SHARE="$PREFIX/share/rcode"

# ---- source of the files: the local repo or a download (curl | bash) ----
SRC=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/bin/rcode" ]; then
  SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [ "$MODE" = install ]; then
  command -v curl >/dev/null 2>&1 || die "curl is required (or clone the repo and run ./install.sh)."
  TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
  say "Downloading $REPO@$REF …"
  curl -fsSL "https://github.com/$REPO/archive/$REF.tar.gz" | tar -xz -C "$TMP" --strip-components=1
  SRC="$TMP"
fi

confirm() {
  [ "$YES" = 1 ] && return 0
  local tty="${RCODE_TTY:-/dev/tty}" ans
  printf '%s [y/N] ' "$1" >&2; read -r ans <"$tty" || return 1
  case "$ans" in y|Y|yes|YES) return 0;; *) return 1;; esac
}

# ============================ local ============================
install_local() {
  mkdir -p "$BIN" "$SHARE"
  install -m 755 "$SRC/bin/rcode" "$BIN/rcode"
  ln -sf rcode "$BIN/rzed"
  install -m 644 "$SRC/share/vsc.sh" "$SHARE/vsc.sh"
  say "✔ rcode and rzed → $BIN"
  say "✔ vsc.sh      → $SHARE/vsc.sh"

  local m
  for m in fzf ssh; do command -v "$m" >/dev/null 2>&1 || warn "'$m' is missing (required)."; done
  command -v code >/dev/null 2>&1 || command -v zed >/dev/null 2>&1 \
    || warn "cannot find 'code' or 'zed' in PATH (you need at least one)."
  case ":$PATH:" in *":$BIN:"*) ;; *) warn "$BIN is not in your PATH.";; esac
  if ! grep -qsiE '^\s*ControlMaster' "$HOME/.ssh/config" 2>/dev/null; then
    say ""
    say "Recommended: reuse SSH connections. Add this to ~/.ssh/config (I do not modify it myself):"
    sed 's/^/    /' "$SRC/examples/ssh-config"
    say "    and create the directory:  mkdir -m 700 -p ~/.ssh/cm"
  fi
}

uninstall_local() {
  rm -f "$BIN/rcode" "$BIN/rzed" "$SHARE/vsc.sh"
  rmdir "$SHARE" 2>/dev/null || true
  say "✔ uninstalled from $PREFIX (I did not touch ~/.config/rcode or ~/.local/state/rcode)"
}

# ============================ server ==============================
remote_rc() {   # rc file according to the server's shell
  case "$(ssh "$SERVER" 'basename "${SHELL:-bash}"' 2>/dev/null)" in zsh) echo .zshrc;; *) echo .bashrc;; esac
}

server_block() {
  printf '%s\n' "$BEGIN"
  printf '# vsc / vsz: open this folder in local VS Code / Zed\n'
  printf 'export VSC_HOST="%s"\n' "$ALIAS"
  printf '[ -f ~/.local/share/rcode/vsc.sh ] && . ~/.local/share/rcode/vsc.sh\n'
  if [ "$ZOXIDE" = 1 ]; then
    local sh; sh=$([ "$1" = .zshrc ] && echo zsh || echo bash)
    printf 'command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init %s)"\n' "$sh"
  fi
  printf '%s\n' "$END"
}

install_server() {
  local rc block
  rc=$(remote_rc) || die "could not connect to '$SERVER'."
  [ -n "$rc" ] || die "could not connect to '$SERVER'."
  if ssh "$SERVER" "grep -qF '$BEGIN' ~/$rc" 2>/dev/null; then
    say "The rcode block is already in $SERVER:~/$rc; only updating vsc.sh."
    ssh "$SERVER" 'mkdir -p ~/.local/share/rcode' && scp -q "$SRC/share/vsc.sh" "$SERVER:.local/share/rcode/vsc.sh"
    say "✔ vsc.sh updated on $SERVER"; return 0
  fi
  block=$(server_block "$rc")
  say "Proposed change to $SERVER:~/$rc (appended at the end):"
  printf '%s\n' "$block" | sed 's/^/+ /'
  say "Also: $SERVER:~/.local/share/rcode/vsc.sh (new file) and backup ~/$rc.bak-rcode"
  confirm "Apply?" || die "cancelled; nothing was modified."
  ssh "$SERVER" "mkdir -p ~/.local/share/rcode && cp -p ~/$rc ~/$rc.bak-rcode 2>/dev/null || true"
  scp -q "$SRC/share/vsc.sh" "$SERVER:.local/share/rcode/vsc.sh"
  { printf '\n'; printf '%s\n' "$block"; } | ssh "$SERVER" "cat >> ~/$rc"
  say "✔ installed on $SERVER. Open a new session (or: source ~/$rc). Try: vsc  /  vsz"
}

uninstall_server() {
  local rc; rc=$(remote_rc) || die "could not connect to '$SERVER'."
  confirm "Remove the rcode block from $SERVER:~/$rc and delete vsc.sh?" || die "cancelled."
  ssh "$SERVER" "cp -p ~/$rc ~/$rc.bak-rcode && sed -i '/^# >>> rcode >>>\$/,/^# <<< rcode <<<\$/d' ~/$rc && rm -f ~/.local/share/rcode/vsc.sh"
  say "✔ uninstalled from $SERVER (backup: ~/$rc.bak-rcode)"
}

# ============================ main ============================
if [ -n "$SERVER" ]; then
  command -v ssh >/dev/null 2>&1 || die "ssh is missing."
  if [ "$MODE" = uninstall ]; then uninstall_server; else install_server; fi
elif [ "$MODE" = uninstall ]; then
  uninstall_local
else
  install_local
fi
