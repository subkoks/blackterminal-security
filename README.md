<p align="center">
  <strong>BlackTerminal Security</strong>
</p>

<h3 align="center">Find vulnerabilities. Ship secure.</h3>

<p align="center">
  A skill + agent package that gives AI coding agents the instincts of a senior
  application security engineer.<br/>
  Stop shipping classic vulnerabilities — start shipping production-secure code.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License" /></a>
  <img src="https://img.shields.io/badge/format-SKILL.md-black" alt="SKILL.md format" />
  <img src="https://img.shields.io/badge/editors-Claude%20%7C%20Cursor%20%7C%20Windsurf%20%7C%20Codex-black" alt="Editors" />
</p>

---

## Why this exists

AI coding agents write functional code, but they keep shipping the same classic vulnerabilities — SQL injection, XSS, IDOR, hardcoded secrets, missing auth on Server Actions, public S3 buckets, `pull_request_target` with checkout-of-fork-code. The bugs that have headlined CVEs for fifteen years.

**BlackTerminal Security fixes this.** It's a set of detection patterns, vulnerability taxonomies, threat-modeling discipline, and a specialized auditor agent that teach your AI teammates to **think like a senior security engineer** — find the trust boundary, match input to sink, check auth on every state-changing path, treat every secret as already leaked, fail closed.

### The bugs it catches

- **Injection** — SQLi, NoSQLi, command, code, template, XSS, LDAP, XPath
- **Broken Access Control** — IDOR, BOLA, BOPLA, missing auth, mass assignment, Server Action authz gaps, `x-middleware-subrequest` bypass class
- **Cryptographic Failures** — MD5/SHA1, `Math.random()` for tokens, ECB mode, hardcoded keys, JWT `alg: none`, HS256/RS256 confusion, `===` for HMAC compare
- **SSRF** — including private-IP / cloud-metadata / `file://` / TOCTOU
- **Path Traversal** — `path.join` without prefix-check, `send_file` with raw input
- **Insecure Deserialization** — `pickle.loads`, `yaml.load`, `ObjectInputStream`, `vm2`
- **Hardcoded Secrets** — AWS, GitHub, Stripe, OpenAI, Anthropic, Slack, JWTs, private keys (25+ patterns)
- **Cloud Misconfig** — public S3, IAM `*:*`, `0.0.0.0/0:22`, IMDSv1, missing encryption
- **Container / k8s** — `privileged: true`, `runAsUser: 0`, `hostNetwork`, `/var/run/docker.sock` mount, `image:latest`
- **CI/CD** — `pull_request_target` + checkout-fork-code, mutable Action tags (CVE-2025-30066 class), shell-injection via PR title
- **Auth flaws** — JWT in localStorage, no MFA, missing rate limit on login, predictable reset tokens
- **Open Redirect** — `//evil.com` bypass class
- **Markdown exfil** — image URLs constructed from secrets (EchoLeak class)
- **LLM-specific** — output-to-eval, excessive agency, secrets in system prompt

---

## What's inside

| Component | Type | What it does |
|-----------|------|-------------|
| **`blackterminal-security`** | Skill | Core security discipline — auto-loaded when your agent reads, writes, or reviews code. Five Disciplines, threat-model checklist, detection cheat-sheet. |
| **`security-audit`** | Skill | Slash-command audit. Scans a file/dir/PR/repo for vulnerabilities, returns severity-ranked report with CWE/OWASP mapping. |
| **`security-auditor`** | Agent | Read-only senior security engineer subagent. Cannot write, edit, or delete. Walks every file with the OWASP Top 10 + CWE Top 25 + threat model. |
| **`scan.sh`** | Script | Fast offline regex scan for pre-commit / CI. macOS bash 3.2-safe. |

### Reference documentation

The skill ships with eight deep reference docs (~50 pages of practitioner-grade content):

