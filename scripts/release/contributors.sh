#!/usr/bin/env bash
# Map every commit in a release range to the person who wrote it and the PR
# that merged it, for the credits in the release notes.
#
# Two sources, deliberately layered so a release is never blocked on credits:
#
#   PR numbers come from git alone. A merge commit records "Merge pull request
#   #N", and `git rev-list <merge>^1..<merge>^2` names the commits that PR
#   contributed, so the #N on every bullet works with no network at all.
#
#   GitHub logins come from the API. Git records a name and an email, never a
#   login, so an @mention that actually notifies the contributor has to be
#   looked up. The fallback derives a login from a
#   `NNN+login@users.noreply.github.com` address, which covers commits made
#   through the GitHub UI but not ones pushed from a workstation.
#
# Merge commits are not in the output: their author is whoever pressed the
# button, and the changelog walks --no-merges anyway.
#
# Usage:
#   contributors.sh --range <gitrange> [--repo owner/name] [--no-network]
#
# Output is TSV on stdout and nothing else:
#   commit<TAB><sha><TAB><login><TAB><pr>      login and pr may be empty
#   new<TAB><login><TAB><pr>                   first contribution to the repo
#
# Bots are never credited: their commit row survives with an empty login so
# the bullet still resolves, and they are never announced as new contributors.
#
# All progress and diagnostics go to stderr; stdout is only ever the TSV.
set -euo pipefail

# Injectable so the test suite can stub the API without touching the network.
GH="${GH:-gh}"

RANGE=""
SLUG=""
NETWORK=true

die() { echo "contributors: $*" >&2; exit 1; }
note() { echo "contributors: $*" >&2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --range) RANGE="${2:-}"; shift 2 ;;
    --repo)  SLUG="${2:-}"; shift 2 ;;
    --no-network) NETWORK=false; shift ;;
    --help|-h) sed -nE '2,/^$/s/^# ?//p' "$0"; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$RANGE" ] || die "--range is required"

if [ -z "$SLUG" ]; then
  SLUG="${GITHUB_REPOSITORY:-}"
fi
if [ -z "$SLUG" ]; then
  SLUG=$(git remote get-url origin 2>/dev/null \
    | sed -E 's#^git@[^:]+:##; s#^https?://[^/]+/##; s#\.git$##' || echo "")
fi

# A range is "<base>..<head>"; a bare ref means all of history, which has no
# base to compare against.
BASE="${RANGE%%..*}"
HEAD_REF="${RANGE##*..}"
[ "$BASE" != "$RANGE" ] || BASE=""

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# --- The commits under consideration ---------------------------------------
git log --no-merges --format='%H%x09%ae%x09%s' "$RANGE" > "$TMP/commits" 2>/dev/null || :
if [ ! -s "$TMP/commits" ]; then
  note "no commits in $RANGE"
  exit 0
fi

# --- PR numbers, from git ---------------------------------------------------
: > "$TMP/prmap"
while IFS=$'\t' read -r merge_sha subject; do
  [ -n "$merge_sha" ] || continue
  pr=$(printf '%s\n' "$subject" \
    | sed -nE 's/^Merge pull request #([0-9]+) .*/\1/p')
  [ -n "$pr" ] || continue
  # Second parent minus first parent is exactly the PR's own commits.
  # awk, not sed: BSD sed does not expand \t in a replacement, so the column
  # separator would have to be a literal tab that is invisible to the next
  # person editing this line.
  git rev-list "${merge_sha}^1..${merge_sha}^2" 2>/dev/null \
    | awk -v pr="$pr" '{ print $0 "\t" pr }' >> "$TMP/prmap" || :
done < <(git log --first-parent --merges --format='%H%x09%s' "$RANGE")

# A squash merge leaves no merge commit at all: GitHub records the number by
# appending "(#N)" to the subject instead. Consulted only when the merge-commit
# map has nothing, so a normal merge is never second-guessed.
pr_for() {
  local pr
  pr=$(awk -F'\t' -v s="$1" '$1 == s { print $2; exit }' "$TMP/prmap")
  if [ -z "$pr" ]; then
    pr=$(printf '%s\n' "$2" | sed -nE 's/.*\(#([0-9]+)\)$/\1/p')
  fi
  printf '%s' "$pr"
}

