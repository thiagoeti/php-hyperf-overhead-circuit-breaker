#!/bin/sh

# git.sh — Git Workflow
# Usage: ./git.sh [beta|main|full] [<message>]

DIR="$(cd "$(dirname "$0")" && pwd)"
# Lowercase the mode so 'Beta', 'MAIN', etc. are accepted.
MODE="$(printf '%s' "${1:-beta}" | tr '[:upper:]' '[:lower:]')"
MSG="${2:-"chore: update $(date '+%Y-%m-%d %H:%M')"}"

if [ "$MODE" = "full" ]; then
  BRANCH="beta"
else
  BRANCH="$MODE"
fi

die() {
  echo ""
  echo "❌ $*" >&2
  echo ""
  exit 1
}

# True if the working tree has any change, tracked or untracked.
is_dirty() {
  ! git diff --quiet \
    || ! git diff --cached --quiet \
    || [ -n "$(git ls-files --others --exclude-standard)" ]
}

# Stash the working tree if dirty. Sets DIRTY=true/false.
stash_if_dirty() {
  DIRTY=false
  if is_dirty; then
    DIRTY=true
    echo ""
    echo "📦 Changes in '$(git branch --show-current)' — stashing..."
    git stash push -u -m "git.sh: $1" || die "🚫 Failed to stash changes."
  fi
}

# Restore the stash. On conflict, keep it and stop — never drop the user's work.
restore_stash() {
  [ "$DIRTY" = true ] || return 0
  echo ""
  echo "♻️ Restoring changes..."
  if git stash pop; then
    echo "✅ Changes restored."
    return 0
  fi
  echo "" >&2
  echo "⚠️ Conflict while restoring your changes." >&2
  echo "" >&2
  echo "   Your stash was PRESERVED — nothing is lost." >&2
  echo "" >&2
  echo "   To recover:" >&2
  echo "     • resolve the conflict markers above" >&2
  echo "     • git stash drop   # after resolving" >&2
  echo "     • git stash list   # to inspect it" >&2
  die "🚫 Stopped to let you resolve the stash conflict manually."
}

echo ""
echo "════════════════════════════════"
echo ""
echo "▶️ git.sh — starting"
echo ""
echo "📁 Repo: $DIR"
echo "🌿 Mode: $MODE"
echo "💬 Message: $MSG"
echo ""

# --- Validate mode ---

if [ "$MODE" != "full" ] && [ "$MODE" != "beta" ] && [ "$MODE" != "main" ]; then
  die "🚫 Invalid mode: '$MODE'. Use 'beta | main | full'."
fi

# --- Validations ---

cd "$DIR" || die "🚫 Cannot enter $DIR"
git rev-parse --git-dir >/dev/null 2>&1 || die "🚫 Not a git repository"

# Use resolved git paths so the checks also hold inside worktrees.
if [ -d "$(git rev-parse --git-path rebase-merge)" ] \
  || [ -d "$(git rev-parse --git-path rebase-apply)" ]; then
  die "🚫 Rebase in progress. Run 'git rebase --abort' or 'git rebase --continue' first."
fi
if [ -f "$(git rev-parse --git-path MERGE_HEAD)" ]; then
  die "🚫 Merge in progress. Run 'git merge --abort' or resolve conflicts first."
fi
if [ -f "$(git rev-parse --git-path CHERRY_PICK_HEAD)" ]; then
  die "🚫 Cherry-pick in progress. Run 'git cherry-pick --abort' or finish it first."
fi

CURRENT=$(git branch --show-current)
if [ -z "$CURRENT" ]; then
  die "🚫 Detached HEAD state. Run 'git checkout beta' or 'git checkout main' first."
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  die "🚫 No 'origin' remote configured. Add one with 'git remote add origin <url>'."
fi

if [ -z "$(git config user.name)" ] || [ -z "$(git config user.email)" ]; then
  die "🚫 Git identity not set. Run 'git config user.name' and 'git config user.email'."
fi

# --- Full: merge every remote branch into beta ---

