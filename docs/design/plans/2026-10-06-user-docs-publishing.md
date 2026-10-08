# User Docs Publishing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the GitHub wiki into `docs/user/` as the single, code-verified user guide, publish it at `submersion.app/guide/` through a pinned docsify page, and empty the wiki.

**Architecture:** App PR 1 copies the wiki into a flat `docs/user/` with a scripted, reviewable conversion and teaches the docs guard `docs/user/`'s rules. A website PR adds `guide/index.html`, a docsify shell whose `basePath` reads `docs/user/` from `main` at view time. The wiki is cleared once the guide is live. Seven content PRs then audit every page against the code.

**Tech Stack:** Python 3 stdlib (guard, one-off scripts), docsify 5.0.0 + docsify-plugin-flexible-alerts 1.3.0 from jsDelivr with SRI, Node test runner (website tests), git, `gh`.

**Spec:** `docs/design/specs/2026-10-06-user-docs-publishing-design.md`

## Global Constraints

- `docs/user/` is flat; only `images/` may be a subfolder.
- Page files are lowercase-kebab (`dive-logging.md`); `Home.md` becomes `README.md`, `_Sidebar.md` becomes `_sidebar.md`.
- Links between guide pages are file-relative Markdown (`[text](page.md)`, `[text](page.md#anchor)`); images are Markdown (`![alt](images/x.png)`); no raw `<a href>` or `<img src>` with a relative URL.
- Callouts use GitHub alert syntax (`> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`).
- docsify `5.0.0` and `docsify-plugin-flexible-alerts` `1.3.0`, exact versions, every CDN tag with `integrity` (sha384) and `crossorigin="anonymous"`.
- `basePath`: `https://raw.githubusercontent.com/submersion-app/submersion/main/docs/user/`; `routerMode: 'hash'`; `relativePath: false`; `loadSidebar: true`.
- No em-dash (U+2014) or en-dash (U+2013) as punctuation and no spaced hyphen (" - ") as prose punctuation in any added text, commit, PR, issue or comment. No emoji.
- No mention of Claude, Claude Code or Anthropic in any commit, PR, issue, comment or file.
- Every app PR body links the issue: `Refs #$ISSUE`. Stage explicit paths only.
- The wiki is cleared only after the maintainer confirms at Task 5.
- Run commands from the worktree root unless a step says otherwise. The Bash tool's shell is zsh: wrap loops in `bash -c '...'`. `$SCRATCH` is the session scratchpad.

## Review Focus

1. **The wiki is edited after the move but before it is cleared.** The edit would be lost. Task 5 Step 2 refuses to clear unless the wiki's HEAD is still `$WIKI_SHA` recorded in Task 0.
2. **The website PR merges before app PR 1.** `basePath` then reads the old docsify pages from `main` and the guide shows stale, broken content. Task 4 opens the website PR as a draft, and Task 4 Step 10 checks the moved pages are on `main` before marking it ready.
3. **A content PR renames a heading another page links to.** Guard rule 3 fails the PR (`test_missing_anchor_fails`, Task 2).
4. **A content PR adds a page but not its sidebar entry.** Guard rule 2 fails it (`test_page_missing_from_sidebar_fails`, Task 2). The PR that creates a page adds its sidebar entry.
5. **A merged edit does not appear on the site at once.** `raw.githubusercontent.com` caches for about five minutes; Task 13 waits it out before judging the live site.

---

### Task 0: Prepare

**Files:** none changed.

**Interfaces:**
- Produces: `$ISSUE` (issue number), `$WIKI_SHA` (wiki HEAD at the move), `$OLD` (the `main` commit before PR 1, for reading the deleted `guide/` and `features/` pages), `$SCRATCH/wiki` (wiki clone).

- [ ] **Step 1: Confirm the branch**

```bash
git branch --show-current
git log --oneline -3
```

Expected: branch `ericgriffin/user-docs-spec`; the top commits are this plan, the spec amendment and the spec. App PR 1 is built on this branch.

- [ ] **Step 2: Record `$OLD`**

```bash
git fetch -q origin main
git merge-base HEAD origin/main
```

Record the sha as `OLD`. `git show "$OLD":docs/user/guide/<page>.md` reads a source page after PR 1 deletes it.

- [ ] **Step 3: Clone the wiki and record its HEAD**

```bash
rm -rf "$SCRATCH/wiki"
git clone -q https://github.com/submersion-app/submersion.wiki.git "$SCRATCH/wiki"
git -C "$SCRATCH/wiki" rev-parse HEAD
ls "$SCRATCH/wiki" | wc -l
```

Expected: 29 files. Record the sha as `WIKI_SHA` (it was `74f07a125bacfc355213340a753ff2298c6dbadf` when this plan was written; a newer sha is fine, it only has to stay the same until Task 5).

- [ ] **Step 4: Open the tracking issue**

```bash
cat > "$SCRATCH/issue_body.md" <<'EOF'
The GitHub wiki is the authoritative user documentation, but it cannot take pull requests, it has drifted from the app (a spot check found 10 of 10 claims stale), and a partial second copy lives in docs/user/guide/ and docs/user/features/.

Move the wiki into docs/user/ as the single user guide, fold in what the second copy adds, audit every page against the code, publish it at submersion.app/guide/ through a pinned docsify page, and empty the wiki for another use.

Design: docs/design/specs/2026-10-06-user-docs-publishing-design.md
EOF
URL=$(gh issue create --repo submersion-app/submersion --title "Publish the user guide from docs/user at submersion.app/guide" --body-file "$SCRATCH/issue_body.md")
echo "$URL"
gh api -X PATCH "repos/submersion-app/submersion/issues/${URL##*/}" -f type=Task --jq .type.name
```

Record the number as `ISSUE`. Expected: `Task`.

---

### Task 1: Mechanical move (app PR 1, commit 1)

**Files:**
- Delete: `docs/user/guide/`, `docs/user/features/`, `docs/user/index.html`, `docs/user/.nojekyll`, `docs/user/_sidebar.md`, `docs/user/README.md`
- Create: `docs/user/*.md` (29 files from the wiki), `docs/user/images/debug-mode-{1..4}.png`
- Modify: `docs/developer/database.md`, `lib/core/services/sync/device_local_fields.dart`, `.github/workflows/build-all.yml`
- Create (scratchpad, not committed): `$SCRATCH/move_wiki.py`

**Interfaces:**
- Consumes: `$SCRATCH/wiki`, `$WIKI_SHA`.
- Produces: the flat `docs/user/` tree Task 2's guard rules check and Task 4's page reads.

- [ ] **Step 1: Write the move script**

Write `$SCRATCH/move_wiki.py`:

```python
#!/usr/bin/env python3
"""One-off: copy the GitHub wiki into docs/user/ by the spec's conversion rules.

Usage: move_wiki.py WIKI_CLONE REPO_ROOT
Writes docs/user/*.md and docs/user/images/*, downloading the attachment
images. Prints every page it wrote and every link it could not convert.
"""

import os
import re
import sys
import urllib.request

LINK = re.compile(r"\]\(([A-Za-z][A-Za-z0-9-]*)(#[^)\s]*)?\)")
WIKI_LINK = re.compile(r"\[\[([^\]|]+)(?:\|([^\]]+))?\]\]")
A_TAG = re.compile(r'<a href="([A-Za-z][A-Za-z0-9-]*)(#[^"]*)?">(.*?)</a>', re.S)
IMG = re.compile(r'<img\s[^>]*?alt="([^"]*)"[^>]*?src="(https://github\.com/user-attachments/[^"]+)"[^>]*?/?>')
DIV = re.compile(r'^<div class="(tip|warning)">\n(.*?)\n</div>[ \t]*$', re.S | re.M)
EXT = {"image/png": ".png", "image/jpeg": ".jpg", "image/gif": ".gif", "image/webp": ".webp"}


def target_name(page):
    if page == "Home":
        return "README.md"
    if page == "_Sidebar":
        return "_sidebar.md"
    return page.lower() + ".md"


def convert(text, pages, page, images_dir, unconverted):
    def link(m):
        name, frag = m.group(1), m.group(2) or ""
        if name not in pages:
            return m.group(0)
        return f"]({target_name(name)}{frag})"

    def wiki(m):
        first, second = m.group(1).strip(), (m.group(2) or "").strip()
        label, name = (first, second) if second else (first, first.replace(" ", "-"))
        if name not in pages:
            unconverted.append(f"{page}: [[{m.group(0)}]]")
            return m.group(0)
        return f"[{label}]({target_name(name)})"

    # docsify rebases Markdown links and images onto its base path but leaves
    # raw HTML alone, so <a href> and <img src> become Markdown.
    def atag(m):
        name, frag, label = m.group(1), m.group(2) or "", " ".join(m.group(3).split())
        if name not in pages:
            unconverted.append(f"{page}: <a href=\"{name}\">")
            return m.group(0)
        return f"[{label}]({target_name(name)}{frag})"

    counter = {"n": 0}

    def img(m):
        counter["n"] += 1
        with urllib.request.urlopen(m.group(2)) as resp:
            ext = EXT.get(resp.headers.get_content_type(), ".png")
            data = resp.read()
        stem = target_name(page)[:-3]
        name = f"{stem}-{counter['n']}{ext}"
        with open(os.path.join(images_dir, name), "wb") as fh:
            fh.write(data)
        return f"![{m.group(1)}](images/{name})"

    # GitHub strips the class from <div class="tip">, and docsify's theme does
    # not style it, so both rendered these as plain text. Alerts render in both.
    def div(m):
        kind = "TIP" if m.group(1) == "tip" else "WARNING"
        body = [f"> {line}" if line.strip() else ">" for line in m.group(2).split("\n")]
        return "\n".join([f"> [!{kind}]"] + body)

    text = LINK.sub(link, text)
    text = WIKI_LINK.sub(wiki, text)
    text = A_TAG.sub(atag, text)
    text = IMG.sub(img, text)
    text = DIV.sub(div, text)
    return text


def main(argv):
    wiki, repo = argv[1], argv[2]
    out = os.path.join(repo, "docs", "user")
    images = os.path.join(out, "images")
    os.makedirs(images, exist_ok=True)
    pages = {f[:-3] for f in os.listdir(wiki) if f.endswith(".md")}
    unconverted = []
    for page in sorted(pages):
        with open(os.path.join(wiki, page + ".md"), encoding="utf-8", newline="") as fh:
            text = fh.read()
        text = convert(text, pages, page, images, unconverted)
        with open(os.path.join(out, target_name(page)), "w", encoding="utf-8", newline="") as fh:
            fh.write(text)
        print("wrote", target_name(page))
    if not os.listdir(images):
        os.rmdir(images)
    for line in unconverted:
        print("UNCONVERTED", line)
    return 1 if unconverted else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

- [ ] **Step 2: Remove the old user docs**

```bash
git rm -rq docs/user/guide docs/user/features
git rm -q docs/user/index.html docs/user/.nojekyll docs/user/_sidebar.md docs/user/README.md
ls docs/user 2>/dev/null | wc -l
```

Expected: `0`.

- [ ] **Step 3: Run the move**

```bash
python3 "$SCRATCH/move_wiki.py" "$SCRATCH/wiki" . | grep -v '^wrote'; echo "exit=$?"
ls docs/user | wc -l
ls docs/user/images
```

Expected: no `UNCONVERTED` lines; 30 entries (29 pages plus `images`); `images` holds `debug-mode-1.png` to `debug-mode-4.png`.

- [ ] **Step 4: Check the conversion counts**

```bash
bash -c 'cd docs/user; echo "callouts=$(cat *.md | grep -c "^> \[!")"; echo "raw_div=$(cat *.md | grep -c "<div class=")"; echo "raw_a=$(cat *.md | grep -c "<a href")"; echo "raw_img=$(cat *.md | grep -c "<img")"; echo "wiki_links=$(cat *.md | grep -cE "\]\([A-Z][A-Za-z-]*(#[^)]*)?\)")"'
```

Expected: `callouts=130`, `raw_div=0`, `raw_a=0`, `raw_img=0`, `wiki_links=0`.

- [ ] **Step 5: Prove the tree is exactly the script's output**

```bash
rm -rf "$SCRATCH/move_check" && mkdir -p "$SCRATCH/move_check/docs/user"
python3 "$SCRATCH/move_wiki.py" "$SCRATCH/wiki" "$SCRATCH/move_check" > /dev/null
diff -r "$SCRATCH/move_check/docs/user" docs/user && echo IDENTICAL
```

Expected: `IDENTICAL`. This is the review aid for the PR: the move is the script, and the script is the spec's conversion table.

- [ ] **Step 6: Fix the three references to the deleted folder**

In `docs/developer/database.md`, change:

```markdown
[What Syncs Between Devices](../user/guide/multi-device-sync.md#what-syncs-between-devices) section of the user
```

to:

```markdown
"What Syncs Between Devices" section of the [Multi-Device Sync](../user/multi-device-sync.md) page of the user
```

(The anchor returns in Task 11, which adds that section.)

In `lib/core/services/sync/device_local_fields.dart`, change `docs/user/guide/multi-device-sync.md` to `docs/user/multi-device-sync.md`.

In `.github/workflows/build-all.yml`, change `docs/user/guide/installation.md` to `docs/user/installation.md`.

```bash
git grep -n "docs/user/guide\|user/guide/\|docs/user/features" -- . ':!docs/design' ':!CHANGELOG.md'
```

Expected: no output.

- [ ] **Step 7: Run the existing guard**

```bash
python3 scripts/check_docs_links.py
```

Expected: all `ok` (the `docs/user/` rules arrive in Task 2).

- [ ] **Step 8: Commit**

```bash
git add docs/user docs/developer/database.md lib/core/services/sync/device_local_fields.dart .github/workflows/build-all.yml
git status --short | grep -v '^[MADR] ' ; git commit -m "docs(user): move the wiki into docs/user

The GitHub wiki at $WIKI_SHA, converted by a script whose rules are in the
design: lowercase-kebab file names, page-name links to .md links, the four
attachment images copied into docs/user/images, and <div class=\"tip|warning\">,
<a href> and <img> turned into callouts and Markdown, which both GitHub and
docsify render. docs/user/guide, docs/user/features and the unpublished
docsify shell are removed; their content is folded in by the content PRs.

Refs #$ISSUE"
```

Expected: the `grep` prints nothing (no untracked or unstaged leftovers).

---

### Task 2: Guard rules for docs/user (app PR 1, commit 2)

**Files:**
- Modify: `scripts/check_docs_links.py`
- Test: `scripts/check_docs_links_test.py`

**Interfaces:**
- Produces: `github_slug(heading: str) -> str`, `check_user_docs(root: str) -> list[str]`; `main` runs it as "User docs rules".

- [ ] **Step 1: Write the failing tests**

In `scripts/check_docs_links_test.py`, the existing `test_excluded_trees_are_not_checked` uses `docs/user/guide/` as an excluded tree; `docs/user/` is now checked. Change its second line:

```python
        write(self.root, "docs/user/guide/a.md", "[x](guide/gone.md)\n")
```

to:

```python
        write(self.root, "docs/design/plans/b.md", "[x](gone.md)\n")
```

Then insert this class immediately before `class MainTests(unittest.TestCase):`:

```python
class UserDocsTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = self._tmp.name
        self.addCleanup(self._tmp.cleanup)
        write(self.root, "docs/user/README.md", "# Home\n")
        write(self.root, "docs/user/_sidebar.md", "* [Home](README.md)\n* [Sites](dive-sites.md)\n")
        write(self.root, "docs/user/dive-sites.md", "# Dive Sites\n\n## Maps & Layers\n")

    def test_valid_tree_passes(self):
        self.assertEqual(guard.check_user_docs(self.root), [])

    def test_no_user_docs_folder_passes(self):
        with tempfile.TemporaryDirectory() as root:
            self.assertEqual(guard.check_user_docs(root), [])

    def test_subfolder_fails(self):
        write(self.root, "docs/user/guide/old.md")
        failures = guard.check_user_docs(self.root)
        self.assertEqual(len(failures), 1)
        self.assertIn("flat", failures[0])

    def test_images_folder_is_allowed_but_not_for_pages(self):
        write(self.root, "docs/user/images/shot.png")
        self.assertEqual(guard.check_user_docs(self.root), [])
        write(self.root, "docs/user/images/stray.md")
        self.assertEqual(len(guard.check_user_docs(self.root)), 1)

    def test_page_missing_from_sidebar_fails(self):
        write(self.root, "docs/user/trips.md", "# Trips\n")
        failures = guard.check_user_docs(self.root)
        self.assertEqual(len(failures), 1)
        self.assertIn("trips.md", failures[0])

    def test_same_page_and_cross_page_anchors_resolve(self):
        write(
            self.root,
            "docs/user/README.md",
            "# Home\n\n## Getting Started\n\n[a](#getting-started) "
            "[b](dive-sites.md#maps--layers)\n",
        )
        self.assertEqual(guard.check_user_docs(self.root), [])

    def test_missing_anchor_fails(self):
        write(self.root, "docs/user/README.md", "# Home\n\n[a](#nowhere) [b](dive-sites.md#gone)\n")
        failures = guard.check_user_docs(self.root)
        self.assertEqual(len(failures), 2)
        self.assertIn("#nowhere", failures[0])

    def test_github_slug_rules(self):
        self.assertEqual(guard.github_slug("Security & Privacy"), "security--privacy")
        self.assertEqual(guard.github_slug("Use `ppO2` limits"), "use-ppo2-limits")
        self.assertEqual(guard.github_slug("See [Sites](dive-sites.md) **now**"), "see-sites-now")
        self.assertEqual(guard.github_slug("Tanks &mdash; or gear?"), "tanks--or-gear")

    def test_repeated_heading_gets_a_suffix(self):
        write(self.root, "docs/user/README.md", "# Home\n\n## Notes\n\n## Notes\n\n[a](#notes-1)\n")
        self.assertEqual(guard.check_user_docs(self.root), [])

    def test_link_to_digit_leading_heading_fails(self):
        write(
            self.root,
            "docs/user/README.md",
            "# Home\n\n## 1. Enable R2\n\n## 2. Create a bucket\n\n[a](#1-enable-r2)\n",
        )
        failures = guard.check_user_docs(self.root)
        self.assertEqual(len(failures), 1)
        self.assertIn("digit", failures[0])

    def test_links_outside_user_docs_are_left_to_check_links(self):
        write(self.root, "docs/user/README.md", "# Home\n\n[a](../developer/x.md#y) [b](https://e.org/a#b)\n")
        self.assertEqual(guard.check_user_docs(self.root), [])

    def test_raw_relative_html_link_or_image_fails(self):
        write(
            self.root,
            "docs/user/README.md",
            '# Home\n\n<a href="dive-sites.md">Sites</a>\n<img src="images/x.png" alt="x">\n'
            '<a href="https://example.com">ok</a>\n',
        )
        failures = guard.check_user_docs(self.root)
        self.assertEqual(len(failures), 2)
        self.assertIn("Markdown", failures[0])
```

- [ ] **Step 2: Run them to see them fail**

```bash
python3 scripts/check_docs_links_test.py 2>&1 | grep -E "^Ran|^OK|^FAILED"
```

Expected: `FAILED (errors=12)`: the 12 new tests error on the missing `check_user_docs` / `github_slug`.

- [ ] **Step 3: Implement**

In `scripts/check_docs_links.py`:

1. Add `import html` above `import os`.
2. Add `os.path.join("docs", "user"),` as the last entry of `LINK_ROOTS`.
3. Insert this block immediately before `def _has_files(folder):`:

```python
# docs/user/ is published by docsify, which resolves links from one root, so
# the folder stays flat (images/ aside), every page must be in the sidebar
# docsify navigates by, and every anchor must mean the same heading on GitHub
# and in docsify.
USER_DOCS = os.path.join("docs", "user")
USER_IMAGES = "images"
USER_HOME = "README.md"
USER_SIDEBAR = "_sidebar.md"
HEADING_RE = re.compile(r"^\s{0,3}#{1,6}\s+(.*?)\s*#*\s*$")
# docsify rebases Markdown links and images onto its base path, but not raw
# HTML, so a relative <a href> or <img src> works on GitHub and breaks on the
# published guide.
RAW_HTML_URL_RE = re.compile(r"""<(?:a|img)\b[^>]*\b(?:href|src)\s*=\s*["']([^"']+)["']""")


def github_slug(heading):
    """The anchor GitHub gives a heading: link text kept, markup and
    punctuation dropped, lowercased, each space a hyphen."""
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", heading)
    text = re.sub(r"<[^>]+>", "", text)
    text = html.unescape(text).replace("`", "").replace("*", "")
    text = re.sub(r"[^\w\- ]", "", text.lower())
    return text.replace(" ", "-")


def _heading_slugs(text):
    seen, slugs = {}, set()
    for _number, line in _unfenced_lines(text):
        match = HEADING_RE.match(line)
        if not match:
            continue
        base = github_slug(match.group(1))
        count = seen.get(base, 0)
        seen[base] = count + 1
        slugs.add(base if count == 0 else f"{base}-{count}")
    return slugs


def check_user_docs(root):
    base = os.path.join(root, USER_DOCS)
    if not os.path.isdir(base):
        return []
    failures, pages = [], {}
    for entry in sorted(os.listdir(base)):
        full = os.path.join(base, entry)
        rel = os.path.join(USER_DOCS, entry)
        if os.path.isdir(full):
            if entry != USER_IMAGES:
                failures.append(f"{rel}/: docs/user/ is flat; move these pages up a level")
                continue
            for dirpath, _dirnames, filenames in os.walk(full):
                for name in sorted(filenames):
                    if name.endswith(".md"):
                        stray = os.path.relpath(os.path.join(dirpath, name), root)
                        failures.append(f"{stray}: pages belong in docs/user/, not images/")
        elif entry.endswith(".md"):
            pages[entry] = _read_text(full) or ""

    sidebar = pages.get(USER_SIDEBAR, "")
    linked = {
        os.path.basename(unquote(url.split("#", 1)[0]))
        for _number, line in _unfenced_lines(sidebar)
        for url in _link_targets(line)
    }
    for name in sorted(pages):
        if name not in (USER_HOME, USER_SIDEBAR) and name not in linked:
            failures.append(
                f"{os.path.join(USER_DOCS, name)}: not linked from {USER_SIDEBAR}, "
                "so the published guide cannot reach it"
            )

    slugs = {name: _heading_slugs(text) for name, text in pages.items()}
    for name, text in sorted(pages.items()):
        rel = os.path.join(USER_DOCS, name)
        for number, line in _unfenced_lines(text):
            for match in RAW_HTML_URL_RE.finditer(INLINE_CODE_RE.sub("", line)):
                url = match.group(1)
                if not (SCHEME_RE.match(url) or url.startswith(("#", "//"))):
                    failures.append(
                        f"{rel}:{number}: raw HTML link or image -> {url}; use Markdown "
                        "([text](page.md) or ![alt](images/x.png)) so the published guide resolves it"
                    )
            for url in _link_targets(line):
                if SCHEME_RE.match(url) or "#" not in url:
                    continue
                path, fragment = url.split("#", 1)
                path = unquote(path.split("?", 1)[0])
                if "/" in path or (path and path not in pages):
                    continue  # outside docs/user/, or missing: check_links reports it
                target = path or name
                fragment = unquote(fragment)
                if fragment not in slugs[target]:
                    failures.append(f"{rel}:{number}: no heading for anchor -> {url}")
                elif fragment[:1].isdigit():
                    failures.append(
                        f"{rel}:{number}: anchor starts with a digit, which docsify "
                        f"prefixes with '_', so the link breaks on the site -> {url}"
                    )
    return failures
```

4. In `main`, add `("User docs rules", check_user_docs),` after `("Retired docs folders", check_retired),`.

- [ ] **Step 4: Run the tests to see them pass**

```bash
python3 scripts/check_docs_links_test.py 2>&1 | grep -E "^Ran|^OK|^FAILED"
python3 scripts/check_docs_links.py
```

Expected: `Ran 41 tests` and `OK`; the guard prints four `ok` lines and exits 0 on the moved tree.

- [ ] **Step 5: Mutation check**

```bash
cp docs/user/README.md "$SCRATCH/readme.bak"
printf '\n[x](#no-such-heading)\n<img src="images/x.png" alt="x">\n' >> docs/user/README.md
printf '# Orphan\n' > docs/user/orphan.md
python3 scripts/check_docs_links.py | grep FAIL; echo "exit=$?"
cp "$SCRATCH/readme.bak" docs/user/README.md; rm docs/user/orphan.md
git status --short docs/user
```

Expected: three `FAIL` lines (anchor, raw image, orphan page); the final `git status` prints nothing.

- [ ] **Step 6: Commit**

```bash
git add scripts/check_docs_links.py scripts/check_docs_links_test.py
git commit -m "ci: teach the docs guard docs/user's rules

docs/user/ is now a checked tree, plus four rules for the published guide:
it stays flat (images/ aside), every page is in _sidebar.md, every anchor
resolves under GitHub's slug rules and none targets a heading starting
with a digit (docsify prefixes those), and no raw relative <a href> or
<img src> (docsify does not rebase them).

Refs #$ISSUE"
```

---

### Task 3: Inbound links and contributor docs (app PR 1, commit 3), then open PR 1

**Files:**
- Modify: `README.md`, `CONTRIBUTING.md`, `docs/README.md`, `docs/developer/release-process.md`, `docs/contributing/README.md`

- [ ] **Step 1: README**

In `README.md`, after the `- **macOS / Windows / Linux:** [GitHub Releases](https://github.com/submersion-app/submersion/releases)` line of `## Download`, add a blank line and:

```markdown
New to Submersion? The [user guide](https://submersion.app/guide/) covers
everything from your first dive to sync and backup.
```

- [ ] **Step 2: CONTRIBUTING**

In `CONTRIBUTING.md`, replace:

```markdown
- **Improve documentation** — the `docs/` directory powers the developer guide
  and the published site.
```

with:

```markdown
- **Improve documentation**: the user guide is the Markdown in `docs/user/`,
  published at [submersion.app/guide](https://submersion.app/guide/) once
  merged; developer docs are the rest of `docs/`.
```

- [ ] **Step 3: docs map**

In `docs/README.md`, replace the `user/` row with:

```markdown
| [user/](user/README.md) | Divers using the app | The user guide, published at [submersion.app/guide](https://submersion.app/guide/) |
```

- [ ] **Step 4: Release process**

In `docs/developer/release-process.md`, replace:

```markdown
User-facing channel documentation is on the wiki:
[Update Channels](https://github.com/submersion-app/submersion/wiki/Update-Channels).
```

with:

```markdown
User-facing channel documentation is in the user guide:
[Update Channels](../user/update-channels.md).
```

- [ ] **Step 5: Writing user docs**

In `docs/contributing/README.md`, insert before `## Code Review`:

```markdown
## Writing User Docs

The user guide is the Markdown in [`docs/user/`](../user/README.md). The
website shows it at [submersion.app/guide](https://submersion.app/guide/),
reading `main` directly, so a merged change appears within a few minutes.

- **One folder.** Every page sits directly in `docs/user/`; screenshots go
  in `docs/user/images/`. Name pages in lowercase-kebab (`dive-sites.md`).
- **Links are Markdown and file-relative:** `[Dive Sites](dive-sites.md)`,
  `[Sync options](multi-device-sync.md#sync-options)`. Images likewise:
  `![Alt text](images/name.png)`. The site cannot resolve a relative HTML
  `<a href>` or `<img src>`.
- **New pages go in [`_sidebar.md`](../user/_sidebar.md)**, or the site
  cannot reach them.
- **Callouts** use GitHub's syntax, which the site renders too:
  `> [!NOTE]`, `> [!TIP]`, `> [!WARNING]`.
- **Check what you write against the app.** Use the exact on-screen label
  (the English strings are in `lib/l10n/arb/app_en.arb`) and the real menu
  path.
- No em-dashes and no emoji.

`python3 scripts/check_docs_links.py` checks the links, anchors, sidebar
and folder rules; CI runs it on every pull request.
```

- [ ] **Step 6: Verify and commit**

```bash
python3 scripts/check_docs_links.py
git add README.md CONTRIBUTING.md docs/README.md docs/developer/release-process.md docs/contributing/README.md
git commit -m "docs: point readers and contributors at the user guide

Refs #$ISSUE"
```

Expected: the guard passes.

- [ ] **Step 7: Push and open PR 1**

```bash
git push -u origin ericgriffin/user-docs-spec
```

PR title: `docs(user): move the wiki into docs/user as the user guide`. Body sections (repository template): **Related Issue** `Refs #$ISSUE`; **Summary**: the design link, the move (wiki sha, conversion table, `IDENTICAL` diff from Task 1 Step 5), the guard rules, the inbound links, and that content PRs and the website PR follow; **Test Plan**: guard tests 41 OK, guard passes, mutation check; **Screenshots**: delete the section (no UI paths). Create it with `gh pr create --base main --head ericgriffin/user-docs-spec --title ... --body-file "$SCRATCH/pr1_body.md"`, then bind it in the desktop app (`get_status`, `bind_pr` if needed).

---

### Task 4: The website page (website PR)

All steps run in a fresh clone of `submersion-app/submersion-website` at `$SCRATCH/website-guide`.

**Files (website repo):**
- Create: `guide/index.html`, `guide/guide.css`, `tests/guide-page.test.mjs`
- Modify: `index.html`, `computers/index.html`, `privacy/index.html`, `terms/index.html`, `tests/support-matrix-page.test.mjs`

**Interfaces:**
- Consumes: the moved `docs/user/` on the PR 1 branch (for the render check).

- [ ] **Step 1: Clone and branch**

```bash
rm -rf "$SCRATCH/website-guide"
git clone -q https://github.com/submersion-app/submersion-website.git "$SCRATCH/website-guide"
cd "$SCRATCH/website-guide" && git switch -q -c ericgriffin/user-guide
```

- [ ] **Step 2: Write the failing test**

Create `tests/guide-page.test.mjs`:

```javascript
// The user guide page. Its text lives in the app repo's docs/user/ and is read
// from main at view time, so what this page must get right is the wiring:
// pinned, integrity-checked scripts, the right source folder, and a way in
// from every other page.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), "utf8");
const guide = read("guide/index.html");

const externalTags = [...guide.matchAll(/<(script|link)\b[^>]*\b(?:src|href)="(https:\/\/cdn\.jsdelivr\.net\/[^"]+)"[^>]*>/g)];

test("every CDN file is version-pinned and integrity-checked", () => {
  assert.ok(externalTags.length >= 5, "expected docsify, its search plugin, two themes and the alerts plugin");
  for (const [tag, , url] of externalTags) {
    assert.match(url, /@\d+\.\d+\.\d+\//, `not pinned to an exact version: ${url}`);
    assert.doesNotMatch(url, /@latest/, `floating version: ${url}`);
    assert.match(tag, /\bintegrity="sha384-[A-Za-z0-9+/=]+"/, `no integrity hash: ${url}`);
    assert.match(tag, /\bcrossorigin="anonymous"/, `integrity needs crossorigin: ${url}`);
  }
});

test("the guide reads docs/user/ from the app repo's main branch", () => {
  assert.match(
    guide,
    /basePath:\s*'https:\/\/raw\.githubusercontent\.com\/submersion-app\/submersion\/main\/docs\/user\/'/,
  );
  assert.match(guide, /homepage:\s*'README\.md'/);
});

test("the sidebar comes from docs/user/ and routing is hash-based", () => {
  assert.match(guide, /loadSidebar:\s*true/);
  assert.match(guide, /routerMode:\s*'hash'/);
  assert.match(guide, /relativePath:\s*false/);
});

test("every page offers an edit link into docs/user/ on main", () => {
  assert.match(guide, /https:\/\/github\.com\/submersion-app\/submersion\/edit\/main\/docs\/user\//);
});

test("without JavaScript the reader is sent to the Markdown on GitHub", () => {
  assert.match(guide, /<noscript>[\s\S]*github\.com\/submersion-app\/submersion\/tree\/main\/docs\/user[\s\S]*<\/noscript>/);
});

const sitePages = ["index.html", "computers/index.html", "privacy/index.html", "terms/index.html", "lightroom/index.html"];

test("every header nav links to the guide", () => {
  for (const page of sitePages) {
    const html = read(page);
    const nav = html.match(/<div class="nav__links">([\s\S]*?)<\/div>/);
    if (!nav) continue;
    assert.match(nav[1], /href="(?:\.\.\/)?guide\/">Guide<\/a>/, `${page}: header nav has no Guide link`);
  }
});

test("every footer link row links to the guide", () => {
  for (const page of sitePages) {
    const html = read(page);
    const row = html.match(/<div class="footer__links">([\s\S]*?)<\/div>/);
    if (!row) continue;
    assert.match(row[1], /href="(?:\.\.\/)?guide\/">User Guide<\/a>/, `${page}: footer has no User Guide link`);
  }
});
```

```bash
cd "$SCRATCH/website-guide" && bash -c 'node --test tests/guide-page.test.mjs > ../guide1.log 2>&1; echo exit=$?'; grep -E "ENOENT|ℹ (pass|fail)" ../guide1.log | head -3
```

Expected: `exit=1` with `ENOENT` for `guide/index.html`.

- [ ] **Step 3: Write the page**

Create `guide/index.html`:

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="color-scheme" content="dark" />
    <meta name="theme-color" content="#49e8ff" />
    <title>User Guide · Submersion Dive Log</title>
    <meta
      name="description"
      content="The Submersion user guide: logging dives, dive computers, sites, gear, planning, sync and backup."
    />
    <link rel="canonical" href="https://submersion.app/guide/" />
    <link rel="icon" type="image/png" href="../assets/favicon.png" />
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link
      href="https://fonts.googleapis.com/css2?family=Inter:opsz,wght@14..32,300..800&display=swap"
      rel="stylesheet"
    />
    <!-- docsify and its plugins are pinned to exact versions with subresource
         integrity: the browser refuses any file whose bytes differ. To upgrade,
         change the version in every URL and recompute each hash with
         curl -s URL | openssl dgst -sha384 -binary | openssl base64 -A -->
    <link
      rel="stylesheet"
      href="https://cdn.jsdelivr.net/npm/docsify@5.0.0/dist/themes/core.min.css"
      integrity="sha384-u1ltA0BWEetQbGokjUjglT9sN702RQwy8JESh3Ha4GNlyzMU57usk6duY0/BOTMj"
      crossorigin="anonymous"
    />
    <link
      rel="stylesheet"
      href="https://cdn.jsdelivr.net/npm/docsify@5.0.0/dist/themes/addons/core-dark.min.css"
      integrity="sha384-g9crfHW8IcGuSHfca3iTqOPPx2uRbodq5uKkC9CiXVqnNVszeNEYKIs5nYc8wUXY"
      crossorigin="anonymous"
    />
    <link rel="stylesheet" href="guide.css" />
  </head>
  <body>
    <!-- The guide's text lives in the app repository under docs/user/ and is
         read from main at view time, so nothing here goes out of date. Edit it
         there: https://github.com/submersion-app/submersion/tree/main/docs/user -->
    <nav class="guide-nav" aria-label="Primary">
      <a href="../">Home</a>
      <a href="../#download">Download</a>
      <a href="https://github.com/submersion-app/submersion" target="_blank" rel="noreferrer">GitHub</a>
    </nav>
    <div id="app">Loading the guide...</div>
    <noscript>
      <p class="guide-noscript">
        The guide needs JavaScript. You can read it on GitHub instead:
        <a href="https://github.com/submersion-app/submersion/tree/main/docs/user">docs/user</a>.
      </p>
    </noscript>
    <script>
      window.$docsify = {
        name: '<img src="../assets/favicon.png" alt="" width="28" height="28" /> Submersion Guide',
        nameLink: './',
        basePath: 'https://raw.githubusercontent.com/submersion-app/submersion/main/docs/user/',
        homepage: 'README.md',
        loadSidebar: true,
        relativePath: false,
        routerMode: 'hash',
        auto2top: true,
        subMaxLevel: 2,
        search: { paths: 'auto', placeholder: 'Search the guide', noData: 'No matches' },
        'flexible-alerts': { style: 'callout' },
        plugins: [
          function editLink(hook, vm) {
            hook.afterEach(function (html) {
              var file = vm.route.file || 'README.md';
              var page = file.split('/').pop();
              var url = 'https://github.com/submersion-app/submersion/edit/main/docs/user/' + page;
              return (
                html +
                '<p class="guide-edit"><a href="' + url + '" target="_blank" rel="noreferrer">' +
                'Edit this page on GitHub</a></p>'
              );
            });
          },
        ],
      };
    </script>
    <script
      src="https://cdn.jsdelivr.net/npm/docsify@5.0.0/dist/docsify.min.js"
      integrity="sha384-w6yZXzkazsxmservgGooUY9zjEHzIFHubRNZMLJ3enj/JD+Z8BvAGBqdrjfnLNhu"
      crossorigin="anonymous"
    ></script>
    <script
      src="https://cdn.jsdelivr.net/npm/docsify@5.0.0/dist/plugins/search.min.js"
      integrity="sha384-wZGyhbW44GtFpUJG1z6siOX84RFRDAht5UTeOlV/LlRP6T2GXj3LrLwcUHTyzfby"
      crossorigin="anonymous"
    ></script>
    <script
      src="https://cdn.jsdelivr.net/npm/docsify-plugin-flexible-alerts@1.3.0/dist/docsify-plugin-flexible-alerts.min.js"
      integrity="sha384-62mB0esH4v+xjk8v2AlYluN29nnWLddo1FVuCmZJQJE3ULtg6NbWOPGyX4TWutgu"
      crossorigin="anonymous"
    ></script>
  </body>
</html>
```

Create `guide/guide.css`:

```css
/* The user guide: docsify's core theme with its dark add-on, recoloured to
   the site's palette. The values mirror the tokens at the top of
   ../styles.css; keep them in step if the palette changes. */
:root {
  --theme-color: #8fdcec;
  --base-background-color: #04182a;
  --base-color: #eaf6fa;
  --base-font-family: "Inter", system-ui, -apple-system, "Segoe UI", sans-serif;
  --sidebar-background: #021120;
  --sidebar-nav-link-color: rgba(234, 246, 250, 0.72);
  --link-color: #8fdcec;
  --heading-color: #eaf6fa;
}

.guide-nav {
  position: fixed;
  top: 0;
  right: 0;
  z-index: 30;
  display: flex;
  gap: 1.25rem;
  padding: 0.9rem 1.5rem;
  font-family: var(--base-font-family);
  font-size: 0.9rem;
}

.guide-nav a {
  color: rgba(234, 246, 250, 0.72);
  text-decoration: none;
}

.guide-nav a:hover,
.guide-nav a:focus-visible {
  color: #8fdcec;
}

.guide-edit {
  margin-top: 3rem;
  padding-top: 1rem;
  border-top: 1px solid rgba(234, 246, 250, 0.16);
  font-size: 0.9rem;
}

.guide-noscript {
  max-width: 40rem;
  margin: 4rem auto;
  padding: 0 1rem;
  color: #eaf6fa;
}
```

```bash
cd "$SCRATCH/website-guide" && bash -c 'node --test tests/guide-page.test.mjs > ../guide2.log 2>&1; echo exit=$?'; grep -E "ℹ (pass|fail)" ../guide2.log
```

Expected: `pass 5`, `fail 2` (the nav and footer tests; the links come next).

- [ ] **Step 4: Verify the pinned hashes are current**

```bash
bash -c 'for u in $(grep -oE "https://cdn\.jsdelivr\.net/npm/[^\"]+" "$0"); do h=$(curl -sf "$u" | openssl dgst -sha384 -binary | openssl base64 -A); grep -q "sha384-$h" "$0" && echo "ok $u" || echo "MISMATCH $u"; done' "$SCRATCH/website-guide/guide/index.html"
```

Expected: five `ok` lines. A `MISMATCH` means jsDelivr serves different bytes for that exact version: stop and investigate rather than updating the hash.

- [ ] **Step 5: Add the Guide links**

Write `$SCRATCH/add_guide_links.py`:

```python
#!/usr/bin/env python3
"""One-off: add the Guide link to every page's header nav and footer row."""
import re

PAGES = {  # page: prefix to the site root
    "index.html": "",
    "computers/index.html": "../",
    "privacy/index.html": "../",
    "terms/index.html": "../",
    "lightroom/index.html": "../",
}

for page, up in PAGES.items():
    text = open(page, encoding="utf-8").read()
    nav = re.compile(r'(\n(\s*)<a href="' + re.escape(up) + r'#download">Download</a>)')
    m = nav.search(text)
    if m and 'class="nav__links"' in text:
        text = text[: m.start()] + f'\n{m.group(2)}<a href="{up}guide/">Guide</a>' + text[m.start():]
    row = re.compile(r'(<div class="footer__links">\n(\s*))')
    m = row.search(text)
    if m:
        text = text[: m.end()] + f'<a href="{up}guide/">User Guide</a>\n{m.group(2)}' + text[m.end():]
    open(page, "w", encoding="utf-8").write(text)
    print(page, text.count(f'href="{up}guide/"'))
```

```bash
cd "$SCRATCH/website-guide" && python3 "$SCRATCH/add_guide_links.py"
```

Expected: `index.html 2`, `computers/index.html 2`, `privacy/index.html 2`, `terms/index.html 2`, `lightroom/index.html 0` (it has no nav or link row).

- [ ] **Step 6: Widen the menu test's link rebasing**

```bash
cd "$SCRATCH/website-guide" && bash -c 'node --test tests/*.test.mjs > ../all1.log 2>&1; echo exit=$?'; grep -E "^✖ .*menu|ℹ (pass|fail)" ../all1.log
```

Expected: three failures, `computers/`, `privacy/` and `terms/ uses the homepage's menu`: the test rebases only the homepage's `#section` links, so `guide/` does not match `../guide/`.

In `tests/support-matrix-page.test.mjs`, replace:

```javascript
const homeMenu = () =>
  navLinks(read("index.html")).map(([href, text]) => [href.startsWith("#") ? `../${href}` : href, text]);
```

with:

```javascript
// The homepage's site-relative links ("#log", "guide/") gain "../" on an inner
// page; absolute ones (https:, mailto:, /...) are the same everywhere.
const fromInnerPage = (href) => (/^([a-z]+:|\/)/i.test(href) ? href : `../${href}`);

const homeMenu = () => navLinks(read("index.html")).map(([href, text]) => [fromInnerPage(href), text]);

test("homepage links are rebased for inner pages", () => {
  assert.equal(fromInnerPage("#log"), "../#log");
  assert.equal(fromInnerPage("guide/"), "../guide/");
  assert.equal(fromInnerPage("https://github.com/x"), "https://github.com/x");
});
```

```bash
cd "$SCRATCH/website-guide" && bash -c 'node --test tests/*.test.mjs > ../all2.log 2>&1; echo exit=$?'; grep -E "ℹ (tests|pass|fail)" ../all2.log
```

Expected: `exit=0`, `fail 0`.

- [ ] **Step 7: Render check against the PR 1 branch**

In a throwaway copy (never committed), point `basePath` at the PR 1 branch and serve it:

```bash
rm -rf "$SCRATCH/guide-preview" && mkdir -p "$SCRATCH/guide-preview"
cp -R "$SCRATCH/website-guide/guide" "$SCRATCH/website-guide/assets" "$SCRATCH/website-guide/styles.css" "$SCRATCH/guide-preview/"
sed -i '' "s#/submersion/main/docs/user/#/submersion/ericgriffin/user-docs-spec/docs/user/#" "$SCRATCH/guide-preview/guide/index.html"
grep -c "ericgriffin/user-docs-spec/docs/user/" "$SCRATCH/guide-preview/guide/index.html"
```

Expected: `1` (the integrity hashes cover only the CDN files, so editing this page is safe). Add a temporary `.claude/launch.json` entry (the file is git-ignored) named `guide-preview` that runs `python3 -m http.server 8765 --bind 127.0.0.1 --directory $SCRATCH/guide-preview` on port 8765, start it with `preview_start`, and in the browser pane check, at 1280x860:

- `/guide/#/dive-logging`: 7 `.alert` elements, tables render, cross-page links route as `#/dive-sites`, the edit link points at `edit/main/docs/user/dive-logging.md`;
- `/guide/#/media-sync`: 5 alerts (former tips and warnings), the Marine Life link routes as `#/marine-life-and-photos`;
- `/guide/#/debug-mode`: 4 images load (`naturalWidth > 0`);
- the sidebar lists every page; search finds "Garmin".

Then stop the server and remove the `guide-preview` entry.

- [ ] **Step 8: Commit, push, open a draft PR**

```bash
cd "$SCRATCH/website-guide" && git add guide/index.html guide/guide.css tests/guide-page.test.mjs tests/support-matrix-page.test.mjs index.html computers/index.html privacy/index.html terms/index.html && git commit -m "feat(guide): publish the user guide at /guide/

A docsify page reads the guide from the app repo's docs/user/ on main, so
merged doc changes appear without a sync job. docsify and the alerts
plugin are pinned with subresource integrity. Every page's nav and footer
links to it." && git push -q -u origin ericgriffin/user-guide
gh pr create --repo submersion-app/submersion-website --draft --base main --head ericgriffin/user-guide --title "feat(guide): publish the user guide at /guide/" --body-file "$SCRATCH/website_pr_body.md"
```

The body says: what the page does, the pinned versions and hashes, the tests, and **merge only after submersion-app/submersion app PR 1 merges** (`Refs submersion-app/submersion#$ISSUE`).

- [ ] **Step 9: Wait for app PR 1 to merge**

The maintainer merges app PR 1. Nothing in this task proceeds until it has.

- [ ] **Step 10: Confirm `main` serves the moved guide, then mark ready**

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://raw.githubusercontent.com/submersion-app/submersion/main/docs/user/installation.md
curl -s -o /dev/null -w "%{http_code}\n" https://raw.githubusercontent.com/submersion-app/submersion/main/docs/user/guide/installation.md
gh pr ready --repo submersion-app/submersion-website ericgriffin/user-guide
```

Expected: `200` then `404` (within five minutes of the merge). The maintainer then merges the website PR.

---

### Task 5: Clear the wiki

**Files:** the wiki repository only.

- [ ] **Step 1: Confirm the guide is live**

```bash
curl -s https://submersion.app/guide/ | grep -c "raw.githubusercontent.com/submersion-app/submersion/main/docs/user/"
```

Expected: `1`. Also open `https://submersion.app/guide/#/installation` in the browser pane and confirm the page renders.

- [ ] **Step 2: Confirm nothing changed in the wiki since the move**

```bash
git -C "$SCRATCH/wiki" fetch -q origin
test "$(git -C "$SCRATCH/wiki" rev-parse origin/master)" = "$WIKI_SHA" && echo UNCHANGED || echo CHANGED
```

Expected: `UNCHANGED`. If `CHANGED`, stop: show the maintainer `git -C "$SCRATCH/wiki" log --stat $WIKI_SHA..origin/master` and carry those edits into `docs/user/` in a PR before clearing.

- [ ] **Step 3: Ask the maintainer**

Ask in chat, and wait for an explicit yes: "The guide is live at submersion.app/guide/ and the wiki is unchanged since the move. Clear the wiki now? This deletes all 29 pages (history keeps them) and the wiki shows GitHub's empty-wiki page."

- [ ] **Step 4: Clear and push**

```bash
cd "$SCRATCH/wiki" && git pull -q && git rm -q '*.md' && git commit -q -m "Move the user guide to submersion.app/guide

The guide's source is now docs/user/ in submersion-app/submersion. This
wiki is cleared for another use; its history keeps every page." && git push -q
```

- [ ] **Step 5: Verify**

```bash
rm -rf "$SCRATCH/wiki-verify" && git clone -q https://github.com/submersion-app/submersion.wiki.git "$SCRATCH/wiki-verify"
ls "$SCRATCH/wiki-verify" | wc -l
```

Expected: `0`.

---

### Content tasks (Tasks 6 to 12): shared procedure

Each content task is one PR, branched from `main` after app PR 1 merges, independent of the others. Each follows this procedure for every page it owns.

- [ ] **A. Branch**

```bash
git fetch -q origin main && git switch -c ericgriffin/user-docs-<section> origin/main
```

- [ ] **B. Read the sources**

The wiki page is now `docs/user/<page>.md`. Fold-in sources are read from before PR 1 deleted them: `git show "$OLD":docs/user/guide/<page>.md` or `git show "$OLD":docs/user/features/<page>.md`.

- [ ] **C. Fold in** the task's fold items, each re-checked against the code before it is written.

- [ ] **D. Audit every claim**

Write `$SCRATCH/audit_labels.py` once:

```python
#!/usr/bin/env python3
"""Audit aid: check a user-guide page's bold UI labels against the app's
English strings (lib/l10n/arb/app_en.arb). Run from the repository root.

Usage: audit_labels.py docs/user/<page>.md

FOUND    the label is an exact app string (case-insensitive)
PARTIAL  the label appears inside a longer app string: confirm by hand
MISSING  no app string contains it: either it is not a UI label (emphasis,
         a term) or the page names something the app does not show
"""

import html
import json
import re
import sys

ARB = "lib/l10n/arb/app_en.arb"


def main(argv):
    with open(ARB, encoding="utf-8") as fh:
        arb = json.load(fh)
    values = [v.strip().lower() for k, v in arb.items() if not k.startswith("@") and isinstance(v, str)]
    exact = set(values)
    with open(argv[1], encoding="utf-8") as fh:
        text = fh.read()
    found = re.findall(r"\*\*([^*\n]+)\*\*|<strong>([^<]+)</strong>", text)
    labels = sorted({html.unescape((a or b).strip()).rstrip(":").strip() for a, b in found})
    counts = {"FOUND": 0, "PARTIAL": 0, "MISSING": 0}
    for label in labels:
        key = label.lower()
        if key in exact:
            status = "FOUND"
        elif any(key in value for value in values):
            status = "PARTIAL"
        else:
            status = "MISSING"
        counts[status] += 1
        print(f"{status:8} {label}")
    print(" ".join(f"{k}={v}" for k, v in counts.items()))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

```bash
python3 "$SCRATCH/audit_labels.py" docs/user/<page>.md
```

Every `MISSING` and `PARTIAL` label is resolved: it is not a UI label (leave it), or it names the right control under a different label (fix the label), or it names something the app does not have (rewrite or remove). Then check, by reading the code, every menu path (`lib/shared/widgets/nav/nav_destinations.dart` and the page code), every number (its constant), and every platform statement (build configuration). Record each principal claim and the file it was checked against for the PR body.

- [ ] **E. Rewrite punctuation**

Every `&mdash;` and every spaced hyphen used as punctuation on the page is rewritten into a comma, colon, semicolon, parentheses or two sentences, reading naturally. A callout that repeats its own type in bold (`> [!TIP]` then `**Tip:**`) loses the bold label.

```bash
grep -c '&mdash;\|&ndash;' docs/user/<page>.md
python3 -c "import sys;t=open(sys.argv[1],encoding='utf-8').read();print(t.count(chr(0x2014))+t.count(chr(0x2013)))" docs/user/<page>.md
```

Expected: `0` and `0`.

- [ ] **F. Verify and commit**

```bash
python3 scripts/check_docs_links.py
git add docs/user/<pages...>
git commit -m "docs(user): <section>: fold in and verify against the code

Refs #$ISSUE"
```

- [ ] **G. PR**

Title `docs(user): audit <section> against the app`. Body: **Related Issue** `Refs #$ISSUE`; **Summary** listing what was folded in, what stale claims were fixed, and what was removed; a **Claims checked** table (claim, page, file checked against); **Screenshots** section deleted.

---

### Task 6: Getting Started (README, installation, first-dive)

- [ ] Shared procedure A to G, for `README.md`, `installation.md`, `first-dive.md`.
- [ ] **README.md:** fix the navigation description: the app has 16 destinations (`lib/shared/widgets/nav/nav_destinations.dart`, adds Media, Species, Tracks) and Statistics is now Insights; the phone bar's middle slots depend on width. Fold in the tagline "Dive safe. Log everything."
- [ ] **installation.md:** iOS 15 and macOS 12 (`ios/Runner.xcodeproj/project.pbxproj`, `macos/Runner.xcodeproj/project.pbxproj`). Fold from `guide/installation.md`: Linux `.deb` and `.rpm` packages, `install.sh`, udev rules, `uninstall.sh` (`.github/workflows/release.yml`, `scripts/release/`), the glibc 2.38 floor (`.github/workflows/build-all.yml`), optional ffmpeg (`platform_video_transcoder.dart`).
- [ ] **first-dive.md:** rewrite the first-run section for the setup wizard: "Set up a new profile" or "I have existing Submersion data" (restore, cloud sync, folder); steps Profile, Units, Backup, Done, then "Get started" (the `setup_*` strings). Fold in Day Trip for a single dive (`trip_edit_page.dart`).

### Task 7: Logging Your Dives (dashboard, dive-logging, dive-profiles, dive-computer, import-export, data-quality-assistant)

- [ ] Shared procedure A to G, for the six pages.
- [ ] **dive-logging.md:** replace "long-press to select" with **Select items** in the overflow menu (#2775). Fold from `guide/dive-logging.md`: the "Tanks or Equipment?" explanation, **Fill from my cylinders**, registered-transmitter matching (`lib/features/transmitters`), weight names and the `weights[label ~ ...]` search, renumber all dives. Fold from `features/tags.md` a "Tags and dive types" section: 20 tag colours (`TagColors.predefined`), tag merge (`tag_merge_sheet.dart`), 15 built-in dive types (`tag_tables.dart`), custom dive types.
- [ ] **dive-profiles.md:** remove the claim that ascent-rate thresholds are adjustable in Settings. Fold from `features/profile-analysis.md`: the Data Sources comparison grid, hiding a computer hides its temperature, events and pressure curves, Unlink, Export as image. Fold from `features/decompression.md`: compartment half-times 4 to 635 minutes (`buhlmann_coefficients.dart`).
- [ ] **dive-computer.md:** Android supports USB serial. Fold from `guide/dive-computer.md`: the per-platform transport matrix, the support matrix link `https://submersion.app/computers/`, Garmin FIT files, cable and Garmin Connect sign-in (`lib/core/services/garmin_connect`), **Combine** and **Merge as another computer** with Best fit and Align starts.
- [ ] **import-export.md:** DAN DL7 is supported (`dan_dl7_import_parser.dart`), as are Diving Log SQLite and Ratio XML. Fold from `guide/import-export.md`: DAN DL7 including the DiveCloud ZIP, the five-file CSV export with a units choice and header-detected re-import (`parser_registry.dart`), dives placed into trips by date on import, Import from Garmin Device.
- [ ] **dashboard.md, data-quality-assistant.md:** audit only.

### Task 8: Your Dive World (dive-sites, trips, buddies-and-dive-centers, marine-life-and-photos)

- [ ] Shared procedure A to G, for the four pages.
- [ ] **dive-sites.md:** replace long-press selection with **Select items**. Fold from `guide/dive-sites.md`: the map wraps across the 180th meridian, the site Dive Statistics card, tides on site detail with no API key (`lib/features/tides`). Do not carry its OpenWeatherMap or World Tides key steps or difficulty-coloured markers (stale).
- [ ] **trips.md:** the wiki wrongly limits the itinerary and photos to liveaboard trips. Fold from `features/trips.md`: Day Trip locks its end date to the start, every trip type has six tabs (Overview, Itinerary, Gear, Checklist, Dives, Photos), itinerary days Travel, Dive and Rest with planned dives, the countdown and the day-by-day story with day maps.
- [ ] **buddies-and-dive-centers.md:** replace long-press selection. Fold from `features/buddies.md`: Import from Contacts, Capture Instructor Signature.
- [ ] **marine-life-and-photos.md:** the catalog has 685 species (`species.json`), not 511. Fold from `features/marine-life.md`: freshwater species and catalog updates on launch, the Species page (search, sort, Manage catalog), **Look up online** (iNaturalist), **Suggest for the catalog**, species photo tagging. Fold from `features/media-matching.md` a "How photos are matched" section: the time windows, EXIF and video date order, GoPro, the no-capture-date messages, **Choose dive**, **Shift capture times by**. Move `features/marine-life.md`'s maintainer section to a new `docs/developer/species-catalog.md`, linked from `docs/developer/README.md`'s Quick Links.

### Task 9: Diver and Gear (certifications-and-courses, equipment, diver-profile, cylinder-passports)

- [ ] Shared procedure A to G, for the four pages.
- [ ] **equipment.md:** the button is **Use Set**, not "Apply set". Fold from `guide/equipment.md`: cylinders on a dive and **Fill from my cylinders** (cross-link `dive-logging.md`), a Tank item in a set links as equipment only.
- [ ] **cylinder-passports.md (new):** what a passport holds, writing and scanning QR and NFC tags, the `https://submersion.app/c` landing page, and a link to the format spec on GitHub (`https://github.com/submersion-app/submersion/blob/main/docs/developer/reference/formats/cylinder-passport-tag.md`). Sources: `lib/features/cylinder_passports/`, the format spec, and `git show "$OLD":docs/user/README.md`. Add it to `_sidebar.md` under Diver and Gear in this PR.
- [ ] **certifications-and-courses.md, diver-profile.md:** audit only.

### Task 10: Insights and Planning (statistics, planning, weight-planner, safety)

- [ ] Shared procedure A to G, for the four pages.
- [ ] **statistics.md:** Insights takes the dive filter, with the dive-count bar (`insights_filter_bar.dart`); add the Dive focus and Observations pages. Do not carry `guide/insights.md`'s statistics PDF/CSV export or pinch-and-pan claims (stale).
- [ ] **planning.md, weight-planner.md, safety.md:** audit only.

### Task 11: Setup and Data (settings, update-channels, backup-and-restore, multi-device-sync, media-sync, encrypted-sync, debug-mode)

- [ ] Shared procedure A to G, for the seven pages.
- [ ] **settings.md:** fold in ppO2 limits for open circuit, working 1.4 and maximum 1.6 (`settings_providers.dart`). Do not carry `guide/settings.md`'s GF presets, API keys, Google Drive, CNS-warning or ascent-rate settings, or Reset Settings (stale).
- [ ] **multi-device-sync.md:** fold in a "What Syncs Between Devices" section (`lib/core/services/sync/device_local_fields.dart`), the duplicate diver profiles banner and Merge, and the R2 EU and FedRAMP endpoints. Drop any Lightroom bullets (the UI is hidden). Then restore the anchor in `docs/developer/database.md`: `[What Syncs Between Devices](../user/multi-device-sync.md#what-syncs-between-devices)`.
- [ ] **debug-mode.md:** replace the four screenshot alt texts ("Screenshot 2026-05-27 at ...") with descriptions of what each shows.
- [ ] **update-channels.md, backup-and-restore.md, media-sync.md, encrypted-sync.md:** audit only.

### Task 12: Reference (glossary)

- [ ] Shared procedure A to G, for `glossary.md`.
- [ ] Gradient factors start at 15 (the slider minimum), not 10. Fold from `features/oxygen-tracking.md`: the CNS surface half-time of 90 minutes (`o2_exposure.dart`).

---

### Task 13: Final verification

- [ ] **Step 1: All content PRs merged**

```bash
gh pr list --repo submersion-app/submersion --search "Refs #$ISSUE in:body" --state all --json number,title,state --jq '.[] | "\(.number) \(.state) \(.title)"'
```

Expected: PR 1 and the seven content PRs, all `MERGED`.

- [ ] **Step 2: Live checks** (at least five minutes after the last merge)

In the browser pane, on `https://submersion.app/guide/`: the home page renders; the sidebar lists every page including Cylinder Passports; search for "Garmin" returns Dive Computer; an alert callout and a table render on Dive Logging; a cross-page link and a same-page anchor work; the Debug Mode images load; the edit link opens `github.com/submersion-app/submersion/edit/main/docs/user/<page>.md`. Every site page's header and footer link to the guide.

- [ ] **Step 3: Repository checks**

```bash
python3 scripts/check_docs_links.py
bash -c 'cd docs/user; cat *.md | grep -c "&mdash;\|&ndash;"'
```

Expected: the guard passes; `0`.

- [ ] **Step 4: Close the issue**

```bash
gh issue close "$ISSUE" --repo submersion-app/submersion --comment "The user guide now lives in docs/user/ and is published at https://submersion.app/guide/. Every page was audited against the app, and the wiki has been cleared."
```