# --- Logins, from the API where possible ------------------------------------
API_OK=false
: > "$TMP/api"
if [ "$NETWORK" = false ]; then
  note "offline mode: logins derived from commit emails, no first-contribution check"
elif [ -z "$BASE" ]; then
  note "no base ref in '$RANGE': logins derived from commit emails"
elif [ -z "$SLUG" ]; then
  note "could not determine the repository: logins derived from commit emails"
elif "$GH" api --paginate "repos/$SLUG/compare/$BASE...$HEAD_REF" \
       -q '.commits[] | [.sha, (.author.login // "")] | @tsv' \
       > "$TMP/api" 2>"$TMP/apierr"; then
  API_OK=true
else
  note "GitHub API unavailable, falling back to commit emails:"
  sed 's/^/  /' "$TMP/apierr" >&2 || :
fi

# A GitHub noreply address is "NNN+login@users.noreply.github.com" or, for
# older accounts, "login@users.noreply.github.com".
login_from_email() {
  printf '%s\n' "$1" \
    | sed -nE 's/^([0-9]+\+)?([^@]+)@users\.noreply\.github\.com$/\2/p'
}

# Bots author real commits but are not contributors to thank.
is_bot() {
  case "$1" in
    *"[bot]") return 0 ;;
    Copilot|copilot) return 0 ;;
    *) return 1 ;;
  esac
}

login_for() {
  local sha="$1" email="$2" login=""
  if [ "$API_OK" = true ]; then
    login=$(awk -F'\t' -v s="$sha" '$1 == s { print $2; exit }' "$TMP/api")
  fi
  [ -n "$login" ] || login=$(login_from_email "$email")
  if [ -n "$login" ] && is_bot "$login"; then
    login=""
  fi
  printf '%s' "$login"
}

# --- Emit the commit rows, remembering who appeared and where ---------------
: > "$TMP/authors"
while IFS=$'\t' read -r sha email subject; do
  [ -n "$sha" ] || continue
  login=$(login_for "$sha" "$email")
  pr=$(pr_for "$sha" "$subject")
  printf 'commit\t%s\t%s\t%s\n' "$sha" "$login" "$pr"
  [ -n "$login" ] && printf '%s\t%s\n' "$login" "$pr" >> "$TMP/authors"
done < "$TMP/commits"

# --- First contributions ----------------------------------------------------
# Only ever claimed from the API. Announcing someone as a first-time
# contributor when they are not is worse than saying nothing.
[ "$API_OK" = true ] || exit 0

# The "+" of a UTC offset decodes to a space inside a query string, so the
# timestamp is percent-encoded before it becomes an `until` parameter.
BASE_DATE=$(git log -1 --format=%cI "$BASE" 2>/dev/null | sed 's/+/%2B/' || echo "")
if [ -z "$BASE_DATE" ]; then
  note "could not date $BASE: skipping the first-contribution check"
  exit 0
fi

# git log is newest first, so the last row for a login is their earliest
# commit in the range, and its PR is the one that introduced them.
awk -F'\t' '{ pr[$1] = $2; if (!($1 in seen)) { seen[$1]; order[n++] = $1 } }
            END { for (i = 0; i < n; i++) print order[i] "\t" pr[order[i]] }' \
  "$TMP/authors" > "$TMP/unique"

while IFS=$'\t' read -r login pr; do
  [ -n "$login" ] || continue
  prior=$("$GH" api \
    "repos/$SLUG/commits?author=$login&until=$BASE_DATE&per_page=1" \
    -q 'length' 2>/dev/null) || {
      note "could not check prior commits for @$login: not claiming a first contribution"
      continue
    }
  [ "$prior" = "0" ] || continue
  printf 'new\t%s\t%s\n' "$login" "$pr"
done < "$TMP/unique"
