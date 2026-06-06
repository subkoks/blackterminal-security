#!/usr/bin/env bash
# blackterminal-security/scripts/scan.sh
#
# Quick offline scan for the most common vulnerability patterns.
# Not a substitute for the full security-auditor subagent or proper SAST,
# but useful in CI / pre-commit hooks to catch low-hanging fruit fast.
#
# Usage:
#   ./scan.sh <file-or-directory>
#   ./scan.sh ./src
#
# Exit codes:
#   0 — clean
#   1 — findings detected
#   2 — usage error

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <file-or-directory>" >&2
  exit 2
fi

TARGET="$1"
if [ ! -e "$TARGET" ]; then
  echo "error: target does not exist: $TARGET" >&2
  exit 2
fi

CRITICAL=0
HIGH=0
MEDIUM=0

RED='\033[0;31m'
YEL='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

flag() {
  local sev="$1"; shift
  local msg="$*"
  case "$sev" in
    CRIT) printf "${RED}[CRIT]${NC} %s\n" "$msg"; CRITICAL=$((CRITICAL+1)) ;;
    HIGH) printf "${RED}[HIGH]${NC} %s\n" "$msg"; HIGH=$((HIGH+1)) ;;
    MED)  printf "${YEL}[MED]${NC}  %s\n" "$msg"; MEDIUM=$((MEDIUM+1)) ;;
    INFO) printf "${CYAN}[INFO]${NC} %s\n" "$msg" ;;
  esac
}

# File globs to scan (skip vendored / build / test by default)
FIND_EXPR=(
  "$TARGET"
  -type f
  -not -path '*/node_modules/*'
  -not -path '*/.git/*'
  -not -path '*/dist/*'
  -not -path '*/build/*'
  -not -path '*/.next/*'
  -not -path '*/__pycache__/*'
  -not -path '*/vendor/*'
  -not -path '*/.venv/*'
  -not -path '*/target/*'
  \(
    -name '*.js' -o -name '*.jsx' -o -name '*.ts' -o -name '*.tsx'
    -o -name '*.py' -o -name '*.go' -o -name '*.rs' -o -name '*.java'
    -o -name '*.rb' -o -name '*.php' -o -name '*.cs'
    -o -name '*.sql' -o -name '*.yaml' -o -name '*.yml' -o -name '*.json'
    -o -name '*.tf' -o -name '*.hcl' -o -name 'Dockerfile' -o -name 'Dockerfile.*'
    -o -name '*.sh'
  \)
)

if [ -f "$TARGET" ]; then
  FILES=("$TARGET")
else
  # Bash 3.2-compatible (macOS default) — avoid `mapfile`
  FILES=()
  while IFS= read -r _line; do
    FILES+=("$_line")
  done < <(find "${FIND_EXPR[@]}" 2>/dev/null)
fi

echo "BlackTerminal Security quick-scan"
echo "Target: $TARGET"
echo "Files:  ${#FILES[@]}"
echo "---"

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "No scannable files found (filtered by extension allowlist)."
  exit 0
fi

# ─── Hardcoded secrets ──────────────────────────────────────────────
SECRET_PATTERNS=(
  'AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|AWS access key'
  'ghp_[A-Za-z0-9]{36}|GitHub PAT'
  'gho_[A-Za-z0-9]{36}|GitHub OAuth'
  'github_pat_[A-Za-z0-9_]{82}|GitHub fine-grained PAT'
  'glpat-[A-Za-z0-9_-]{20}|GitLab PAT'
  'sk_live_[A-Za-z0-9]{24,}|Stripe live secret'
  'sk-ant-(api03|admin01)-[A-Za-z0-9_-]{80,}|Anthropic key'
  'sk-proj-[A-Za-z0-9_-]{40,}|OpenAI project key'
  'AIza[0-9A-Za-z_-]{35}|Google API key'
  'xox[baprs]-[0-9A-Za-z-]{10,}|Slack token'
  'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+|JWT'
  '-----BEGIN.*PRIVATE KEY|Private key block'
)

for f in "${FILES[@]}"; do
  for entry in "${SECRET_PATTERNS[@]}"; do
    pat="${entry%%|*}"
    name="${entry##*|}"
    if grep -nE "$pat" "$f" >/dev/null 2>&1; then
      line=$(grep -nE "$pat" "$f" | head -1 | cut -d: -f1)
      flag CRIT "$f:$line — hardcoded secret ($name)"
    fi
  done
done

