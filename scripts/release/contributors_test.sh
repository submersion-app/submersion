#!/usr/bin/env bash
# Tests for contributors.sh, the authorship map behind release-note credits.
#
# Two properties matter more than the formatting: the PR number for every
# commit is derived from git alone, so it survives with no network at all, and
# no GitHub API failure is ever fatal. A release must not be blocked because
# credits could not be looked up.
#
# The GitHub calls are exercised through a stub binary injected with GH=, so
# this suite never touches the network.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTRIB="$SCRIPT_DIR/contributors.sh"

fail() { echo "FAIL: $1"; exit 1; }

# --- A scratch repository shaped like a real release range -----------------
# One merged PR from an outside contributor (two commits, one of them the
# intra-PR noise that per-commit bullets carry), plus one commit pushed
# straight to main.
TMPREPO=$(mktemp -d)
STUBDIR=$(mktemp -d)
trap 'rm -rf "$TMPREPO" "$STUBDIR"' EXIT

git_c() { git -c user.name=t -c user.email=t@t "$@"; }

(
  cd "$TMPREPO"
  git init -q -b main
  git_c commit -q --allow-empty -m "chore: initial"
  git tag v1.0.0.1

  git checkout -q -b feat/x
  git_c commit -q --allow-empty \
    --author "Octo Cat <123+octocat@users.noreply.github.com>" \
    -m "feat: report a new thing"
  git_c commit -q --allow-empty \
    --author "Octo Cat <123+octocat@users.noreply.github.com>" \
    -m "Fixed formatting defects."

  git checkout -q main
  git_c merge -q --no-ff feat/x \
    -m "Merge pull request #42 from octocat/feat/x" \
    -m "feat: report a new thing"

  git_c commit -q --allow-empty -m "docs: release notes"

  # A squash-merged PR: no merge commit exists, and GitHub records the number
  # by appending it to the subject instead. Older ranges in this repo are
  # shaped this way.
  git_c commit -q --allow-empty \
    --author "Squashy <9+squashy@users.noreply.github.com>" \
    -m "fix(import): handle an empty file (#7)"

  # A dependabot PR: its author must never be credited.
  git checkout -q -b deps/bump
  git_c commit -q --allow-empty \
    --author "dependabot[bot] <49699333+dependabot[bot]@users.noreply.github.com>" \
    -m "chore(deps): bump a package"
  git checkout -q main
  git_c merge -q --no-ff deps/bump \
    -m "Merge pull request #43 from submersion-app/deps/bump" \
    -m "chore(deps): bump a package"
)

RANGE="v1.0.0.1..HEAD"
run() { (cd "$TMPREPO" && "$CONTRIB" --range "$RANGE" --repo o/r "$@"); }

sha_of() { (cd "$TMPREPO" && git log --format='%H' --no-merges --grep="$1" -1); }

# --- Offline: PR numbers come from git, logins from noreply emails ---------
OFFLINE=$(run --no-network 2>/dev/null)
OFFLINE_ERR=$(run --no-network 2>&1 >/dev/null)

echo "$OFFLINE" | grep -qE '^(Resolving|Looking|Found )' \
  && fail "progress output leaked onto stdout"

# Merge commits are not part of the map: the changelog walks --no-merges, and
# a merge's author is whoever clicked the button, not the contributor.
[ "$(echo "$OFFLINE" | grep -c '^commit')" -eq 5 ] \
  || fail "expected 5 commit rows, got: $(echo "$OFFLINE" | grep -c '^commit')"

FEAT_SHA=$(sha_of "report a new thing")
echo "$OFFLINE" | grep -q "^commit	$FEAT_SHA	octocat	42$" \
  || fail "PR-mapped feat commit missing or wrong: $(echo "$OFFLINE" | grep "$FEAT_SHA")"

NOISE_SHA=$(sha_of "Fixed formatting defects")
echo "$OFFLINE" | grep -q "^commit	$NOISE_SHA	octocat	42$" \
  || fail "intra-PR commit not attributed to its PR"

# A commit pushed straight to main has an author but no PR, and its git
# identity is not a GitHub noreply address, so there is no login to claim.
DOC_SHA=$(sha_of "release notes")
echo "$OFFLINE" | grep -q "^commit	$DOC_SHA		$" \
  || fail "direct commit should carry neither login nor PR: $(echo "$OFFLINE" | grep "$DOC_SHA")"

# Bots are filtered: the row survives (so the commit still resolves) with an
# empty login, so the bullet renders unattributed.
# A squash merge leaves the PR number only in the subject.
SQUASH_SHA=$(sha_of "handle an empty file")
echo "$OFFLINE" | grep -q "^commit	$SQUASH_SHA	squashy	7$" \
  || fail "squash-merged PR number not recovered from the subject: $(echo "$OFFLINE" | grep "$SQUASH_SHA")"

