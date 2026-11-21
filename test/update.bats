#!/usr/bin/env bats
load helper
setup() { setup_env; RCODE="$ROOT/bin/rcode"; }

@test "--update installs the latest release into the same prefix" {
  FAKE_LATEST=v9.9.9 run "$RCODE" --update --yes
  [ "$status" -eq 0 ]
  [[ "$output" == *"→ v9.9.9"* ]]
  [[ "$output" == *"INSTALLER REF=v9.9.9 ARGS=--prefix $ROOT"* ]]
  grep -q 'raw.githubusercontent.com/EsauPR/remote-code/v9.9.9/install.sh' "$STUB_LOG"
}

@test "--update does nothing when already up to date" {
  v=$("$RCODE" --version | awk '{print $2}')
  FAKE_LATEST="v$v" run "$RCODE" --update --yes
  [ "$status" -eq 0 ]; [[ "$output" == *"up to date"* ]]
  ! grep -q 'install.sh' "$STUB_LOG"
}

@test "--update does not downgrade when the installed version is newer" {
  FAKE_LATEST=v0.0.1 run "$RCODE" --update --yes
  [ "$status" -eq 0 ]; [[ "$output" == *"up to date"* ]]
}

@test "--update fails clearly when there are no releases" {
  FAKE_NO_RELEASE=1 run "$RCODE" --update --yes
  [ "$status" -eq 1 ]; [[ "$output" == *"could not query the latest release"* ]]
}

@test "--update asks first: 'n' cancels without running the installer" {
  printf 'n\n' > "$BATS_TEST_TMPDIR/ans"
  RCODE_TTY="$BATS_TEST_TMPDIR/ans" run "$RCODE" --update
  [ "$status" -eq 1 ]; [[ "$output" == *cancelled* ]]
  ! grep -q 'install.sh' "$STUB_LOG"
}

@test "--update asks first: 'y' runs the installer" {
  printf 'y\n' > "$BATS_TEST_TMPDIR/ans"
  RCODE_TTY="$BATS_TEST_TMPDIR/ans" run "$RCODE" --update
  [ "$status" -eq 0 ]; [[ "$output" == *"INSTALLER REF=v9.9.9"* ]]
}

@test "VERSION is semver" {
  run "$RCODE" --version
  [[ "$output" =~ ^rcode\ [0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "release script: rejects a bad version and passes syntax check" {
  bash -n "$ROOT/scripts/release.sh"
  run "$ROOT/scripts/release.sh" 1.2; [ "$status" -ne 0 ]
  [[ "$output" == *"version must look like"* ]]
}
