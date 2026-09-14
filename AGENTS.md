# AGENTS.md

Repo-specific instructions for Codex CLI and other agents working in this repository.

## Scope

- This repo ships security skills, an auditor agent, and install/update scripts.
- Read `README.md` and `CLAUDE.md` before editing.
- Keep changes small and security-focused. Prefer updating the canonical skill/agent source over generated outputs.

## Operating rules

- Feature branches only; one logical change per commit.
- Keep both security-auditor definitions read-only by default: the Codex-native
  `.codex/agents/security-auditor.toml` and the compatible Markdown agent.
- Preserve the SSH-only remote policy documented in `CLAUDE.md`.
- Use repo-local `.codex/config.toml` for Codex workspace defaults.

## Codex CLI notes

- Codex CLI should treat this file as the repo guidance source.
- If a change affects generated skill or agent artifacts, update the canonical source under `skills/`, `agents/`, or `.codex/agents/`, not a downstream mirror.
