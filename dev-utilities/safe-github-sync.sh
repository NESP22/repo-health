#!/usr/bin/env bash
# Safe GitHub sync — macOS. Night-safe: fetch + classify by default.
# Mutations opt-in only: --ff (fast-forward clean, strictly-behind, non-protected
# repos) and --push (push clean, strictly-ahead, non-protected repos).
#
# Usage:
#   bash safe-github-sync.sh            # audit only
#   bash safe-github-sync.sh --ff       # fast-forward safe repos
#   bash safe-github-sync.sh --push     # push safe repos
set -u
export GIT_TERMINAL_PROMPT=0

FF=0; PUSH=0
for a in "$@"; do
  case "$a" in
    --ff) FF=1 ;;
    --push) PUSH=1 ;;
    *) echo "unknown flag: $a" >&2; exit 2 ;;
  esac
done

PROTECTED="team-hub-app nesp_email_reply_assistant nesp-crm shiftframe-hockey ShiftFrame"

# Canonical clone roots on the Mac.
ROOTS=("$HOME/Projects")
# ShiftFrame (if cloned elsewhere) — adjust to the Mac's actual path.
for extra in "$HOME/ShiftFrameMacDev" "$HOME/Projects/shiftframe-hockey"; do
  [ -d "$extra" ] && ROOTS+=("$extra")
done

declare -a repos=()
for r in "${ROOTS[@]}"; do
  [ -d "$r" ] || continue
  for d in "$r"/*/; do
    [ -d "$d/.git" ] && repos+=("${d%/}")
  done
done

for d in "${repos[@]}"; do
  name=$(basename "$d")
  branch=$(git -C "$d" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '(detached)')
  remote=$(git -C "$d" remote get-url origin 2>/dev/null || echo '')
  [ -z "$remote" ] && { printf '%-28s NO-REMOTE\n' "$name"; continue; }

  git -C "$d" fetch origin --no-tags >/dev/null 2>&1 || { printf '%-28s ERROR fetch failed\n' "$name"; continue; }

  up=$(git -C "$d" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
  [ -z "$up" ] && { printf '%-28s %-26s NO-UPSTREAM\n' "$name" "$branch"; continue; }

  ahead=$(git -C "$d" rev-list --left-only --count "HEAD...$up" 2>/dev/null || echo 0)
  behind=$(git -C "$d" rev-list --right-only --count "HEAD...$up" 2>/dev/null || echo 0)
  dirty=$(git -C "$d" status --porcelain 2>/dev/null | grep -vc '^??' || true)
  prot=0; for p in $PROTECTED; do [ "$name" = "$p" ] && prot=1; done

  class='CURRENT'
  if [ "$dirty" -gt 0 ]; then class='LOCAL CHANGES'
  elif [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then class='DIVERGED'
  elif [ "$ahead" -gt 0 ]; then class='PUSH NEEDED'
  elif [ "$behind" -gt 0 ]; then class='PULL SAFE'
  fi

  tag=''; [ "$prot" = 1 ] && tag=' [PROTECTED]'
  printf '%-28s %-26s %-13s ahead=%-3s behind=%-3s dirty=%-3s%s\n' "$name" "$branch" "$class" "$ahead" "$behind" "$dirty" "$tag"

  [ "$prot" = 1 ] && continue
  if [ "$FF" = 1 ] && [ "$class" = 'PULL SAFE' ]; then
    git -C "$d" pull --ff-only >/dev/null 2>&1 && echo "    -> fast-forwarded" || echo "    -> ff-only skipped/failed"
  fi
  if [ "$PUSH" = 1 ] && [ "$class" = 'PUSH NEEDED' ]; then
    git -C "$d" push origin "$branch" >/dev/null 2>&1 && echo "    -> pushed $branch" || echo "    -> push failed"
  fi
done
