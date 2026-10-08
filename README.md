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
- Run `gh auth login`, then `chezmoi apply` again: it clones the projects
  listed in `home/.chezmoidata/projects.yaml` into `~/Projects`.
- Pull secrets from Bitwarden (skipped during the first install because the
  vault is locked):
  ```sh
  bw login                               # once per machine
  export BW_SESSION="$(bw unlock --raw)"
  chezmoi apply
  ```

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

## Git

`~/.gitconfig` (from `home/dot_gitconfig.tmpl`) is set up for a linear, rebase-based workflow:

| Setting | Effect |
|---|---|
| `pull.rebase`, `rebase.autoStash` | `git pull` rebases your commits on top, stashing uncommitted work around it |
| `rebase.autoSquash`, `rebase.updateRefs` | `--fixup` commits squash in automatically; stacked branches move with a rebase |
| `rerere.enabled` | Remembers conflict resolutions, so repeated rebases don't ask twice |
| `merge.conflictStyle = zdiff3` | Conflict markers include the common ancestor |
| `push.autoSetupRemote`, `fetch.prune` | First push sets the upstream; deleted remote branches are pruned |
| `commit.gpgsign`, `gpg.format = ssh` | Commits and tags are signed with `~/.ssh/id_ed25519` (only when that key exists) |

For GitHub to show signed commits as **Verified**, the public key must also be added to
GitHub as a *signing* key (once per key):

```sh
gh auth refresh -h github.com -s admin:ssh_signing_key
gh ssh-key add ~/.ssh/id_ed25519.pub --type signing --title "$(hostname) signing"
```

## AI coding assistants

Personal preferences for Claude Code, Codex and opencode live in **one file**:
`home/.chezmoitemplates/ai-instructions.md`. It covers conventional commits, branch naming
(`feature/ABC-123-short-name`, `fix/42-short-name`), the rebase-only workflow, Homebrew-first
installs, chezmoi, and secret handling. chezmoi writes it to each tool's global location:

| Tool | File |
|---|---|
| Claude Code | `~/.claude/CLAUDE.md` |
| Codex | `~/.codex/AGENTS.md` |
| opencode | `~/.config/opencode/AGENTS.md` |

Edit the shared file, then `chezmoi apply`. These are instructions only; nothing is enforced by
git hooks.

## Claude Code

Installed with Homebrew (`claude-code@latest` cask). Only hand-written config
is tracked, so it follows me to every machine:

| Tracked | Why |
|---|---|
| `~/.claude/settings.json` (selected keys) | The keys in `home/.chezmoidata/claude.yaml`: theme, notifications, status line, the context-mode plugin. Other keys, such as hooks plugins add, are left alone |
| `~/.claude/CLAUDE.md`, `agents/`, `commands/`, `keybindings.json` | Add with `chezmoi add` when created |

Deliberately **not** tracked, and blocked by `.chezmoiignore` so they can't be
added by accident: `~/.claude.json` (account, machine ID, project history),
`~/.claude/.credentials.json` (login token), `settings.local.json`
(per-machine overrides), and session data such as `projects/`, `sessions/`,
`history.jsonl` and `file-history/`. Skills and plugins synced from claude.ai
arrive on their own.

