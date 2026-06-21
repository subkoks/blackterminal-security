# blackterminal-security — project instructions

A skill + agent package that gives AI coding agents the instincts of a senior
application-security engineer: detection patterns, vulnerability taxonomies,
threat-modeling discipline, and a specialized auditor agent. Brand:
blackterminal. Author: Ingus Liepins (black.terminal), GitHub `subkoks`.

It ships as a Claude Code plugin and symlinks into Claude Code and Codex
(Cursor/Windsurf retired 2026-06-17) so one `git pull` updates them all. Coverage spans OWASP Top 10, OWASP API/LLM Top 10, and CWE Top 25 —
injection, broken access control, crypto failures, SSRF, path traversal,
insecure deserialization, hardcoded secrets, cloud/container/CI misconfig.

## Key files

| Path | Role |
|---|---|
| `.claude-plugin/plugin.json` | Plugin manifest — `skills`/`agents` paths must match directory names exactly |
| `skills/blackterminal-security/SKILL.md` | Core discipline; frontmatter description controls auto-activation |
| `skills/security-audit/SKILL.md` | On-demand audit command |
| `agents/security-auditor.md` | Read-only auditor subagent |
| `scripts/` | Install / update / healthcheck / branding-gate helpers |
| `install.sh` | Symlink install into supported editors |

## Rules for this project

- **SSH only.** Git remotes use `git@github.com:...`; never HTTPS.
- Feature branches only; `main` is protected. One logical change per commit.
- Keep the security auditor read-only by default — it proposes fixes, it does
  not silently rewrite security-sensitive code.

## Cloud sessions (Claude Code on the web)

This repo is cloud-ready. A `SessionStart` hook (`.claude/settings.json` ->
`scripts/cloud-setup.sh`) bootstraps dependencies automatically in Anthropic
cloud sessions (`claude --remote`, `claude.ai/code`). It is cloud-guarded
(`CLAUDE_CODE_REMOTE=true`) and a no-op in local sessions.
