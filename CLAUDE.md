# CLAUDE.md

## What this is

`remote-code`: pure-Bash tools to open VS Code (Remote-SSH) or Zed on a server folder.
No build step, no dependencies beyond `ssh`, `fzf`, `code`/`zed`.

- `bin/rcode` — local launcher. Reads hosts from `~/.ssh/config`, lists remote folders over one SSH
  connection, picks with `fzf`, then `exec`s `code --remote ssh-remote+HOST PATH` or `zed ssh://HOST/PATH`.
  Also handles `--help`, `--version`, `--update`.
- `bin/rzed` — **symlink** to `rcode`. The editor is chosen from `$0` (`rzed`) or `RCODE_EDITOR=zed`.
  Never turn it into a copy; edit only `bin/rcode`.
- `share/vsc.sh` — sourced from the *server's* rc file; defines `vsc`/`vsz`, which print the local open command,
  copy it via OSC 52 and emit an OSC 8 link. Requires `VSC_HOST` (the server's alias in the local ssh config).
- `install.sh` — local install (`--prefix`, `--uninstall`), and `--server HOST` to add/remove a block
  delimited by `# >>> rcode >>>` / `# <<< rcode <<<` in the server's rc file (shows diff, asks, backs up).
  Works from a clone or via `curl | bash` (downloads files for `RCODE_REF`).
- `scripts/release.sh X.Y.Z` — release: requires clean `main`, matching `VERSION="X.Y.Z"` in `bin/rcode`,
  `bats` and `gh`; runs tests, pushes, tags `vX.Y.Z`, creates GitHub release.
- `test/` — bats tests with stubs in `test/stubs/` (`ssh`, `fzf`, `curl`, `code`, `zed`, `scp`).
- `README.md` is user-facing documentation (English).

## Commands

```bash
bats test/                 # run all tests (needs bats-core); safe, uses stubs and a temp HOME
bats test/rcode.bats       # one file
shellcheck bin/rcode share/vsc.sh install.sh scripts/release.sh   # if available
```

## Conventions and gotchas

- **Requires bash >= 5.** `rcode` and `install.sh` start with a `BASH_VERSINFO` guard (keep it before any newer syntax);
  `share/vsc.sh` skips loading on older bash. Bash 4/5 features (`${var,,}`, `printf -v`, `mapfile`, `declare -A`) are fine.
- Version lives in one place: `VERSION="..."` in `bin/rcode`. `release.sh` greps for the exact line format.
- Code, comments, messages and docs are in English; user-facing messages are prefixed `rcode:` / `install:`.
- `rcode` uses `set -u` (not `-e`); failures are handled explicitly with `die`/`warn`.
- Host parsing intentionally ignores patterns containing `*`, `?`, `!` and follows `Include` recursively.
- Remote work is sent as a script over stdin to `ssh host 'bash -s'` so a single connection (ControlMaster) is reused.
  Remote paths passed to the shell must be quoted with `printf %q`.
- Paths are percent-encoded by hand for `zed://`/`ssh://` and `vscode://` URLs, under `LC_ALL=C`; in `vsc.sh`
  `printf %q` runs *before* setting `LC_ALL` so non-ASCII characters are not escaped.
- The installer must never modify `~/.ssh/config`; it only suggests changes (`examples/ssh-config`).
- State/config: `~/.local/state/rcode/history` (max 50 entries, `host<TAB>path`), `~/.config/rcode/config`
  (honours `XDG_*`). `--update` must never touch them.
- Tests must not touch the real environment: use `setup_env` from `test/helper.bash` (temp `HOME`, stubs first in `PATH`).
  Stub behavior is controlled with env vars (`FAKE_SSH_FAIL`, `FZF_PICK`, `FZF_QUERY`, `FZF_TAB_ON`, `STUB_LOG`...).
- Env overrides used by tests for `--update`: `RCODE_API_URL`, `RCODE_RAW_URL`, `RCODE_REPO`, `RCODE_TTY`, `RCODE_REF`.
- When changing behavior, update `README.md` and the relevant `.bats` file in the same change.
