# Contributing to BlackTerminal Security

Thanks for helping ship more secure code. The vulnerability landscape evolves continuously — new CVE classes, new framework footguns, new supply-chain attacks. PRs that add detection patterns, fresh case studies, and per-stack rules are especially welcome.

## What we want

### High-value contributions
- **New vulnerability patterns** — vulnerable + fixed code pair, CWE/OWASP mapping, real-world citation (CVE / writeup / CVSS)
- **Fresh case studies** — recent production exploits with vendor, date, vector, remediation, code-level lesson
- **Per-language / per-framework additions** — Rails, Django, Flask, FastAPI, Phoenix, ASP.NET, etc.
- **Per-cloud / per-tool additions** — Cloudflare Workers, Deno Deploy, Modal, Fly.io, Vercel-specific
- **Refusal / fix templates** — clearer wording, more useful patches
- **Compatibility verifications** — does this skill load correctly in `<your agent>`?

### Lower-priority
- Stylistic edits without new content
- Reformatting that doesn't improve clarity
- Adding emojis (we don't use them by default)

## What we don't accept

- Speculative patterns without evidence ("this might be exploitable")
- Proprietary techniques copied from closed-source guides
- Unverified CVE claims (always link the CVE / advisory)
- Vendor marketing copy disguised as recommendations
- Patterns that produce high false-positive rates without context filtering

## How to add a vulnerability pattern

Edit the right reference file:
- `language-patterns.md` for backend language-specific
- `frontend-patterns.md` for browser / framework
- `infrastructure-patterns.md` for cloud / containers / CI
- `secrets-patterns.md` for secret regex
- `vulnerability-taxonomies.md` for new entries in canonical lists

For each pattern, include:

1. **Class** — vulnerability category (Injection, AuthN, etc.)
2. **CWE** — canonical CWE ID
3. **Vulnerable code** — minimal, language-tagged
4. **Fixed code** — concrete fix, language-tagged
5. **Detection regex** (where useful) — grep-friendly
6. **CVE reference** — link to NVD / advisory
7. **Common variants / bypasses** — when applicable

## How to add a case study

Edit `case-studies.md`. Use the existing entry shape:

- Title (vendor + name + CVE if any)
- Disclosed date + class
- Vector — what the attacker did
- Payload pattern (verbatim where possible)
- Data at risk
- Fix
- Lesson for an agent
- URL

## Testing your contribution

1. **Self-audit.** Run the `security-auditor` agent against your patch and any fixture code you added. Patterns should be detectable and the audit shouldn't trip on the documentation itself.
2. **Load the skill** in Claude Code (or your agent of choice) and verify it activates appropriately.
3. **Try the audit slash command** on a known-vulnerable sample to confirm your new pattern catches it.
4. **False-positive check.** Run the pattern against a popular OSS codebase and see if it produces noise. Tune accordingly.

## Style

- Direct prose. No marketing hype.
- Code in code blocks, language-tagged.
- Quote real CVE / writeup URLs.
- Concrete fixes, not "validate input".
- No emojis unless explicitly required.
- ASCII characters where possible (we recommend Gitleaks scanning the repo itself).

## License

By contributing, you agree your work is licensed under MIT (see [LICENSE](LICENSE)).

## Questions / Disclosures

- Discord: [blackterminal.ai/discord](https://www.blackterminal.ai/discord)
- General PRs and issues: GitHub
- Security disclosure (active vulnerability you'd rather not publish before a fix lands): security@blackterminal.ai