# ─── Injection sinks ────────────────────────────────────────────────
for f in "${FILES[@]}"; do
  # SQL injection (template-string interpolation into query sinks)
  if grep -nE '\b(query|execute|raw|\$queryRawUnsafe|sql\.raw|sequelize\.literal)\s*\(\s*[`"'\''][^`"'\'']*\$\{' "$f" >/dev/null 2>&1; then
    line=$(grep -nE '\b(query|execute|raw|\$queryRawUnsafe|sql\.raw|sequelize\.literal)\s*\(\s*[`"'\''][^`"'\'']*\$\{' "$f" | head -1 | cut -d: -f1)
    flag HIGH "$f:$line — possible SQL injection (template literal in query sink)"
  fi

  # Command injection
  if grep -nE 'child_process\.(exec|execSync)\s*\(\s*[`"'\''][^`"'\'']*\$\{' "$f" >/dev/null 2>&1; then
    line=$(grep -nE 'child_process\.(exec|execSync)\s*\(\s*[`"'\''][^`"'\'']*\$\{' "$f" | head -1 | cut -d: -f1)
    flag HIGH "$f:$line — possible command injection (child_process.exec with template literal)"
  fi
  if grep -nE 'subprocess\.(run|call|Popen).*shell\s*=\s*True' "$f" >/dev/null 2>&1; then
    line=$(grep -nE 'subprocess\.(run|call|Popen).*shell\s*=\s*True' "$f" | head -1 | cut -d: -f1)
    flag HIGH "$f:$line — subprocess shell=True (possible command injection)"
  fi

  # Code execution sinks
  if grep -nE '\beval\s*\(|new\s+Function\s*\(' "$f" >/dev/null 2>&1; then
    line=$(grep -nE '\beval\s*\(|new\s+Function\s*\(' "$f" | head -1 | cut -d: -f1)
    flag MED "$f:$line — eval / new Function() — verify input source"
  fi
  if grep -nE '\b(pickle\.loads|yaml\.load[^_])' "$f" >/dev/null 2>&1; then
    line=$(grep -nE '\b(pickle\.loads|yaml\.load[^_])' "$f" | head -1 | cut -d: -f1)
    flag HIGH "$f:$line — unsafe deserialization (pickle.loads / yaml.load)"
  fi

  # XSS
  if grep -nE 'dangerouslySetInnerHTML|\bv-html\b|\{@html\b' "$f" >/dev/null 2>&1; then
    line=$(grep -nE 'dangerouslySetInnerHTML|\bv-html\b|\{@html\b' "$f" | head -1 | cut -d: -f1)
    flag MED "$f:$line — raw HTML render — verify content is sanitized"
  fi

  # Crypto smells
  if grep -nE "createHash\s*\(\s*['\"](md5|sha1)['\"]" "$f" >/dev/null 2>&1; then
    line=$(grep -nE "createHash\s*\(\s*['\"](md5|sha1)['\"]" "$f" | head -1 | cut -d: -f1)
    flag MED "$f:$line — weak hash (MD5/SHA1)"
  fi
  if grep -nE "Math\.random\b.*\b(token|secret|key|nonce|salt)" "$f" >/dev/null 2>&1; then
    line=$(grep -nE "Math\.random\b.*\b(token|secret|key|nonce|salt)" "$f" | head -1 | cut -d: -f1)
    flag HIGH "$f:$line — Math.random() used near security-sensitive identifier"
  fi
  if grep -nE "algorithm\s*:\s*['\"]none['\"]" "$f" >/dev/null 2>&1; then
    line=$(grep -nE "algorithm\s*:\s*['\"]none['\"]" "$f" | head -1 | cut -d: -f1)
    flag CRIT "$f:$line — JWT alg=none"
  fi
  if grep -nE "rejectUnauthorized\s*:\s*false" "$f" >/dev/null 2>&1; then
    line=$(grep -nE "rejectUnauthorized\s*:\s*false" "$f" | head -1 | cut -d: -f1)
    flag HIGH "$f:$line — TLS verification disabled (rejectUnauthorized: false)"
  fi
done

# ─── Infrastructure: cloud / k8s / Docker ──────────────────────────
for f in "${FILES[@]}"; do
  if grep -nE '0\.0\.0\.0/0' "$f" >/dev/null 2>&1; then
    line=$(grep -nE '0\.0\.0\.0/0' "$f" | head -1 | cut -d: -f1)
    flag MED "$f:$line — open ingress (0.0.0.0/0)"
  fi
  if grep -nE '"Action"\s*:\s*"\*"' "$f" >/dev/null 2>&1; then
    if grep -nE '"Resource"\s*:\s*"\*"' "$f" >/dev/null 2>&1; then
      flag HIGH "$f — IAM policy with Action:* and Resource:*"
    fi
  fi
  if grep -nE 'privileged\s*:\s*true' "$f" >/dev/null 2>&1; then
    line=$(grep -nE 'privileged\s*:\s*true' "$f" | head -1 | cut -d: -f1)
    flag HIGH "$f:$line — privileged container"
  fi
  if grep -nE 'runAsUser\s*:\s*0\b' "$f" >/dev/null 2>&1; then
    line=$(grep -nE 'runAsUser\s*:\s*0\b' "$f" | head -1 | cut -d: -f1)
    flag MED "$f:$line — container running as UID 0"
  fi
  if grep -nE 'hostNetwork\s*:\s*true|hostPID\s*:\s*true|hostIPC\s*:\s*true' "$f" >/dev/null 2>&1; then
    line=$(grep -nE 'hostNetwork\s*:\s*true|hostPID\s*:\s*true|hostIPC\s*:\s*true' "$f" | head -1 | cut -d: -f1)
    flag HIGH "$f:$line — host namespace mount"
  fi
  if grep -nE '/var/run/docker\.sock' "$f" >/dev/null 2>&1; then
    line=$(grep -nE '/var/run/docker\.sock' "$f" | head -1 | cut -d: -f1)
    flag CRIT "$f:$line — Docker socket mounted (container escape vector)"
  fi

  # Dockerfile smells
  case "$f" in
    *Dockerfile*|Dockerfile)
      if grep -nE '^USER\s+root\s*$' "$f" >/dev/null 2>&1; then
        line=$(grep -nE '^USER\s+root\s*$' "$f" | head -1 | cut -d: -f1)
        flag MED "$f:$line — USER root in Dockerfile"
      fi
      if grep -nE '^FROM\s+\S+:latest' "$f" >/dev/null 2>&1; then
        line=$(grep -nE '^FROM\s+\S+:latest' "$f" | head -1 | cut -d: -f1)
        flag MED "$f:$line — FROM with :latest (non-deterministic)"
      fi
      if grep -nE 'curl\s+[^|]+\|\s*(sudo\s+)?(bash|sh)' "$f" >/dev/null 2>&1; then
        line=$(grep -nE 'curl\s+[^|]+\|\s*(sudo\s+)?(bash|sh)' "$f" | head -1 | cut -d: -f1)
        flag HIGH "$f:$line — curl|sh remote-code execution"
      fi
      ;;
  esac
