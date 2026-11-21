#!/usr/bin/env bats
load helper
setup() { setup_env; RCODE="$ROOT/bin/rcode"; }

write_config() {
  cat > "$HOME/.ssh/config" <<'CFG'
Host alpha
    HostName 10.0.0.1
Host beta gamma
    User x
Host *
    ControlMaster auto
Host web-?
    User y
Host !negated
    User z
Host extra
    HostName 10.0.0.9
CFG
}

@test "--version y --help" {
  run "$RCODE" --version; [ "$status" -eq 0 ]; [[ "$output" == rcode\ * ]]
  run "$RCODE" --help;    [ "$status" -eq 0 ]; [[ "$output" == *"Usage: rcode"* ]]
}

@test "lists hosts: no wildcards or negated patterns" {
  write_config; export FAKE_SSH_FAIL=1
  run "$RCODE"; [ "$status" -eq 1 ]
  run cat "$STUB_DIR/fzf.1.in"
  [ "$output" = $'alpha\nbeta\ngamma\nextra' ]
}

@test "honors Include (path relative to ~/.ssh)" {
  printf 'Include extra.conf\nHost main\n' > "$HOME/.ssh/config"
  printf 'Host included\n' > "$HOME/.ssh/extra.conf"
  export FAKE_SSH_FAIL=1; run "$RCODE"
  run cat "$STUB_DIR/fzf.1.in"; [[ "$output" == *included* && "$output" == *main* ]]
}

@test "RCODE_EXCLUDE hides hosts" {
  write_config; export FAKE_SSH_FAIL=1 RCODE_EXCLUDE="beta extra"
  run "$RCODE"; run cat "$STUB_DIR/fzf.1.in"
  [ "$output" = $'alpha\ngamma' ]
}

@test "unreachable host: clear error" {
  write_config; export FAKE_SSH_FAIL=1
  run "$RCODE" alpha
  [ "$status" -eq 1 ]; [[ "$output" == *"could not connect to 'alpha'"* ]]
}

@test "host + path: opens VS Code, path with spaces as a single argument" {
  write_config
  run "$RCODE" alpha "/srv/my project"; [ "$status" -eq 0 ]
  grep -qF 'code [--remote] [ssh-remote+alpha] [/srv/my project]' "$STUB_LOG"
}

@test "rzed opens Zed with an encoded URL" {
  write_config; ln -s "$ROOT/bin/rcode" "$BATS_TEST_TMPDIR/rzed"
  run "$BATS_TEST_TMPDIR/rzed" alpha "/srv/a b/ñ"; [ "$status" -eq 0 ]
  grep -qF 'zed [ssh://alpha/srv/a%20b/%C3%B1]' "$STUB_LOG"
}

@test "RCODE_EDITOR=zed" {
  write_config; RCODE_EDITOR=zed run "$RCODE" alpha /opt
  grep -qF 'zed [ssh://alpha/opt]' "$STUB_LOG"
}

@test "interactive selection: picks remote folder and saves history" {
  write_config; export FZF_PICK=1
  run "$RCODE" alpha; [ "$status" -eq 0 ]
  grep -qF '[ssh-remote+alpha] [/home/test/proj one]' "$STUB_LOG"
  [ "$(cat "$XDG_STATE_HOME/rcode/history")" = $'alpha\t/home/test/proj one' ]
}

@test "manual path with ~ expands to the remote HOME" {
  write_config; export FZF_PICK=99 FZF_QUERY='~/something'
  run "$RCODE" alpha; [ "$status" -eq 0 ]
  grep -qF '[/home/test/something]' "$STUB_LOG"
}

@test "Tab enters the folder and lists the next level" {
  write_config; export FZF_PICK=1 FZF_TAB_ON=1
  run "$RCODE" alpha; [ "$status" -eq 0 ]
  [ -f "$STUB_DIR/fzf.2.in" ]   # second list = folder contents
}

@test "config file: RCODE_EXCLUDE" {
  write_config; mkdir -p "$XDG_CONFIG_HOME/rcode"
  echo 'RCODE_EXCLUDE="alpha"' > "$XDG_CONFIG_HOME/rcode/config"
  export FAKE_SSH_FAIL=1; run "$RCODE"; run cat "$STUB_DIR/fzf.1.in"
  [[ "$output" != *alpha* ]]
}

@test "clear error without fzf" {
  write_config
  # Empty PATH: neither fzf nor any real editor can be found or launched.
  mkdir -p "$BATS_TEST_TMPDIR/empty"
  run env PATH="$BATS_TEST_TMPDIR/empty" "$(command -v bash)" "$RCODE" alpha /x
  [ "$status" -eq 1 ]; [[ "$output" == *"fzf is not installed"* ]]
}

@test "safety: tests never reach a real editor (stubs come first in PATH)" {
  [ "$(command -v code)" = "$BATS_TEST_DIRNAME/stubs/code" ]
  [ "$(command -v zed)" = "$BATS_TEST_DIRNAME/stubs/zed" ]
  [ "$(command -v ssh)" = "$BATS_TEST_DIRNAME/stubs/ssh" ]
}