`settings.json` is **merged, not overwritten**: `dot_claude/modify_settings.json.tmpl` sets
only the keys listed in `home/.chezmoidata/claude.yaml` and keeps everything else, so plugins
can add their own hooks without causing drift. If you change one of those keys in Claude Code
(`/config`), copy the new value into `claude.yaml` or the next `chezmoi apply` will put it back.
(`chezmoi re-add` doesn't work for this file.)
Secrets such as API keys in `env` or MCP server tokens never go in `claude.yaml`; they
come from Bitwarden via a template.

## Homelab (Talos + Kubernetes)

- **talosctl** is pinned to the cluster's Talos version in
  `home/.chezmoidata/talos.yaml` (Homebrew only has the latest, which can be
  ahead of the cluster). After upgrading the cluster, update the version and
  checksums there.
- **`~/.talos/config`** comes from Bitwarden (see Secrets). If you change it
  (e.g. new endpoints), paste the new version into the "Talos Config" note.
- **`~/.kube/config`** is never stored. When it's missing, `chezmoi apply`
  asks the cluster for an admin kubeconfig (needs `~/.talos/config` and the
  home network), so each machine gets its own certificate.

## Projects

Repositories in `home/.chezmoidata/projects.yaml` are cloned into
`~/Projects` once `gh auth login` is done. **Add new projects there** as
`owner/name`; folders that already exist are never touched.

## Layout

```
install.sh                  bootstrap from an existing clone (alternative to the one-liner)
.chezmoiroot                tells chezmoi the dotfiles live in home/
home/
  .chezmoi.toml.tmpl        first-run prompts (name, email) and WSL detection
  .chezmoidata/
    packages.yaml           taps, brew, cask, apt and Docker package lists
    zsh.yaml                oh-my-zsh plugins
    talos.yaml              pinned talosctl version + checksums
    projects.yaml           repos to clone into ~/Projects
    claude.yaml             Claude Code settings chezmoi manages
  .chezmoitemplates/ai-instructions.md  shared AI assistant preferences
  .chezmoiexternal.toml.tmpl  oh-my-zsh + plugin downloads
  run_onchange_before_10-install-packages.sh.tmpl  re-runs when package lists change
  run_once_after_80-enable-git-hooks.sh.tmpl  turns on the gitleaks hook
  run_after_85-kube-config.sh           creates ~/.kube/config if missing
  run_after_95-clone-projects.sh.tmpl   clones projects.yaml repos into ~/Projects
  run_once_after_90-set-login-shell.sh
  dot_zshrc.tmpl            -> ~/.zshrc
  dot_gitconfig.tmpl        -> ~/.gitconfig
  dot_config/starship.toml  -> ~/.config/starship.toml
  dot_claude/modify_settings.json.tmpl  merges .chezmoidata/claude.yaml into ~/.claude/settings.json
  dot_config/terraform/dot_terraformrc  -> ~/.config/terraform/.terraformrc (TF_CLI_CONFIG_FILE;
                            providers cached in ~/.cache/terraform, no ~/.terraform.d)
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

Secrets stay in Bitwarden and are written out by chezmoi only while the vault
is unlocked (checked with `bw status`, which never prompts). While it's locked,
or `BW_SESSION` holds an old session key, those files are skipped rather than
emptied, so `chezmoi apply` never deletes them and never asks for the master
password. Unlocking again (`export BW_SESSION="$(bw unlock --raw)"`) is only
needed when a secret has changed or on a new machine.

| File | Comes from |
|---|---|
| `~/.config/sops/age/keys.txt` | Bitwarden secure note "age private key" (used by `sops`) |
| `~/.cloudflared/cert.pem` | Bitwarden secure note "Cloudflare Tunnel Cert" |
| `~/.cloudflared/credentials.json` | Bitwarden secure note "Cloudflare Tunnel Credentials" |
| `~/.talos/config` | Bitwarden secure note "Talos Config" (talosctl admin config, with endpoints) |
| `~/.config/zsh/secrets.zsh` | Environment variables (API keys) listed in `.chezmoidata/secrets.yaml`, each from a Bitwarden Secure note (its text) or a Login (its Password). Sourced by `.zshrc`. |

To add another: create the template under `home/`, read the item with the
`bitwarden` function, and add the target to the locked-vault block in
`home/.chezmoiignore`.

**API keys as environment variables:** add `name` (the variable) and `item` (a Bitwarden
Secure note holding the key as its text, or a Login holding it as the password) to `secretEnv` in `home/.chezmoidata/secrets.yaml`,
unlock Bitwarden, run `bw sync` (new items aren't seen until then) and `chezmoi apply`. New shells export it. Currently: `UNIFI_API_KEY`
(item "UniFi API Key").

For anything else, two options, simplest first:

- **Local file:** put tokens and exports in `~/.zshrc.local`. It's sourced by
  `.zshrc` and never tracked.
- **Pulled from Bitwarden at apply time:** run `bw login` and
  `export BW_SESSION="$(bw unlock --raw)"`, then reference
  items in any template, for example in `home/private_dot_config/gh/private_hosts.yml.tmpl`:
  ```
  {{ (bitwarden "item" "GitHub token").login.password }}
  ```
  The repo only holds the item name; the value is fetched when you run `chezmoi apply`.