done

# ─── CI/CD red flags ────────────────────────────────────────────────
for f in "${FILES[@]}"; do
  case "$f" in
    *.github/workflows/*|*.yml|*.yaml)
      if grep -nE '^on:\s*pull_request_target' "$f" >/dev/null 2>&1; then
        line=$(grep -nE '^on:\s*pull_request_target' "$f" | head -1 | cut -d: -f1)
        flag HIGH "$f:$line — pull_request_target trigger (verify no untrusted code execution)"
      fi
      if grep -nE 'permissions:\s*write-all' "$f" >/dev/null 2>&1; then
        line=$(grep -nE 'permissions:\s*write-all' "$f" | head -1 | cut -d: -f1)
        flag MED "$f:$line — permissions: write-all"
      fi
      if grep -nE '\$\{\{\s*github\.event\.(pull_request\.(title|body|head_ref)|comment\.body|issue\.(title|body))' "$f" >/dev/null 2>&1; then
        line=$(grep -nE '\$\{\{\s*github\.event\.(pull_request\.(title|body|head_ref)|comment\.body|issue\.(title|body))' "$f" | head -1 | cut -d: -f1)
        flag HIGH "$f:$line — untrusted GitHub event field used in workflow (script injection)"
      fi
      ;;
  esac
done

echo "---"
TOTAL=$((CRITICAL + HIGH + MEDIUM))
printf "Findings: ${RED}%d critical${NC}, ${RED}%d high${NC}, ${YEL}%d medium${NC}\n" \
  "$CRITICAL" "$HIGH" "$MEDIUM"

if [ $TOTAL -eq 0 ]; then
  echo "No findings."
  exit 0
else
  echo ""
  echo "Run /security-audit for a deeper review with severity calibration,"
  echo "exploit scenarios, and patched code. For a full SAST pass, run:"
  echo "  semgrep --config p/owasp-top-ten --config p/secrets ."
  echo "  trivy fs ."
  echo "  gitleaks detect --source . --redact"
  exit 1
fi