- **vulnerability-taxonomies.md** — OWASP Top 10 (2021), API Top 10 (2023), Mobile Top 10 (2024), LLM Top 10 (2025), CWE Top 25 (2024), CISA KEV recurring classes, DBIR top vectors
- **language-patterns.md** — JS/TS, Python, Go, Rust, Java/Spring, Ruby/Rails, PHP — vulnerable + fixed code pairs, per-ORM SQLi reference
- **frontend-patterns.md** — React, Next.js (Server Actions, middleware, hydration), Vue, Svelte, browser specifics
- **infrastructure-patterns.md** — AWS, GCP, Azure, Docker, Kubernetes, Terraform, GitHub Actions, GitLab CI
- **secrets-patterns.md** — regex catalog for 25+ secret types
- **case-studies.md** — Log4Shell, Spring4Shell, MOVEit, XZ backdoor, Polyfill.io, Snowflake, Ivanti, regreSSHion, Next.js CVE-2025-29927, tj-actions supply chain, recent agent CVEs
- **tooling.md** — Semgrep, CodeQL, Snyk, Trivy, Gitleaks, OSV, govulncheck, Brakeman, Checkov, kube-bench, MobSF
- **threat-modeling.md** — the full 10-question discipline

---

## Install

This repo is the single source of truth. `install.sh` symlinks the skills and agent
into every supported editor, so a `git pull` here updates them everywhere — no copies, no drift.

```bash
git clone https://github.com/subkoks/blackterminal-security.git
cd blackterminal-security
./install.sh              # detect installed editors, symlink skills + agent
./install.sh --dry-run    # preview actions
./install.sh --with-hooks # also install the pre-commit scan hook in this repo
./install.sh --uninstall  # remove all symlinks
```

What it wires up (only for editors present on the machine):

| Target | Path |
|--------|------|
| Cursor (canonical) | `~/.cursor/skills/blackterminal-security`, `~/.cursor/skills/security-audit` |
| Claude Code (skills) | `~/.claude/skills/*` → Cursor canonical |
| Claude Code (agent) | `~/.claude/agents/security-auditor.md` |
| Windsurf | `~/.codeium/windsurf/skills/*` |
| `~/.agents` mirror | `~/.agents/skills/*` |

Codex / Copilot consume `SKILL.md` directly — point their instruction file at this repo.

### Manual / project-level

```bash
mkdir -p .claude/skills .claude/agents
cp -r skills/blackterminal-security .claude/skills/
cp -r skills/security-audit .claude/skills/
cp agents/security-auditor.md .claude/agents/
```

---

## How it works

### The Five Disciplines

Once installed, the `blackterminal-security` skill activates whenever your agent reads, writes, or reviews code. Your agent now thinks like a senior:

1. **Find the trust boundaries** — every place untrusted data crosses into trusted code.
2. **Match input to sink** — every `(source, sink)` pair is a potential vulnerability.
3. **Auth on every state-changing path** — authentication + authorization (ownership, not just role) + input validation.
4. **Secrets are already leaked** — assume rotation as default, plan for it.
5. **Fail closed, log loudly, blast-radius small** — default deny, sanitized errors, audit logs, network/IAM segmentation.

### The 10-Question Threat Model

Before declaring code "secure":

1. Trust boundaries — where does data cross?
2. AuthN/AuthZ — server-side, ownership-checked?
3. Input validation — schema at the boundary?
4. Output encoding — correct context?
5. Secrets — safe storage + rotation?
6. Failure mode — fail closed?
7. Blast radius — what falls if owned?
8. Supply chain — pinned + audited?
9. Logging — security events captured? PII redacted?
10. Replay protection — idempotency, nonces, CSRF, rate limits?

If any answer is "I don't know" — the code is **not** cleared.

### Audit mode

```
> /security-audit src/api/users.ts

> /security-audit https://github.com/owner/repo/pull/123

> /security-audit ./terraform/

> /security-audit "all server actions in this app"
```

The `security-auditor` agent walks the target, applies all 20 audit categories, and produces a severity-ranked report with:
- **File:line** — exact location
- **Class** — vulnerability category
- **CWE / OWASP** — canonical IDs
- **Code** — verbatim vulnerable snippet
- **Exploit scenario** — concrete, not generic
- **Fix** — patched code
- **References** — links to CWE, OWASP, BlackTerminal Security references

### Fast offline scan

```bash
./scripts/scan.sh ./src        # exit 0 clean, 1 findings, 2 usage
```

Use it as a pre-commit gate (`./install.sh --with-hooks`) or in CI — see `.github/workflows/security-scan.yml`.