BOT_SHA=$(sha_of "bump a package")
echo "$OFFLINE" | grep -q "^commit	$BOT_SHA		43$" \
  || fail "bot author was not filtered: $(echo "$OFFLINE" | grep "$BOT_SHA")"

# First-contribution claims need the API; guessing them offline would be wrong.
echo "$OFFLINE" | grep -q '^new' \
  && fail "new-contributor rows must not be emitted without the API"

echo "$OFFLINE_ERR" | grep -q . || fail "offline mode should say so on stderr"

# --- With the API: logins come from GitHub, first-timers are detected ------
cat > "$STUBDIR/gh" <<'STUB'
#!/usr/bin/env bash
# Stub gh. Dispatches on the API path; fixtures come from the environment.
for arg in "$@"; do
  case "$arg" in
    */compare/*) cat "$STUB_COMPARE_TSV"; exit 0 ;;
    */commits\?author=*)
      # A raw "+" in a query string decodes to a space. The offset must be
      # percent-encoded before it reaches the API.
      case "$arg" in *"until="*"+"*) echo "unencoded + in: $arg" >&2; exit 9 ;; esac
      echo "$STUB_PRIOR_COMMITS"; exit 0 ;;
  esac
done
exit 1
STUB
chmod +x "$STUBDIR/gh"

# The API reports a display login that the email heuristic could not produce,
# which is the whole reason for the call.
{
  echo "$FEAT_SHA	OctoCat"
  echo "$NOISE_SHA	OctoCat"
  echo "$DOC_SHA	ericgriffin"
  echo "$BOT_SHA	dependabot[bot]"
  echo "$SQUASH_SHA	squashy"
} > "$STUBDIR/compare.tsv"

ONLINE=$(STUB_COMPARE_TSV="$STUBDIR/compare.tsv" STUB_PRIOR_COMMITS=0 \
  GH="$STUBDIR/gh" run 2>/dev/null)

echo "$ONLINE" | grep -q "^commit	$FEAT_SHA	OctoCat	42$" \
  || fail "API login did not win over the email heuristic"
echo "$ONLINE" | grep -q "^commit	$DOC_SHA	ericgriffin	$" \
  || fail "API login missing for the direct commit"
echo "$ONLINE" | grep -q "^commit	$BOT_SHA		43$" \
  || fail "bot login from the API was not filtered"

# Zero prior commits means a first contribution, credited to the earliest PR
# the contributor appears in.
[ "$(echo "$ONLINE" | grep -c '^new')" -eq 3 ] \
  || fail "expected 3 new-contributor rows, got: $(echo "$ONLINE" | grep '^new')"
echo "$ONLINE" | grep -q "^new	OctoCat	42$" \
  || fail "new-contributor row missing for OctoCat"
echo "$ONLINE" | grep -q '^new	dependabot' \
  && fail "a bot must never be announced as a new contributor"

# A contributor with prior commits is not new.
NOTNEW=$(STUB_COMPARE_TSV="$STUBDIR/compare.tsv" STUB_PRIOR_COMMITS=1 \
  GH="$STUBDIR/gh" run 2>/dev/null)
echo "$NOTNEW" | grep -q '^new' \
  && fail "contributor with prior commits announced as new"

# --- A failing gh must degrade, never abort --------------------------------
cat > "$STUBDIR/gh-broken" <<'STUB'
#!/usr/bin/env bash
echo "gh: HTTP 403" >&2
exit 1
STUB
chmod +x "$STUBDIR/gh-broken"

set +e
BROKEN=$(GH="$STUBDIR/gh-broken" run 2>/dev/null)
BROKEN_STATUS=$?
set -e
[ "$BROKEN_STATUS" -eq 0 ] || fail "a failing gh aborted the script (exit $BROKEN_STATUS)"
echo "$BROKEN" | grep -q "^commit	$FEAT_SHA	octocat	42$" \
  || fail "PR mapping should survive an API failure"
echo "$BROKEN" | grep -q '^new' \
  && fail "no first-contribution claims when the API is unavailable"

# --- An empty range is not an error ----------------------------------------
set +e
EMPTY=$( (cd "$TMPREPO" && "$CONTRIB" --range "HEAD..HEAD" --repo o/r --no-network 2>/dev/null) )
EMPTY_STATUS=$?
set -e
[ "$EMPTY_STATUS" -eq 0 ] || fail "empty range exited $EMPTY_STATUS"
[ -z "$EMPTY" ] || fail "empty range produced output: $EMPTY"

echo "PASS: contributors.sh"
