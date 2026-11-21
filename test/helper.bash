# Isolated environment: HOME, state and PATH with stubs.
setup_env() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export HOME="$BATS_TEST_TMPDIR/home"; mkdir -p "$HOME/.ssh"
  export XDG_STATE_HOME="$HOME/.state" XDG_CONFIG_HOME="$HOME/.config"
  export STUB_DIR="$BATS_TEST_TMPDIR/stub"; mkdir -p "$STUB_DIR"
  export STUB_LOG="$STUB_DIR/calls.log"; : > "$STUB_LOG"
  export PATH="$BATS_TEST_DIRNAME/stubs:$PATH"
  export TERM=dumb
  unset RCODE_EXCLUDE RCODE_EDITOR FAKE_SSH_FAIL FZF_PICK FZF_QUERY FZF_TAB_ON
}
