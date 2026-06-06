#!/usr/bin/env bash
# install.sh — wire BlackTerminal Security skills + agent into local AI editors.
#
# This repo is the single source of truth. Everything is symlinked back here,
# so `git pull` updates every editor at once — no copies, no drift.
#
# Usage:
#   ./install.sh              install into every detected editor
#   ./install.sh --dry-run    print actions without changing anything
#   ./install.sh --with-hooks also install the pre-commit scan hook in THIS repo
#   ./install.sh --uninstall  remove the symlinks this script created
#
# Idempotent. macOS bash 3.2-safe (no mapfile / associative arrays).

set -euo pipefail

# --- resolve repo root (dir containing this script) ---
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  case "$SOURCE" in /*) ;; *) SOURCE="$DIR/$SOURCE" ;; esac
done
REPO="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

DRY=0
UNINSTALL=0
WITH_HOOKS=0
for arg in "$@"; do
  case "$arg" in
    --dry-run)    DRY=1 ;;
    --uninstall)  UNINSTALL=1 ;;
    --with-hooks) WITH_HOOKS=1 ;;
    -h|--help)    grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

GREEN='\033[0;32m'; YEL='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
say()  { printf "${CYAN}%s${NC}\n" "$*"; }
ok()   { printf "  ${GREEN}link${NC} %s\n" "$*"; }
skip() { printf "  ${YEL}skip${NC} %s\n" "$*"; }

SKILLS="blackterminal-security security-audit"

# link <target> <linkpath> — idempotent symlink (replaces existing symlink)
link() {
  local target="$1" linkpath="$2"
  if [ "$UNINSTALL" -eq 1 ]; then
    if [ -L "$linkpath" ]; then
      [ "$DRY" -eq 1 ] && { echo "  rm   $linkpath"; return; }
      rm -f "$linkpath"; echo "  rm   $linkpath"
    fi
    return
  fi
  if [ -e "$linkpath" ] && [ ! -L "$linkpath" ]; then
    skip "$linkpath (real file/dir exists, not ours — leaving it)"
    return
  fi
  [ "$DRY" -eq 1 ] && { ok "$linkpath -> $target"; return; }
  mkdir -p "$(dirname "$linkpath")"
  ln -sfn "$target" "$linkpath"
  ok "$linkpath -> $target"
}

# --- Cursor (canonical), then Claude skills point at Cursor canonical ---
CURSOR_DIR="$HOME/.cursor/skills"
CLAUDE_SKILLS="$HOME/.claude/skills"
CLAUDE_AGENTS="$HOME/.claude/agents"
WINDSURF_DIR="$HOME/.codeium/windsurf/skills"
AGENTS_MIRROR="$HOME/.agents/skills"

say "BlackTerminal Security installer"
say "repo: $REPO"
[ "$DRY" -eq 1 ] && say "(dry-run — no changes)"
[ "$UNINSTALL" -eq 1 ] && say "(uninstall mode)"

cursor_present=0
[ -d "$HOME/.cursor" ] && cursor_present=1

for s in $SKILLS; do
  src="$REPO/skills/$s"
  if [ "$cursor_present" -eq 1 ]; then
    say "Cursor: $s"
    link "$src" "$CURSOR_DIR/$s"
    canonical="$CURSOR_DIR/$s"
  else
    canonical="$src"
  fi
  if [ -d "$HOME/.claude" ]; then
    say "Claude (skill): $s"
    link "$canonical" "$CLAUDE_SKILLS/$s"
  fi
  if [ -d "$HOME/.codeium/windsurf" ]; then
    say "Windsurf: $s"
    link "$src" "$WINDSURF_DIR/$s"
  fi
  if [ -d "$HOME/.agents" ]; then
    say "~/.agents mirror: $s"
    link "$src" "$AGENTS_MIRROR/$s"
  fi
done

# --- Claude agent ---
if [ -d "$HOME/.claude" ]; then
  say "Claude (agent): security-auditor"
  link "$REPO/agents/security-auditor.md" "$CLAUDE_AGENTS/security-auditor.md"
fi

# --- optional: pre-commit hook in this repo ---
if [ "$WITH_HOOKS" -eq 1 ] && [ "$UNINSTALL" -eq 0 ]; then
  say "pre-commit hook (this repo)"
  if [ -d "$REPO/.git" ]; then
    if [ "$DRY" -eq 1 ]; then
      ok ".git/hooks/pre-commit"
    else
      cp "$REPO/hooks/pre-commit" "$REPO/.git/hooks/pre-commit"
      chmod +x "$REPO/.git/hooks/pre-commit"
      ok ".git/hooks/pre-commit"
    fi
  else
    skip "not a git repo — run from a clone with .git/"
  fi
fi

say "done."
if [ "$UNINSTALL" -eq 0 ] && [ "$DRY" -eq 0 ]; then
  echo ""
  echo "Verify in Claude Code:  /security-audit <path>"
  echo "Fast scan:              ./scripts/scan.sh <path>"
fi
