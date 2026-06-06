# Changelog

All notable changes to BlackTerminal Security.

## [1.1.0] — 2026-06-06

### Added
- `install.sh` — idempotent, symlink-based installer that wires the skills + agent
  into every detected editor (Cursor, Claude Code, Windsurf, `~/.agents` mirror)
  from a single source of truth. Supports `--dry-run`, `--uninstall`, `--with-hooks`.
- `hooks/pre-commit` — staged-file security gate using `scripts/scan.sh`.
- `.github/workflows/security-scan.yml` — hardened CI (least-privilege `permissions`,
  no `pull_request_target`, action pinned to commit SHA) running the offline scan.
- `.editorconfig` — consistent formatting across editors.

### Changed
- Rebranded the package as **BlackTerminal Security** (`blackterminal-security`),
  tuned for a personal multi-editor AI coding setup.
- README install flow rewritten around the symlink installer.

## [1.0.0] — 2026-04-30

### Initial release

- `blackterminal-security` skill — core security-engineer discipline auto-loaded for any agent reading, writing, or reviewing code
- `security-audit` skill — slash-command audit for files / directories / PR diffs / repos
- `security-auditor` agent — read-only senior security engineer subagent
- Reference docs (8):
  - Vulnerability taxonomies (OWASP Top 10, API Top 10, Mobile Top 10, LLM Top 10, CWE Top 25, CISA KEV, DBIR)
  - Language patterns (JS/TS, Python, Go, Rust, Java/Spring, Ruby/Rails, PHP)
  - Frontend patterns (React, Next.js, Vue, Svelte, browser specifics)
  - Infrastructure patterns (AWS, GCP, Azure, Docker, Kubernetes, Terraform, GitHub Actions, GitLab)
  - Secrets patterns (25+ regex catalog: AWS, GitHub, Stripe, OpenAI, Anthropic, Slack, Google, JWT, private keys)
  - Case studies (Log4Shell, Spring4Shell, MOVEit, XZ backdoor, Polyfill.io, Snowflake, Ivanti, regreSSHion, Next.js CVEs, tj-actions, MCP CVEs)
  - Tooling (Semgrep, CodeQL, Snyk, Trivy, Gitleaks, OSV, govulncheck, Brakeman, Checkov, kube-bench, MobSF)
  - Threat modeling (10-question discipline)
- `scripts/scan.sh` — bash quick-scan for CI / pre-commit
- Plugin manifest (`.claude-plugin/plugin.json`)
- MIT license

### Synthesizes

- OWASP Top 10 (2021)
- OWASP API Security Top 10 (2023)
- OWASP Mobile Top 10 (2024)
- OWASP LLM Top 10 (2025)
- CWE Top 25 (2024)
- CISA Known Exploited Vulnerabilities catalog
- Verizon DBIR (2024–2025)
- NIST NVD CWE distributions
- CIS Benchmarks (AWS, GCP, Azure, Kubernetes, Docker)
- NSA/CISA Kubernetes Hardening Guide v1.2
- GitHub Actions Security Hardening guide
- OWASP Cheat Sheet Series

### Vulnerability classes covered

Injection (SQL/NoSQL/command/code/template/LDAP/XPath), XSS (stored/reflected/DOM-based), CSRF, SSRF, IDOR/BOLA/BOPLA, mass assignment, prototype pollution, ReDoS, deserialization, path traversal, open redirect, weak crypto, hardcoded secrets, JWT misuse, missing auth, race conditions, supply chain, container/k8s privilege escalation, cloud misconfiguration, CI/CD injection, mobile-specific issues, LLM-specific issues.
