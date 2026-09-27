# dotfiles

My Ubuntu (WSL) dev environment, managed with [chezmoi](https://chezmoi.io).
Packages come from Homebrew on Linux, with apt for anything brew doesn't have.
Shell is zsh + oh-my-zsh with the starship prompt. No secrets live in this repo.

## Fresh machine

Steps 1 and 2 are the only manual work; the rest is one command.

### Step 1: Install Ubuntu in WSL (Windows)

In PowerShell as Administrator:

```powershell
wsl --install -d Ubuntu
```

Reboot if asked, then open **Ubuntu** from the Start menu and create your
Linux username and password. You'll need that password during the install.

### Step 2: Install everything

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin" init --apply l3rady
```

This downloads chezmoi, clones this repo into `~/.local/share/chezmoi` and
applies it. It needs `curl` and `git`, which the WSL Ubuntu image already has
(if not: `sudo apt-get update && sudo apt-get install -y curl git`). The repo is
public, so no GitHub login is needed.

It asks for your `sudo` password (apt needs it) and for your git name and email
once (stored locally, not in the repo). It then:

1. adds Docker's apt repository and installs the apt packages, including the
   ones Homebrew needs,
2. installs Homebrew, trusts the third-party taps and installs everything else
   with brew (chezmoi included, which takes over from the downloaded copy),
3. downloads oh-my-zsh and the plugins in `home/.chezmoidata/zsh.yaml`,
4. writes `~/.zshrc`, `~/.gitconfig` and `~/.config/starship.toml`,
5. switches on the secret-scanning git hook for this repo,
6. makes zsh your login shell and adds you to the `docker` group.

The Homebrew step takes a while. If a single brew package fails, the rest
still install and you'll see a `!!` warning; fix the list and run `chezmoi apply`.

<details>
<summary>Alternative: clone first, then run install.sh</summary>

Does the same thing, if you'd rather see the code before running it:

```sh
sudo apt-get update && sudo apt-get install -y git curl
git clone https://github.com/l3rady/dotfiles ~/.local/share/chezmoi
bash ~/.local/share/chezmoi/install.sh
```

</details>

### Step 3: Finish up

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
install.sh                  bootstrap from an existing clone (alternative to the one-liner)
.chezmoiroot                tells chezmoi the dotfiles live in home/
home/
  .chezmoi.toml.tmpl        first-run prompts (name, email) and WSL detection
  .chezmoidata/
    packages.yaml           taps, brew, cask, apt and Docker package lists
    zsh.yaml                oh-my-zsh plugins
  .chezmoiexternal.toml.tmpl  oh-my-zsh + plugin downloads
  run_onchange_before_10-install-packages.sh.tmpl  re-runs when package lists change
  run_once_after_80-enable-git-hooks.sh.tmpl  turns on the gitleaks hook
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
| `.githooks/pre-commit` | Runs `gitleaks` on every commit and blocks it if anything looks like a key, token or password. chezmoi switches it on (`core.hooksPath`) during install. |
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
