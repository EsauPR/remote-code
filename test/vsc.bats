#!/usr/bin/env bats
load helper
setup() { setup_env; mkdir -p "$BATS_TEST_TMPDIR/my folder ñ"; D="$BATS_TEST_TMPDIR/my folder ñ"; export VSC_HOST=srv; }

run_in() { bash -c 'source "$1/share/vsc.sh"; shift; "$@"' _ "$ROOT" "$@"; }

@test "vsc: VS Code command and URI" {
  run run_in vsc "$D"; [ "$status" -eq 0 ]
  [[ "$output" == *"code --remote ssh-remote+srv "* ]]
  [[ "$output" == *"vscode://vscode-remote/ssh-remote+srv"*"my%20folder%20%C3%B1"* ]]
}

@test "vsz: Zed command and URI" {
  run run_in vsz "$D"; [ "$status" -eq 0 ]
  [[ "$output" == *"zed ssh://srv"*"my%20folder%20%C3%B1"* ]]
  [[ "$output" == *"zed://ssh/srv"* ]]
}

@test "OSC 52 contains the command in base64" {
  b64=$(run_in vsz /tmp 2>/dev/null | head -1 | sed 's/^.*52;c;//; s/\x07.*//')
  [ "$(printf '%s' "$b64" | base64 -d)" = "zed ssh://srv/tmp" ]
}

@test "errors: no VSC_HOST and nonexistent path" {
  VSC_HOST= run run_in vsc; [ "$status" -eq 1 ]; [[ "$output" == *VSC_HOST* ]]
  run run_in vsc /no/such/dir; [ "$status" -eq 1 ]; [[ "$output" == *"does not exist"* ]]
}

@test "also works in zsh" {
  command -v zsh >/dev/null || skip "zsh not installed"
  run zsh -c 'source "$1/share/vsc.sh"; vsz /tmp' _ "$ROOT"
  [ "$status" -eq 0 ]; [[ "$output" == *"zed ssh://srv/tmp"* ]]
}
