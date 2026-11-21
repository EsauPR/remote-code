#!/usr/bin/env bash
# Publish a release: scripts/release.sh X.Y.Z
# Prerequisites: VERSION="X.Y.Z" already set in bin/rcode and committed, clean tree on main.
# It runs the tests, pushes main, creates the annotated tag vX.Y.Z and a GitHub release.
set -euo pipefail
cd "$(dirname "$0")/.."
die() { echo "release: $*" >&2; exit 1; }

v="${1:?usage: scripts/release.sh X.Y.Z}"
[[ "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must look like 1.2.3"
[ "$(git rev-parse --abbrev-ref HEAD)" = main ] || die "switch to the main branch first"
git diff --quiet && git diff --cached --quiet || die "uncommitted changes"
grep -q "^VERSION=\"$v\"\$" bin/rcode || die "set VERSION=\"$v\" in bin/rcode and commit it first"
git rev-parse -q --verify "refs/tags/v$v" >/dev/null && die "tag v$v already exists"
command -v bats >/dev/null 2>&1 || die "bats is required to run the tests"
command -v gh   >/dev/null 2>&1 || die "gh is required to create the release"

bats test/ </dev/null
git push origin main
git tag -a "v$v" -m "v$v"
git push origin "v$v"
gh release create "v$v" --title "v$v" --generate-notes
echo "Released v$v. On your machines: rcode --update"
