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

It asks once for your git name and email (stored locally, not in the repo),
then for your `sudo` password (apt needs it; `chsh` near the end may prompt
again if Homebrew takes more than 15 minutes). It then:

1. adds Docker's apt repository and installs the apt packages, including the
   ones Homebrew needs,
2. installs Homebrew, trusts the third-party taps and installs everything else
   with brew (chezmoi included, which takes over from the downloaded copy),
3. installs the latest Node LTS and Terraform with mise (a project's
   `.terraform-version` picks its Terraform), then the global npm packages under
   `npm:` (Claude Code, Codex, T3 Code...) with npm,
4. downloads oh-my-zsh, the plugins in `home/.chezmoidata/zsh.yaml`, pinned
   `talosctl` and `amtool`, and Claude subagent skill packs,
5. writes `~/.zshrc`, `~/.gitconfig`, `~/.config/starship.toml` and tool configs,
6. switches on the secret-scanning git hook for this repo,
7. makes zsh your login shell and adds you to the `docker` group.

The Homebrew step takes a while. If a single brew package fails, `brew bundle`
still tries the rest and exits with a `!!` warning; re-run `chezmoi apply` to
retry (or fix `packages.yaml` first).

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
- Unlock Bitwarden (skipped during the first install because the vault is
  locked) and sign in to GitHub, then run `chezmoi apply` once to write your
  SSH signing key, secrets, Talos/kube configs, and clone the projects in
  `home/.chezmoidata/projects.yaml` into `~/Projects`:
  ```sh
  bw login                               # once per machine
  export BW_SESSION="$(bw unlock --raw)"
  gh auth login
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

Edit the shared file, then `chezmoi apply`. These shared instructions are not enforced by git
hooks (Claude Code does enforce the 72-character commit header limit via its `PreToolUse` hook
below).

## Claude Code

Installed with npm (`@anthropic-ai/claude-code`, on mise's Node), so `claude update`
and auto-updates work. Only hand-written config
is tracked, so it follows me to every machine:

| Tracked | Why |
|---|---|
| `~/.claude/settings.json` (selected keys) | The keys in `home/.chezmoidata/claude.yaml`: model and effort, attribution (off), theme, notifications, and managed hooks. Other keys, such as hooks plugins add, are left alone |
| `~/.claude/CLAUDE.md` | The shared instructions plus a Claude-only section (`dot_claude/CLAUDE.md.tmpl`) telling the main session when to use the subagents below |
| `~/.claude/agents/` | Subagents to save usage, after [this post](https://www.andreagrandi.it/posts/claude-code-subagents-to-save-usage/): `implementer` (Sonnet) writes code, `scoper` (Haiku) gathers facts, `shipper` (Haiku) commits and opens PRs, `reviewer` (Opus) only for risky changes, and `wordpress-security-reviewer` (Opus, high effort) for read-only WordPress security audits. Opus in the main session plans and reviews |
| `~/.claude/hooks/` | `check-commit-headers.sh` (`PreToolUse` Bash hook that blocks `git push` if a commit header exceeds 72 characters) |
| `~/.claude/agent-skills/` | Pinned, checksum-verified skill packs read only by subagents (such as `wordpress-security`), kept out of `~/.claude/skills` so the main session never loads them |
| `commands/`, `keybindings.json` | Add with `chezmoi add` when created |

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
- **amtool** (Alertmanager CLI) is pinned to the cluster's Alertmanager version
  in `home/.chezmoidata/alertmanager.yaml` (Homebrew doesn't package
  Alertmanager) and extracted to `~/.local/bin/amtool`.
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
.githooks/pre-commit        gitleaks secret scan on staged commits
AGENTS.md, CLAUDE.md        repo-level instructions for AI coding agents
home/
  .chezmoi.toml.tmpl        first-run prompts (name, email), umask and WSL detection
  .chezmoiignore            keeps caches, credentials and locked Bitwarden targets out of apply
  .chezmoiexternal.toml.tmpl  oh-my-zsh + plugins, pinned talosctl/amtool, Claude agentSkills
  .chezmoidata/
    alertmanager.yaml       pinned amtool version + checksums
    claude.yaml             Claude Code settings, hooks and agentSkills
    packages.yaml           taps, brew, cask, mise (Node, Terraform), npm, apt and Docker lists
    projects.yaml           repos to clone into ~/Projects
    secrets.yaml            Bitwarden SSH key item and secret env vars
    system.yaml             shell locale
    talos.yaml              pinned talosctl version + checksums
    zsh.yaml                oh-my-zsh plugins
  .chezmoitemplates/
    ai-instructions.md      shared AI assistant preferences
    bitwarden-*             exact-name Bitwarden helpers and vault-unlocked check
    signing-public-key      SSH signing key lookup (Bitwarden or ~/.ssh/id_ed25519.pub)
  run_onchange_before_10-install-packages.sh.tmpl  re-runs when package lists change
  run_onchange_after_20-install-node.sh.tmpl       Node LTS + Terraform via mise, global npm packages
  run_once_after_80-enable-git-hooks.sh.tmpl       turns on the gitleaks hook
  run_after_85-kube-config.sh                      creates ~/.kube/config if missing
  run_once_after_90-set-login-shell.sh             sets /usr/bin/zsh as login shell
  run_after_95-clone-projects.sh.tmpl              clones projects.yaml repos into ~/Projects
  dot_zshrc.tmpl            -> ~/.zshrc
  dot_gitconfig.tmpl        -> ~/.gitconfig
  dot_default-npm-packages.tmpl  -> ~/.default-npm-packages (reinstalled by mise on Node upgrades)
  dot_cache/terraform/plugin-cache/  creates ~/.cache/terraform/plugin-cache
  dot_claude/
    CLAUDE.md.tmpl          -> ~/.claude/CLAUDE.md
    modify_settings.json.tmpl  merges .chezmoidata/claude.yaml into ~/.claude/settings.json
    agents/                 Claude Code subagents
    hooks/                  Claude Code hooks (check-commit-headers.sh)
  dot_codex/AGENTS.md.tmpl  -> ~/.codex/AGENTS.md
  dot_config/
    git/allowed_signers.tmpl  -> ~/.config/git/allowed_signers
    mise/conf.d/settings.toml -> mise settings (reads .terraform-version)
    opencode/AGENTS.md.tmpl   -> ~/.config/opencode/AGENTS.md
    sops/private_age/         -> ~/.config/sops/age/keys.txt (from Bitwarden)
    starship.toml             -> ~/.config/starship.toml
    terraform/dot_terraformrc -> ~/.config/terraform/.terraformrc (TF_CLI_CONFIG_FILE;
                              providers cached in ~/.cache/terraform, no ~/.terraform.d)
    zsh/private_secrets.zsh.tmpl -> ~/.config/zsh/secrets.zsh (from Bitwarden)
  dot_local/bin/            -> ~/.local/bin/{pbcopy,pbpaste} (WSL clipboard helpers)
  private_dot_cloudflared/  -> ~/.cloudflared/{cert.pem,credentials.json} (from Bitwarden)
  private_dot_ssh/          -> ~/.ssh/{id_ed25519,id_ed25519.pub} (from Bitwarden)
  private_dot_talos/        -> ~/.talos/config (from Bitwarden)
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
| `~/.ssh/id_ed25519`, `~/.ssh/id_ed25519.pub` | Bitwarden SSH key item "WSL SSH Key" (`sshKey.item` in `.chezmoidata/secrets.yaml`, must be ed25519). Used to log in and to sign commits: `.gitconfig` turns signing on in the same apply. |
| `~/.config/sops/age/keys.txt` | Bitwarden secure note "age private key" (used by `sops`) |
| `~/.cloudflared/cert.pem` | Bitwarden secure note "Cloudflare Tunnel Cert" |
| `~/.cloudflared/credentials.json` | Bitwarden secure note "Cloudflare Tunnel Credentials" |
| `~/.talos/config` | Bitwarden secure note "Talos Config" (talosctl admin config, with endpoints) |
| `~/.config/zsh/secrets.zsh` | Environment variables (API keys) listed in `.chezmoidata/secrets.yaml`, each from a Bitwarden Secure note (its text) or a Login (its Password). Sourced by `.zshrc`. |

To add another: create the template under `home/`, read the item with
`{{ includeTemplate "bitwarden-secret" "Item name" }}`, and add the target to the
locked-vault block in `home/.chezmoiignore`.

**Item names must be exact and unique.** The helper (`home/.chezmoitemplates/bitwarden-secret`)
matches the item name exactly, case included. chezmoi's own `bitwarden "item" "name"` isn't
used because `bw get item` does a full-text search, names *and* note contents, so a note that
merely mentions "Cloudflare Tunnel Cert" made that lookup fail with "More than one result".
A Secure note gives its text; a Login gives its Password; an SSH key item
(`home/.chezmoitemplates/bitwarden-ssh-key`) gives its private or public key.

**API keys as environment variables:** add `name` (the variable) and `item` (a Bitwarden
Secure note holding the key as its text, or a Login holding it as the password) to `secretEnv` in `home/.chezmoidata/secrets.yaml`,
unlock Bitwarden, run `bw sync` (new items aren't seen until then) and `chezmoi apply`. New shells export it. Currently: `UNIFI_API_KEY`
(item "UniFi API Key") and `GITHUB_PUBLIC_TOKEN` (item "Github Public Token").

For anything else, two options, simplest first:

- **Local file:** put tokens and exports in `~/.zshrc.local`. It's sourced by
  `.zshrc` and never tracked.
- **Pulled from Bitwarden at apply time:** run `bw login` and
  `export BW_SESSION="$(bw unlock --raw)"`, then reference
  items in any template, for example in `home/private_dot_config/gh/private_hosts.yml.tmpl`:
  ```
  {{ includeTemplate "bitwarden-secret" "GitHub token" }}
  ```
  The repo only holds the item name; the value is fetched when you run `chezmoi apply`.