if [ "$MODE" = "full" ]; then
  echo ""
  echo "🔁 Full mode — syncing all branches"

  # Protect uncommitted work before touching branches, then carry it to beta.
  stash_if_dirty "full: carry changes onto beta"

  git fetch --prune >/dev/null 2>&1 || {
    echo ""
    echo "⚠️ Could not fetch from remote — working with local state."
  }
  if git checkout beta >/dev/null 2>&1; then
    :
  elif git checkout -b beta --track origin/beta >/dev/null 2>&1; then
    :
  elif git checkout -b beta >/dev/null 2>&1; then
    echo ""
    echo "⚠️ 'beta' did not exist locally or on origin — created it from '$CURRENT'."
  else
    # Never leave the user's work stranded in the stash.
    [ "$DIRTY" = true ] && git stash pop >/dev/null 2>&1
    die "🚫 Cannot switch to beta"
  fi

  # Commit the carried work now, so the loop's checkouts find a clean tree.
  restore_stash
  if is_dirty; then
    echo ""
    echo "💾 Committing carried changes onto beta: $MSG"
    git add -A
    git commit -m "$MSG" || die "🚫 Commit on beta failed"
  fi

  # for-each-ref yields clean names (no 'sed | tr' mangling); '--' guards
  # against a branch named like an option.
  for b in $(git for-each-ref --format='%(refname:strip=3)' refs/remotes/origin | grep -v -x -e HEAD -e beta -e main); do
    echo ""
    echo "🔀 Merging '$b' into beta..."

    git checkout -b "$b" --track "origin/$b" >/dev/null 2>&1 \
      || git checkout "$b" -- >/dev/null 2>&1 \
      || {
        echo ""
        echo "⚠️ Cannot checkout '$b', skipping."
        continue
      }

    if ! git pull --rebase --no-edit "origin" "$b" >/dev/null 2>&1; then
      echo ""
      echo "⚠️ Pull rebase failed on '$b' — aborting rebase and skipping."
      git rebase --abort >/dev/null 2>&1
      git checkout beta -- >/dev/null 2>&1 || die "🚫 Cannot switch back to beta — repo left on '$b'."
      continue
    fi

    if ! git checkout beta -- >/dev/null 2>&1; then
      echo ""
      echo "⚠️ Cannot switch back to beta from '$b' — skipping (repo left on '$b')." >&2
      die "🚫 Cannot switch back to beta — resolve manually."
    fi

    if ! git merge --no-ff "$b" -m "merge: $b into beta"; then
      echo ""
      echo "⚠️ Merge conflict on '$b' — aborting merge and skipping."
      git merge --abort >/dev/null 2>&1
      continue
    fi

    echo ""
    echo "🗑️ Deleting merged '$b'..."
    # Delete remote only after the local delete succeeds, so we never lose one side.
    if git branch -d -- "$b" >/dev/null 2>&1; then
      git push origin --delete -- "$b" >/dev/null 2>&1 || {
        echo ""
        echo "⚠️ Could not delete remote '$b'"
      }
    else
      echo ""
      echo "⚠️ Keeping '$b' local AND remote (has unmerged commits or could not delete)."
    fi
  done
fi

# --- Branch: switch to target ---

FROM=$(git branch --show-current)

if [ "$FROM" != "$BRANCH" ]; then

  stash_if_dirty "moving from $FROM to $BRANCH"

  echo ""
  echo "🔀 Switching to $BRANCH..."
  if git checkout "$BRANCH" >/dev/null 2>&1; then
    :
  elif git checkout -b "$BRANCH" --track "origin/$BRANCH" >/dev/null 2>&1; then
    :
  elif git checkout -b "$BRANCH" >/dev/null 2>&1; then
    echo ""
    echo "⚠️ '$BRANCH' did not exist locally or on origin — created it from '$FROM'."
  else
    [ "$DIRTY" = true ] && git stash pop >/dev/null 2>&1
    die "🚫 Cannot switch to $BRANCH"
  fi

  restore_stash

  # Delete the source feature branch with -d (safe: refuses unmerged commits).
  if [ "$FROM" != "main" ] && [ "$FROM" != "beta" ]; then
    echo ""
    echo "🗑️ Deleting branch '$FROM'..."
    git branch -d "$FROM" >/dev/null 2>&1 || {
      echo ""
      echo "⚠️ Keeping '$FROM' — it has unmerged commits (use 'git branch -D $FROM' to force)."
    }
  fi
fi

# --- Ensure branch tracks its remote ---

if ! git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
  echo ""
  echo "🔗 Setting upstream: origin/$BRANCH..."
  git push --set-upstream origin "$BRANCH" || die "🚫 Cannot set upstream for $BRANCH"
fi

# --- Commit & Push (skipped in 'main': its promotion below pushes directly,
#     and a generic pull --rebase here would flatten the merge commit) ---

if [ "$MODE" != "main" ]; then
  if ! is_dirty; then
    echo ""
    echo "⚠️ Nothing to commit — working tree clean."
  else
    echo ""
    echo "📝 Changed files:"
    git status --short

    echo ""
    echo "📦 Staging all..."
    git add -A

    echo ""
    echo "💾 Committing: $MSG"
    git commit -m "$MSG" || die "🚫 Commit failed"
  fi

  echo ""
  echo "🔄 Pulling latest (rebase)..."
  if ! git pull --rebase --no-edit; then
    git rebase --abort >/dev/null 2>&1
    die "🚫 Pull failed — rebase aborted. Local commits are safe on '$BRANCH'. Fix divergence manually and re-run."
  fi

  echo ""
  echo "🚀 Pushing $BRANCH..."
  git push origin "$BRANCH" || die "🚫 Push to $BRANCH failed — local commits are safe on '$BRANCH'."
