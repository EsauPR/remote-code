# remote-code

Open **VS Code** (Remote-SSH) or **Zed** on a server folder without remembering the host or path.
It reads your hosts from `~/.ssh/config`, lists folders on the server and lets you pick one with `fzf`.

`rcode` / `rzed` run locally; `vsc` / `vsz` run on the server and print, copy and link the local open command.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/EsauPR/remote-code/main/install.sh | bash
```

Or by cloning the repo (recommended if you prefer to review first):

```bash
git clone https://github.com/EsauPR/remote-code.git && cd remote-code && ./install.sh
```

Installs `rcode` and `rzed` in `~/.local/bin` and `vsc.sh` in `~/.local/share/rcode`
(`--prefix DIR` to change it, `--uninstall` to remove it).

**Requirements:** `ssh`, [`fzf`](https://github.com/junegunn/fzf) and `code` (VS Code with the Remote-SSH extension) and/or `zed`.
On the server, [`zoxide`](https://github.com/ajeetdsouza/zoxide) is optional but recommended.

## Usage

```
rcode                    # pick host and folder with fzf → VS Code
rcode my-host            # skips host selection
rcode my-host ~/project  # opens directly
rzed ...                 # same, but opens Zed (or RCODE_EDITOR=zed rcode)
```

In the folder picker: **Enter** opens the highlighted one, **Tab** enters it and lists its
subfolders (the second line is the parent). If nothing matches, what you type is used as the path
(`~` expands to the server's HOME). Recent hosts and folders come first
(`~/.local/state/rcode/history`).

Folder candidates on the server: the output of `zoxide query -l` first, then the top-level
directories of `$HOME`, `/srv`, `/opt`, `/var/www` and repos with `.git` (depth 3). If the
server has no zoxide, `rcode` warns you.

### Hiding hosts from the picker

Hosts that are not working servers (e.g. `github.com`):

```bash
RCODE_EXCLUDE="github-personal aur.archlinux.org" rcode
# or permanently, in ~/.config/rcode/config:
RCODE_EXCLUDE="github-personal aur.archlinux.org"
```

Patterns with `*`, `?` and `!` are ignored, and `Include` directives are followed.

### Reusing SSH connections

So that listing folders does not ask for authentication several times, add this to your `~/.ssh/config`
(the installer does **not** modify it, it only suggests it; see [`examples/ssh-config`](examples/ssh-config)):

```
Host *
    ControlMaster auto
    ControlPath ~/.ssh/cm/%C
    ControlPersist 10m
    ServerAliveInterval 30
```

and create the directory: `mkdir -m 700 -p ~/.ssh/cm`.

## `vsc` / `vsz` on the server

Inside an SSH session, `vsc [path]` (VS Code) or `vsz [path]` (Zed) print the local command,
copy it to your clipboard via **OSC 52** and show a clickable link (**OSC 8**):
`vscode://vscode-remote/ssh-remote+HOST/path` or `zed://ssh/HOST/path`.

Install on a server by running this from your local machine. It connects over SSH (`my-host` is the
server's name in your `~/.ssh/config`), shows the diff, asks for confirmation and backs up the rc file:

```bash
curl -fsSL https://raw.githubusercontent.com/EsauPR/remote-code/main/install.sh | bash -s -- --server my-host
```

Options go after `--server my-host`: `--alias local-alias`, `--zoxide`, `--yes`. From a clone it is the same:
`./install.sh --server my-host [--alias local-alias] [--zoxide]`.

This adds a block between `# >>> rcode >>>` and `# <<< rcode <<<` to the server's `~/.bashrc` (or `.zshrc`)
with `export VSC_HOST=<alias>` and the `source` of `vsc.sh`. `--zoxide` also adds `zoxide init`.
To remove it: `curl -fsSL https://raw.githubusercontent.com/EsauPR/remote-code/main/install.sh | bash -s -- --server my-host --uninstall`
(or `./install.sh --server my-host --uninstall` from a clone).

Notes: OSC 52 copying depends on your terminal; inside tmux you need
`set -g allow-passthrough on`.

## Updating

```bash
rcode --update          # compares with the latest GitHub release, asks, and re-runs its installer
rcode --update --yes    # without asking
```

It installs into the same prefix `rcode` lives in, and never touches `~/.config/rcode` or your history.
To pin a specific version: `curl -fsSL https://raw.githubusercontent.com/EsauPR/remote-code/v0.1.0/install.sh | RCODE_REF=v0.1.0 bash`.

Servers keep their own copy of `vsc.sh`. After updating, refresh each one with
the same `--server my-host` command (if the block is already in the rc file, only `vsc.sh` is replaced).

## Releasing (maintainers)

1. Bump `VERSION="X.Y.Z"` in `bin/rcode` and commit.
2. `scripts/release.sh X.Y.Z` — checks a clean `main`, runs the tests, pushes, creates the annotated tag `vX.Y.Z` and the GitHub release.

## Tests

With [bats-core](https://github.com/bats-core/bats-core) (they use stubs for `ssh`, `fzf`, `code` and `zed`, and do not touch your configuration):

```bash
bats test/
```

The tests put stubs of `ssh`, `fzf`, `curl`, `code` and `zed` first in `PATH`, so they never open a real editor or connect anywhere.

## License

MIT
