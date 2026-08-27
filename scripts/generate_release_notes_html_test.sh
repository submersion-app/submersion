#!/usr/bin/env bash
# Tests for generate_release_notes_html.sh: markdown conversion and the
# explicit light/dark colour pairs that keep the notes readable inside the
# Sparkle/WinSparkle web views regardless of the OS theme (issue #849).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fail() { echo "FAIL: $1"; exit 1; }

OUT=$(printf '## Heading\n\n### Sub\n\n- one\n- two\n\nplain text\n' \
  | "$SCRIPT_DIR/generate_release_notes_html.sh")

# Markdown conversion basics.
echo "$OUT" | grep -q "<h2>Heading</h2>" || fail "h2 heading not converted"
echo "$OUT" | grep -q "<h3>Sub</h3>" || fail "h3 subheading not converted"
echo "$OUT" | grep -q "<li>one</li>" || fail "bullet not converted to li"
[ "$(echo "$OUT" | grep -c '<ul>')" -eq 1 ] || fail "bullets not wrapped in a single ul"
echo "$OUT" | grep -q "<p>plain text</p>" || fail "plain line not wrapped in p"

# The body must declare text and background colours as a pair. A text colour
# without a background lets the embedded web view paint a theme-dependent
# background, producing near-black text on a dark page (issue #849).
BODY_RULE=$(echo "$OUT" | sed -n '/body {/,/}/p')
echo "$BODY_RULE" | grep -q "color: #222" || fail "body text colour missing"
echo "$BODY_RULE" | grep -q "background-color: #fff" \
  || fail "body background colour missing; dark-mode web views paint #222 text on a dark page"

# The page must opt in to dark mode with a color-scheme declaration (meta tag
# and :root CSS). Some WKWebView versions only match prefers-color-scheme: dark
# when the page declares color-scheme support, and it keeps WebKit's UA
# defaults consistent with the active appearance in Sparkle's web view.
echo "$OUT" | grep -q '<meta name="color-scheme" content="light dark">' \
  || fail "color-scheme meta tag missing; some WKWebViews need it to match the dark media query"
echo "$OUT" | sed -n '/:root {/,/}/p' | grep -q "color-scheme: light dark" \
  || fail ":root color-scheme declaration missing; some WKWebViews need it to match the dark media query"

# Dark mode must be handled explicitly with the inverse pair, plus a visible
# h2 border (the light #ddd border disappears on a dark background).
DARK_RULE=$(echo "$OUT" | sed -n '/@media (prefers-color-scheme: dark)/,/^  }/p')
[ -n "$DARK_RULE" ] || fail "no prefers-color-scheme: dark block"
echo "$DARK_RULE" | grep -q "color: #e8e8e8" || fail "dark-mode text colour missing"
echo "$DARK_RULE" | grep -q "background-color: #1e1e1e" || fail "dark-mode background colour missing"
echo "$OUT" | sed -n '/@media (prefers-color-scheme: dark)/,/^<\/style>/p' \
  | grep -q "border-bottom-color: #444" || fail "dark-mode h2 border colour missing"

echo "PASS: all generate_release_notes_html tests passed"