fi

# --- Main: sync main only ---

if [ "$MODE" = "main" ]; then
  echo ""
  echo "🔄 Syncing main..."

  if is_dirty; then
    echo ""
    echo "📝 Changed files:"
    git status --short

    echo ""
    echo "📦 Staging all..."
    git add -A

    echo ""
    echo "💾 Committing: $MSG"
    git commit -m "$MSG" || die "🚫 Commit on main failed"
  fi

  if ! git pull --rebase --no-edit >/dev/null 2>&1; then
    git rebase --abort >/dev/null 2>&1
    echo ""
    echo "⚠️ Diverged from origin/main — merging remote into local, keeping local commits..."
    git fetch origin main >/dev/null 2>&1 || die "🚫 Fetch failed while syncing main."
    if ! git merge --no-ff origin/main -m "merge: origin/main into main"; then
      git merge --abort >/dev/null 2>&1
      die "🚫 Merge origin/main into main failed — resolve conflicts manually."
    fi
  fi

  echo ""
  echo "🚀 Pushing main..."
  if ! git push origin main; then
    git checkout beta >/dev/null 2>&1 || {
      echo ""
      echo "⚠️ Could not return to beta — you are on 'main'." >&2
    }
    die "🚫 Push main failed — local commits are safe on 'main'. Re-run to retry."
  fi
fi

# --- Full: promote beta → main ---

if [ "$MODE" = "full" ]; then
  echo ""
  echo "⬆️ Promoting beta → main..."
  git checkout main >/dev/null 2>&1 \
    || git checkout -b main --track origin/main >/dev/null 2>&1 \
    || die "🚫 Cannot switch to main"

  if ! git pull --rebase --no-edit >/dev/null 2>&1; then
    git rebase --abort >/dev/null 2>&1
    git checkout beta >/dev/null 2>&1 || {
      echo ""
      echo "⚠️ Could not return to beta — you are on 'main'." >&2
    }
    die "🚫 Pull on main failed — aborted. Resolve divergence manually."
  fi

  if ! git merge --no-ff beta -m "merge: beta into main"; then
    git merge --abort >/dev/null 2>&1
    git checkout beta >/dev/null 2>&1 || {
      echo ""
      echo "⚠️ Could not return to beta — you are on 'main'." >&2
    }
    die "🚫 Merge beta into main failed — aborted. Resolve conflicts manually."
  fi

  if ! git push origin main; then
    git checkout beta >/dev/null 2>&1 || {
      echo ""
      echo "⚠️ Could not return to beta — you are on 'main'." >&2
    }
    die "🚫 Push main failed — beta is pushed but main is NOT. Re-run to retry promotion."
  fi

  echo ""
  echo "🔙 Returning to beta..."
  git checkout beta >/dev/null 2>&1 || die "🚫 Cannot return to beta"

  echo ""
  echo "🔄 Syncing main → beta..."
  if ! git merge --no-ff main -m "merge: main into beta"; then
    git merge --abort >/dev/null 2>&1
    die "🚫 Merge main into beta failed — main is already pushed. Resolve conflicts manually."
  fi

  echo ""
  echo "🚀 Pushing beta..."
  git push origin beta || die "🚫 Push beta failed — main is pushed but beta is NOT. Re-run to retry."

fi

# --- Return to branch ---

if [ "$BRANCH" = "beta" ] || [ "$BRANCH" = "full" ]; then
  echo ""
  echo "🔙 Returning to beta..."
  git checkout beta >/dev/null 2>&1 \
    || git checkout -b beta --track origin/beta >/dev/null 2>&1 \
    || git checkout -b beta \
    || die "🚫 Cannot return to beta"
fi

if [ "$BRANCH" = "main" ]; then
  echo ""
  echo "🔙 Returning to main..."
  git checkout main >/dev/null 2>&1 \
    || git checkout -b main --track origin/main >/dev/null 2>&1 \
    || git checkout -b main \
    || die "🚫 Cannot return to main"
fi

# --- Done ---

echo ""
echo "✅ git.sh — Done"
echo ""
echo "📌 Worked on: $MODE"
echo "📍 Current branch: $(git branch --show-current)"
echo ""
git status -sb
echo ""
echo "════════════════════════════════"
echo ""