---

## When to use it

Install this if your agent:

- Writes any production code
- Reviews PRs or diffs
- Generates infrastructure-as-code (Terraform, Kubernetes, Dockerfiles)
- Edits CI/CD configurations (GitHub Actions, GitLab CI)
- Refactors authentication / authorization / payments code
- Handles user input on any code path
- Writes Server Actions, RPC handlers, API endpoints
- Touches anything with `eval`, `exec`, `query`, `fetch`, `redirect`, file paths, or secrets

If your agent only writes pure functions and unit tests, you may not need this. **Everyone else does.**

---

## Project layout

```
blackterminal-security/
├── .claude-plugin/
│   └── plugin.json
├── .github/
│   └── workflows/
│       └── security-scan.yml
├── skills/
│   ├── blackterminal-security/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── vulnerability-taxonomies.md
│   │       ├── language-patterns.md
│   │       ├── frontend-patterns.md
│   │       ├── infrastructure-patterns.md
│   │       ├── secrets-patterns.md
│   │       ├── case-studies.md
│   │       ├── tooling.md
│   │       └── threat-modeling.md
│   └── security-audit/
│       └── SKILL.md
├── agents/
│   └── security-auditor.md
├── hooks/
│   └── pre-commit
├── scripts/
│   └── scan.sh
└── install.sh
```

---

## Compatibility

Uses the standard **SKILL.md / agent** package format supported by 30+ AI coding tools.

| Tool | Skills | Subagent | Notes |
|------|--------|----------|-------|
| Claude Code | ✅ | ✅ | Full skill + agent support |
| Cursor | ✅ | — | `~/.cursor/skills/` |
| Windsurf | ✅ | — | `~/.codeium/windsurf/skills/` |
| OpenAI Codex | ✅ | — | Skill format |
| Gemini CLI | ✅ | — | Skill format |
| Cline / Roo Code | ✅ | — | Skill format |
| GitHub Copilot | ✅ | — | Via `.github/copilot-instructions.md` reference |
| Continue.dev | ✅ | — | Skill format |
| Goose | ✅ | — | Skill format |

---

## What it is not

- **Not a SAST tool.** It's a *thinking* skill. Pair it with Semgrep / CodeQL / Snyk / Trivy — the skill knows how to invoke them and synthesize output.
- **Not a guarantee.** Security is layered. This skill makes your agent better; it doesn't make your code invulnerable.
- **Not a replacement for human review** on high-stakes flows (payments, auth, crypto, IAM).
- **Not a runtime defense.** It catches issues at code-time. WAFs, sandboxes, and observability live elsewhere.

It is one layer in your stack. Layer it with: SAST in CI, dependency scanning, secret scanning, container scanning, IaC scanning, DAST, runtime observability, and human security review for high-stakes changes.

---

## Authoritative references

This skill synthesizes guidance from:

- [OWASP Top 10 (2021)](https://owasp.org/Top10/)
- [OWASP API Security Top 10 (2023)](https://owasp.org/API-Security/editions/2023/en/0x11-t10/)
- [OWASP Mobile Top 10 (2024)](https://owasp.org/www-project-mobile-top-10/)
- [OWASP LLM Top 10 (2025)](https://genai.owasp.org/llm-top-10/)
- [CWE Top 25 (2024)](https://cwe.mitre.org/top25/archive/2024/2024_cwe_top25.html)
- [CISA Known Exploited Vulnerabilities](https://www.cisa.gov/known-exploited-vulnerabilities-catalog)
- [Verizon DBIR](https://www.verizon.com/business/resources/reports/dbir/)
- [NIST NVD](https://nvd.nist.gov/)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)
- [NSA/CISA Kubernetes Hardening Guide v1.2](https://media.defense.gov/2022/Aug/29/2003066362/-1/-1/0/CTR_KUBERNETES_HARDENING_GUIDANCE_1.2_20220829.PDF)
- [GitHub Actions Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/)

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). When adding a new pattern: include a real-world citation (CVE, writeup, or CVSS score). When adding a new case study: name the vendor, date, vector, and remediation.

---

## License

MIT. See [LICENSE](LICENSE).

---

*BlackTerminal Security. Find vulnerabilities. Ship secure.*
