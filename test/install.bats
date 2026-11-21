#!/usr/bin/env bats
load helper
setup() { setup_env; INSTALL="$ROOT/install.sh"; P="$BATS_TEST_TMPDIR/prefix"; }

@test "installs rcode, rzed and vsc.sh under the prefix" {
  run "$INSTALL" --prefix "$P"; [ "$status" -eq 0 ]
  [ -x "$P/bin/rcode" ]; [ "$(readlink "$P/bin/rzed")" = rcode ]; [ -f "$P/share/rcode/vsc.sh" ]
  run "$P/bin/rcode" --version; [ "$status" -eq 0 ]
}

@test "suggests ControlMaster without touching ~/.ssh/config" {
  printf 'Host a\n' > "$HOME/.ssh/config"
  run "$INSTALL" --prefix "$P"; [[ "$output" == *ControlMaster* ]]
  [ "$(cat "$HOME/.ssh/config")" = "Host a" ]
}

@test "--uninstall removes what was installed" {
  "$INSTALL" --prefix "$P" >/dev/null
  run "$INSTALL" --prefix "$P" --uninstall; [ "$status" -eq 0 ]
  [ ! -e "$P/bin/rcode" ]
  [ ! -L "$P/bin/rzed" ]
  [ ! -e "$P/share/rcode/vsc.sh" ]
}

@test "unknown option fails" {
  run "$INSTALL" --nope; [ "$status" -eq 1 ]
}

@test "--server: shows the diff, copies vsc.sh and adds the block" {
  export STUB_APPENDED="$STUB_DIR/appended"
  run "$INSTALL" --server myserver --alias my-alias --zoxide --yes; [ "$status" -eq 0 ]
  [[ "$output" == *'+ export VSC_HOST="my-alias"'* ]]
  grep -q '^scp .*vsc.sh myserver:.local/share/rcode/vsc.sh' "$STUB_LOG"
  grep -q '>>> rcode >>>' "$STUB_APPENDED"
  grep -q 'export VSC_HOST="my-alias"' "$STUB_APPENDED"
  grep -q 'zoxide init bash' "$STUB_APPENDED"
}

@test "--server on zsh uses .zshrc and zoxide init zsh" {
  export STUB_APPENDED="$STUB_DIR/appended" FAKE_REMOTE_SHELL=zsh
  run "$INSTALL" --server s --zoxide --yes; [ "$status" -eq 0 ]
  grep -q 'cat >> ~/.zshrc' "$STUB_LOG"; grep -q 'zoxide init zsh' "$STUB_APPENDED"
}

@test "--server without --yes: answering 'n' modifies nothing" {
  printf 'n\n' > "$BATS_TEST_TMPDIR/ans"
  RCODE_TTY="$BATS_TEST_TMPDIR/ans" run "$INSTALL" --server s
  [ "$status" -ne 0 ]; [[ "$output" == *cancelled* ]]
  ! grep -q 'cat >>' "$STUB_LOG"
}

@test "--server without --yes: answering 'y' applies it" {
  printf 'y\n' > "$BATS_TEST_TMPDIR/ans"
  RCODE_TTY="$BATS_TEST_TMPDIR/ans" STUB_APPENDED="$STUB_DIR/appended" run "$INSTALL" --server s
  [ "$status" -eq 0 ]; grep -q 'cat >>' "$STUB_LOG"
}

@test "--server is idempotent if the block already exists" {
  export FAKE_GREP_RC=0
  run "$INSTALL" --server s --yes; [ "$status" -eq 0 ]
  [[ "$output" == *"already in"* ]]; ! grep -q 'cat >>' "$STUB_LOG"
}
