# dotfiles

My Ubuntu (WSL) dev environment, managed with [chezmoi](https://chezmoi.io).
Packages come from Homebrew on Linux, with apt for anything brew doesn't have.
Shell is zsh + oh-my-zsh with the starship prompt. No secrets live in this repo.

## Fresh machine

Everything below "Step 3" is automated. Steps 1 and 2 are the only manual work.

### Step 1: Install Ubuntu in WSL (Windows)

In PowerShell as Administrator:

```powershell
wsl --install -d Ubuntu
```

Reboot if asked, then open **Ubuntu** from the Start menu and create your
Linux username and password. You'll need that password during the install.

### Step 2: Prerequisites (Ubuntu)

A fresh Ubuntu image normally has `git` and `curl` already; this makes sure:

```sh
sudo apt-get update && sudo apt-get install -y git curl
```

You also need a way to clone this repo. There's no `gh` or SSH key yet on a
fresh machine, so if the repo is private, clone over HTTPS and enter a GitHub
personal access token (kept in Bitwarden) when git asks for a password.

### Step 3: Clone and bootstrap

```sh
git clone https://github.com/<you>/dotfiles ~/.local/share/chezmoi
bash ~/.local/share/chezmoi/install.sh
```

`install.sh` asks for your `sudo` password (apt needs it) and for your git name
and email once (stored locally, not in the repo). It then:

1. installs the apt packages Homebrew needs, then Homebrew itself,
2. installs chezmoi and runs `chezmoi init --apply`, which
3. adds Docker's apt repository and installs the apt + Docker packages,
4. trusts the third-party taps and installs everything else with brew,
5. downloads oh-my-zsh and the plugins in `home/.chezmoidata/zsh.yaml`,
6. writes `~/.zshrc`, `~/.gitconfig` and `~/.config/starship.toml`,
7. makes zsh your login shell and adds you to the `docker` group.

The Homebrew step takes a while. If a single brew package fails, the rest
still install and you'll see a `!!` warning; fix the list and run `chezmoi apply`.

### Step 4: Finish up

- Close the terminal and open a new one so zsh, starship and the `docker`
  group take effect.
- If the install printed "Enabled systemd in /etc/wsl.conf", run
  `wsl --shutdown` in PowerShell and reopen Ubuntu. Docker needs systemd.
- Run `gh auth login`, then clone your projects.

## Day to day

| I want to... | Run |
|---|---|
| Change a dotfile | `chezmoi edit ~/.zshrc` then `chezmoi apply` |
| Start tracking a new file | `chezmoi add ~/.config/foo/config` |
| Add a package | edit `home/.chezmoidata/packages.yaml`, then `chezmoi apply` |
| Add a package from a third-party tap | add the tap under `taps:` and the formula as `owner/tap/name` under `brew:` |
| See what would change | `chezmoi diff` |
| Commit and push | `chezmoi cd` then normal `git add/commit/push` |
| Pull changes on another machine | `chezmoi update` |

## Layout

```
install.sh                  one-shot bootstrap for a fresh machine
.chezmoiroot                tells chezmoi the dotfiles live in home/
home/
  .chezmoi.toml.tmpl        first-run prompts (name, email) and WSL detection
  .chezmoidata/
    packages.yaml           taps, brew, cask, apt and Docker package lists
    zsh.yaml                oh-my-zsh plugins
  .chezmoiexternal.toml.tmpl  oh-my-zsh + plugin downloads
  run_onchange_before_10-install-packages.sh.tmpl  re-runs when package lists change
  run_once_after_90-set-login-shell.sh
  dot_zshrc.tmpl            -> ~/.zshrc
  dot_gitconfig.tmpl        -> ~/.gitconfig
  dot_config/starship.toml  -> ~/.config/starship.toml
```

## Secrets

This repo is safe to make public because secrets never go into it.

### What stops a secret being committed

| Layer | What it does |
|---|---|
| `.githooks/pre-commit` | Runs `gitleaks` on every commit and blocks it if anything looks like a key, token or password. `install.sh` switches it on (`core.hooksPath`). |
| chezmoi `add.secrets = "error"` | `chezmoi add` refuses a file that contains a secret, so it never reaches the repo in the first place. |
| `.gitignore` | Blocks known credential files (SSH keys, `.env`, kubeconfig, talosconfig, `*.tfvars`, ...) even if you try to `git add` them. |
| GitHub push protection | GitHub scans pushes to public repos and rejects known token formats. |

To scan the whole history by hand: `chezmoi cd && gitleaks git --redact`.

If a secret ever does get pushed, **rotate it first**. Removing it from git
doesn't help once it's been public.

### Where secrets live instead

Secrets stay in Bitwarden. Two options, simplest first:

- **Local file:** put tokens and exports in `~/.zshrc.local`. It's sourced by
  `.zshrc` and never tracked.
- **Pulled from Bitwarden at apply time:** add `bitwarden-cli` to the brew list,
  run `bw login` and `export BW_SESSION="$(bw unlock --raw)"`, then reference
  items in any template, for example in `home/private_dot_config/gh/private_hosts.yml.tmpl`:
  ```
  {{ (bitwarden "item" "GitHub token").login.password }}
  ```
  The repo only holds the item name; the value is fetched when you run `chezmoi apply`.
