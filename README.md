# dotfiles

My Ubuntu (WSL and headless VM) dev environment, managed with [chezmoi](https://chezmoi.io).
Packages come from Homebrew on Linux, with apt for anything brew doesn't have.
Shell is zsh + oh-my-zsh with the starship prompt. No secrets live in this repo.

## Fresh machine

Steps 1 and 2 are the only manual work; the rest is one command.

### Step 1a: Install Ubuntu in WSL (Windows)

In PowerShell as Administrator:

```powershell
wsl --install -d Ubuntu
```

Reboot if asked, then open **Ubuntu** from the Start menu and create your
Linux username and password. You'll need that password during the install.

### Step 1b: Or prepare a headless Ubuntu VM

On a fresh Ubuntu LTS VM (KVM/QEMU, Proxmox, VMware, cloud VM), SSH in and make
sure `curl` and `git` are installed:

```sh
sudo apt-get update && sudo apt-get install -y curl git
```

`home/.chezmoi.toml.tmpl` automatically detects native Linux VMs (`isVM = true`
via `systemd-detect-virt --vm`, always `false` on WSL), so VM guest packages and
systemd tweaks are enabled automatically without changing WSL installs.

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
- On a headless Ubuntu VM, configure remote access for T3 Code once logged in
  over SSH (installs/updates `t3code.service` and walks through T3 Connect or
  LAN/tailnet setup):
  ```sh
  t3 up --headless
  ```
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

## Shell environment

Shell configuration is split between a shared, secret-free POSIX environment and
interactive Zsh config:

| File | Purpose |
|---|---|
| `~/.config/shell/env.sh` (`home/dot_config/shell/env.sh.tmpl`) | POSIX-compatible, secret-free environment: Homebrew (`brew shellenv sh`), `mise` shims ahead of Homebrew, `~/.local/bin`, locale, `EDITOR`, `TF_CLI_CONFIG_FILE`, `CHECKPOINT_DISABLE`, and WSL `BROWSER`/`GDK_DPI_SCALE`. |
| `~/.bashrc` (`home/dot_bashrc.tmpl`) | Minimal Bash config that sources `~/.config/shell/env.sh` without loading interactive Zsh plugins or secrets. |
| `~/.zshrc` (`home/dot_zshrc.tmpl`) | Interactive Zsh: sources `~/.config/shell/env.sh`, then loads oh-my-zsh, plugins, aliases, `~/.config/zsh/secrets.zsh`, `~/.zshrc.local`, fzf, starship, and zoxide. |

Keeping `~/.config/shell/env.sh` and `~/.bashrc` free of secrets and interactive hooks lets
scripts and non-interactive Bash sessions resolve Homebrew, `mise` (Node, Terraform,
`claude`, `codex`), and `~/.local/bin` without inheriting `~/.config/zsh/secrets.zsh` or
`~/.zshrc.local`.

### AI coding harnesses in clean Bash

Although the interactive login shell is Zsh, AI coding harnesses are configured to run
their shell tools in non-interactive GNU Bash (avoiding Zsh/Bash syntax mismatches and
bloated oh-my-zsh shell snapshots):

- **Claude Code:** `home/.chezmoidata/claude.yaml` sets `env.CLAUDE_CODE_SHELL` to
  `/usr/bin/bash`, `env.CLAUDE_ENV_FILE` to `~/.config/shell/env.sh` (expanded per host),
  and managed `permissions.deny` rules blocking direct `Read` access to managed secret
  files and `.env*` — all merged into `~/.claude/settings.json` by
  `modify_settings.json.tmpl` without clobbering unmanaged `env` keys,
  `permissions.defaultMode`, or user permission rules.
- **Codex CLI:** `home/.chezmoidata/codex.yaml` and `home/dot_codex/modify_config.toml.tmpl`
  merge `allow_login_shell = false`, `[shell_environment_policy]` `exclude` patterns
  (`BW_SESSION`, `*_SECRET*`, `*_TOKEN`, `*_KEY`), and
  `[shell_environment_policy.set] SHELL = "/usr/bin/bash"` into `~/.codex/config.toml`
  while preserving unmanaged runtime keys.
- **Interactive Zsh launchers:** `home/dot_config/zsh/aliases/agents.zsh.tmpl` wraps
  `claude`, `codex`, `agy`, `t3`, and `herdr` so launching them from Zsh passes
  `SHELL=/usr/bin/bash` and `CLAUDE_CODE_SHELL=/usr/bin/bash` and scrubs `BW_SESSION`,
  every variable in `home/.chezmoidata/secrets.yaml` (`secretEnv`), and common cloud
  credential vars by default. Opt in to a scoped token for a single session when needed:
  ```sh
  AI_AGENT_ALLOW_ENV=GITHUB_PUBLIC_TOKEN claude
  AI_AGENT_ALLOW_ENV=GITHUB_PUBLIC_TOKEN,UNIFI_API_KEY codex
  ```

## Remote sessions (headless VM)

`tmux` and `mosh` are installed via `home/.chezmoidata/packages.yaml`, and `~/.tmux.conf`
is managed by chezmoi (`home/dot_tmux.conf`) with mouse mode, 50,000-line scrollback,
truecolor, OSC 52 clipboard passthrough, and `/usr/bin/zsh` as the default shell.

### Persistent sessions with tmux

Run long-lived AI coding sessions (`claude`, `codex`, `agy`, `herdr`) inside `tmux` so
they survive SSH disconnects and laptop sleep:

```sh
# Attach to an existing session or create it if missing
tmux new-session -As ai

# Detach without stopping running commands: Ctrl-b d
# Reattach later over SSH:
tmux attach -t ai
```

Useful bindings in `~/.tmux.conf` (default prefix `Ctrl-b`):

| Binding | Action |
|---|---|
| `prefix \|` / `prefix -` | Split pane horizontally / vertically in current directory |
| `prefix c` | New window in current directory |
| `prefix h/j/k/l` (or arrows) | Move between panes |
| `prefix H/J/K/L` | Resize active pane |
| `prefix r` | Reload `~/.tmux.conf` |

For flaky mobile or roaming connections, `mosh` keeps the SSH session alive across IP
changes (requires UDP ports `60000-61000` reachable on the VM). If non-interactive SSH
does not include Homebrew on `PATH`, pass the server path explicitly:

```sh
mosh --server=/home/linuxbrew/.linuxbrew/bin/mosh-server user@vm-host -- tmux new-session -As ai
```

### Headless authentication over SSH

On a VM without a local desktop browser:

- **Bitwarden & GitHub:** both work directly in the terminal (`bw login`,
  `export BW_SESSION="$(bw unlock --raw)"`, and `gh auth login` using the web device-code
  flow).
- **Device-code / URL login:** tools like `gh auth login`, `t3 up --headless`, and CLI
  logins that print a URL + code can be approved in a browser on your laptop.
- **Localhost OAuth callbacks:** if an AI CLI (`claude`, `codex`, `agy`) opens a callback
  listener on `127.0.0.1:<port>` on the VM, forward that port from your laptop over SSH
  before completing the login in your local browser:
  ```sh
  ssh -L <port>:127.0.0.1:<port> user@vm-host
  ```

## Ubuntu VM (headless)

`home/.chezmoi.toml.tmpl` sets `isWSL` and `isVM` in `~/.config/chezmoi/chezmoi.toml`.
On WSL, `isWSL = true` and `isVM = false`, so WSL installs skip VM-only tweaks. On a
native Linux VM (detected via `systemd-detect-virt --vm`), `isVM = true` enables:

- **Guest packages (`packages.vm_apt`):** installs `qemu-guest-agent` and `openssh-server`
  via apt in `run_onchange_before_10-install-packages.sh.tmpl`.
- **Guest services & disk reclaim (`run_onchange_after_35-configure-vm.sh.tmpl`):**
  enables and starts `fstrim.timer` (reclaims freed blocks from Docker layers, caches,
  and `node_modules` on thin-provisioned disks), `qemu-guest-agent.service`, and
  `ssh.socket`/`ssh.service`.
- **Systemd user lingering & background AI services:** runs
  `loginctl enable-linger "$USER"` so user services start on boot and keep running after
  SSH logout, and installs T3 Code's built-in systemd user unit (`t3 service install`)
  when `t3` is present.

`~/.config/systemd/user/t3code.service` is owned by `t3` itself (and ignored in
`home/.chezmoiignore`) so `t3 update` and `t3 up` can update its versioned launcher
without conflicting with chezmoi. Useful commands on the VM:

```sh
# Configure T3 Connect / LAN access and ensure the background service is running
t3 up --headless

# Check service state and logs
t3 status
systemctl --user status t3code.service
journalctl --user -u t3code.service -f

# Optional: protect T3 Code server from OOM kills under agent memory pressure
t3 service protect
```

To force VM mode on a bare-metal headless Ubuntu host, set `isVM = true` under `[data]`
in `~/.config/chezmoi/chezmoi.toml` and run `chezmoi apply`.

### Provisioning a fresh VM with cloud-init

`vm/cloud-init.yaml.example` (outside `home/`, so chezmoi never copies it into `~`)
provisions a fresh Ubuntu LTS VM with a sudo user, key-only SSH, locale/timezone,
`curl`, `git`, `openssh-server`, `qemu-guest-agent`, and `fstrim.timer`.

1. Copy the template to an untracked local file and fill in your username and SSH public key:
   ```sh
   cp vm/cloud-init.yaml.example vm/cloud-init.yaml
   ```
   (`vm/cloud-init.yaml` is gitignored so local keys and host details are never committed.)
2. Supply `vm/cloud-init.yaml` to your VM platform:
   - **KVM / libvirt (`virt-install`):**
     ```sh
     virt-install ... --cloud-init user-data=vm/cloud-init.yaml
     ```
   - **NoCloud seed ISO (`cloud-localds`, for QEMU / generic hypervisors):**
     ```sh
     cloud-localds seed.iso vm/cloud-init.yaml
     ```
   - **Proxmox VE:** upload to your snippets storage and attach via
     `qm set <vmid> --cicustom "user=local:snippets/cloud-init.yaml"`.
   - **Ubuntu Server ISO autoinstall:** embed the user/package/runcmd sections under
     `autoinstall.user-data:` in your autoinstall `user-data` file.
3. Once the VM boots, SSH in and run the Step 2 chezmoi one-liner (or uncomment the
   optional `runcmd` entry in `vm/cloud-init.yaml` to bootstrap unattended), then run
   the interactive secret-restore and service setup steps:
   ```sh
   sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin" init --apply l3rady
   bw login
   export BW_SESSION="$(bw unlock --raw)"
   gh auth login
   chezmoi apply
   t3 up --headless
   ```

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

Personal preferences and subagent roles for Claude Code, Codex and Antigravity are managed
from a single source of truth:

- `home/.chezmoitemplates/ai-instructions.md` — shared git, environment, and secret rules.
- `home/.chezmoitemplates/ai-delegation.md` — shared subagent delegation rules.
- `home/.chezmoidata/ai.yaml` — semantic model tiers (`fast`, `balanced`, `reasoning`) mapped
  per harness, role metadata, and pinned subagent skill packs (`agentSkills`).
- `home/.chezmoitemplates/agents/` — harness-agnostic role playbooks (`implementer`, `scoper`,
  `shipper`, `reviewer`, `wordpress-security-reviewer`).

chezmoi renders native instructions and native subagents to each tool's global location:

| Tool | Instructions | Native subagents |
|---|---|---|
| Claude Code | `~/.claude/CLAUDE.md` | `~/.claude/agents/*.md` (`haiku` / `sonnet` / `opus`) |
| Antigravity | `~/.gemini/config/AGENTS.md` | `~/.gemini/config/agents/*.md` (`flash` / `pro` / `inherit`) |
| Codex | `~/.codex/AGENTS.md` | `~/.codex/agents/*.toml` (`model_reasoning_effort`, `sandbox_mode`) |

Subagent-only skill packs (such as `wordpress-security`, pinned by commit + SHA-256) are
downloaded to `~/.local/share/agent-skills/` so all three harnesses' subagents can read them
without auto-loading them into any main session.

Edit the shared templates or `ai.yaml`, then `chezmoi apply`. These shared instructions are not
enforced by git hooks (Claude Code does enforce the 72-character commit header limit via its
`PreToolUse` hook below).

## Claude Code

Installed with npm (`@anthropic-ai/claude-code`, on mise's Node), so `claude update`
and auto-updates work. Only hand-written config
is tracked, so it follows me to every machine:

| Tracked | Why |
|---|---|
| `~/.claude/settings.json` (selected keys) | The keys in `home/.chezmoidata/claude.yaml`: model and effort, attribution (off), theme, notifications, Bash shell `env`, secret-file `permissions.deny` rules, and managed hooks. Other keys (such as `permissions.defaultMode`, unmanaged `env` keys, and plugin hooks) are left alone |
| `~/.claude/CLAUDE.md` | Shared instructions (`ai-instructions.md`) plus shared delegation rules (`ai-delegation.md`) |
| `~/.claude/agents/` | Native Claude Code subagent wrappers rendered from `home/.chezmoidata/ai.yaml` and `home/.chezmoitemplates/agents/` (after [this post](https://www.andreagrandi.it/posts/claude-code-subagents-to-save-usage/)) |
| `~/.claude/hooks/` | `check-commit-headers.sh` (`PreToolUse` Bash hook that blocks `git push` if a commit header exceeds 72 characters) |
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

## Memory limits

Three layers stop runaway tests or builds from thrashing swap and locking up
the host:

- **Docker container slice:** `home/run_onchange_after_30-configure-memory-limits.sh.tmpl`
  sets `"cgroup-parent": "docker-containers.slice"` in `/etc/docker/daemon.json`
  and writes `/etc/systemd/system/docker-containers.slice` (`MemoryHigh=70%`,
  `MemoryMax=75%`, `MemorySwapMax=0` from `home/.chezmoidata/system.yaml`). Even
  uncapped containers cannot exceed 75% of RAM or spill into swap.
- **`earlyoom`:** installed via `packages.yaml` and tuned in `/etc/default/earlyoom`
  (`-m 5,2 -s 100,100 -r 3600`) to `SIGTERM` at 5% available RAM and `SIGKILL`
  at 2% regardless of swap, while avoiding core shell/session/container daemons
  (processes *inside* containers have their own process names and are still
  killed normally).
- **`memcap`:** `~/.local/bin/memcap` wraps `systemd-run --user --scope` to cap
  an individual host command with zero swap, e.g. `memcap 8G pytest`.

### Windows `.wslconfig` (host side)

WSL's VM-wide memory and swap ceilings live on the Windows host in
`%USERPROFILE%\.wslconfig` (outside chezmoi's `~`). Recommended settings on a
64 GiB Windows machine:

```ini
[wsl2]
memory=32GB
swap=0

[experimental]
autoMemoryReclaim=gradual
```

- Lower `memory=` (e.g. `24GB`) if Windows host apps need more headroom.
- `swap=0` eliminates `swap.vhdx` disk thrashing; if legitimate builds ever hit
  spikes over the ceiling, a small `swap=2GB` paired with `earlyoom` (`-s 100,100`)
  gives a cushion without letting swap fill.
- `autoMemoryReclaim` controls how WSL returns unused Linux page cache to
  Windows when idle (`dropCache` is the default and flushes all at once;
  `gradual` reclaims slowly over time; `disabled` turns reclamation off).
- Run `wsl --shutdown` in PowerShell after editing `.wslconfig`.

## Layout

```
install.sh                  bootstrap from an existing clone (alternative to the one-liner)
vm/cloud-init.yaml.example  example cloud-init user-data for provisioning a fresh Ubuntu VM
.chezmoiroot                tells chezmoi the dotfiles live in home/
.githooks/pre-commit        gitleaks secret scan on staged commits
AGENTS.md, CLAUDE.md        repo-level instructions for AI coding agents
home/
  .chezmoi.toml.tmpl        first-run prompts (name, email), umask, WSL and VM detection
  .chezmoiignore            keeps caches, credentials and locked Bitwarden targets out of apply
  .chezmoiexternal.toml.tmpl  oh-my-zsh + plugins, pinned talosctl/amtool, shared agentSkills
  .chezmoidata/
    ai.yaml                 semantic model tiers, subagent roles and pinned agentSkills
    alertmanager.yaml       pinned amtool version + checksums
    claude.yaml             Claude Code settings and managed hooks
    codex.yaml              Codex CLI baseline shell policy settings
    packages.yaml           taps, brew, cask, mise (Node, Terraform), npm, apt, VM and Docker lists
    projects.yaml           repos to clone into ~/Projects
    secrets.yaml            Bitwarden SSH key item and secret env vars
    system.yaml             shell locale, earlyoom args, Docker slice limits and VM service settings
    talos.yaml              pinned talosctl version + checksums
    zsh.yaml                oh-my-zsh plugins
  .chezmoitemplates/
    agents/                 shared harness-agnostic subagent playbooks
    ai-delegation.md        shared subagent delegation rules
    ai-instructions.md      shared AI assistant preferences
    *-agent                 per-harness subagent wrappers (claude, antigravity, codex)
    bitwarden-*             exact-name Bitwarden helpers and vault-unlocked check
    signing-public-key      SSH signing key lookup (Bitwarden or ~/.ssh/id_ed25519.pub)
  run_onchange_before_10-install-packages.sh.tmpl  re-runs when package lists change
  run_onchange_after_20-install-node.sh.tmpl       Node LTS + Terraform via mise, global npm packages
  run_onchange_after_30-configure-memory-limits.sh.tmpl  earlyoom + Docker systemd slice
  run_onchange_after_35-configure-vm.sh.tmpl       VM guest services, fstrim.timer, user lingering, t3 service
  run_once_after_80-enable-git-hooks.sh.tmpl       turns on the gitleaks hook
  run_after_85-kube-config.sh                      creates ~/.kube/config if missing
  run_once_after_90-set-login-shell.sh             sets /usr/bin/zsh as login shell
  run_after_95-clone-projects.sh.tmpl              clones projects.yaml repos into ~/Projects
  dot_bashrc.tmpl           -> ~/.bashrc (minimal Bash, sources ~/.config/shell/env.sh)
  dot_zshrc.tmpl            -> ~/.zshrc
  dot_tmux.conf             -> ~/.tmux.conf
  dot_gitconfig.tmpl        -> ~/.gitconfig
  dot_default-npm-packages.tmpl  -> ~/.default-npm-packages (reinstalled by mise on Node upgrades)
  dot_cache/terraform/plugin-cache/  creates ~/.cache/terraform/plugin-cache
  dot_claude/
    CLAUDE.md.tmpl          -> ~/.claude/CLAUDE.md
    modify_settings.json.tmpl  merges .chezmoidata/claude.yaml into ~/.claude/settings.json
    agents/                 Claude Code native subagent wrappers
    hooks/                  Claude Code hooks (check-commit-headers.sh)
  dot_codex/
    AGENTS.md.tmpl          -> ~/.codex/AGENTS.md
    modify_config.toml.tmpl merges .chezmoidata/codex.yaml into ~/.codex/config.toml
    agents/                 Codex native TOML subagent wrappers
  dot_gemini/config/
    AGENTS.md.tmpl          -> ~/.gemini/config/AGENTS.md
    agents/                 Antigravity native subagent wrappers
  dot_config/
    git/allowed_signers.tmpl  -> ~/.config/git/allowed_signers
    mise/conf.d/settings.toml -> mise settings (reads .terraform-version)
    shell/env.sh.tmpl         -> ~/.config/shell/env.sh (shared POSIX, secret-free env)
    sops/private_age/         -> ~/.config/sops/age/keys.txt (from Bitwarden)
    starship.toml             -> ~/.config/starship.toml
    terraform/dot_terraformrc -> ~/.config/terraform/.terraformrc (TF_CLI_CONFIG_FILE;
                              providers cached in ~/.cache/terraform, no ~/.terraform.d)
    zsh/aliases/agents.zsh.tmpl -> ~/.config/zsh/aliases/agents.zsh (Bash harness wrappers)
    zsh/private_secrets.zsh.tmpl -> ~/.config/zsh/secrets.zsh (from Bitwarden)
  dot_local/bin/            -> ~/.local/bin/{memcap,pbcopy,pbpaste} (pbcopy/pbpaste WSL-only)
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

### AI agent secret isolation

Secrets exported into interactive Zsh (`~/.config/zsh/secrets.zsh`, `~/.zshrc.local`,
active `BW_SESSION`) are isolated from AI coding harnesses by three layers:

1. **Shell split + Zsh launcher scrubbing:** `~/.config/shell/env.sh` and `~/.bashrc`
   never source `~/.config/zsh/secrets.zsh` or `~/.zshrc.local`, and the Zsh wrappers in
   `home/dot_config/zsh/aliases/agents.zsh.tmpl` unset `BW_SESSION`, all `secretEnv`
   variables from `home/.chezmoidata/secrets.yaml`, and common cloud credential vars
   before launching `claude`, `codex`, `agy`, `t3`, or `herdr`. Pass a scoped token
   explicitly for one session with `AI_AGENT_ALLOW_ENV=GITHUB_PUBLIC_TOKEN claude`.
2. **Claude Code `permissions.deny`:** `home/.chezmoidata/claude.yaml` blocks `Read`
   access to `~/.config/zsh/secrets.zsh`, `~/.config/sops/age/keys.txt`,
   `~/.ssh/id_ed25519`, `~/.talos/config`, `~/.cloudflared/credentials.json`, and
   `.env` / `.env.*` (merged without touching `permissions.defaultMode` or user rules).
3. **Codex `[shell_environment_policy]`:** `home/.chezmoidata/codex.yaml` sets
   `allow_login_shell = false` and `exclude = ["BW_SESSION", "*_SECRET*", "*_TOKEN", "*_KEY"]`
   in `~/.codex/config.toml`.

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
