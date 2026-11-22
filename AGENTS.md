# Instructions for AI coding agents

This is my personal dotfiles repo, managed with chezmoi. These rules override my global
instructions (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`) where they conflict.

## Git workflow

- **Ad-hoc work goes straight to `main`.** No branch, issue or pull request: commit on
  `main` and push it. Only one person works here, so a branch adds nothing.
- **Branch only when working on an existing GitHub issue.** Then follow the usual flow:
  `gh issue develop <n> --name <type>/<n>-<short-name>`, a PR with `Closes #<n>`, and
  a local fast-forward merge into `main`. Don't open an issue just to get a branch name.
- Everything else still applies: Conventional Commits (header 72 characters or fewer),
  signed commits, linear history, no AI attribution, no `--no-verify`.

## Repo notes

- `.chezmoiroot` is `home`, so only `home/` is applied to `~`. Files at the repo root,
  like this one, are never copied into the home directory.
- Package lists are in `home/.chezmoidata/packages.yaml`. Secrets come from Bitwarden
  through `home/.chezmoitemplates/bitwarden-*`; never commit or print their values.
- Check a template without touching `~`:
  `chezmoi execute-template --file <path>`, or `chezmoi cat <target>`.
  Ask before running `chezmoi apply` on the real home directory.
