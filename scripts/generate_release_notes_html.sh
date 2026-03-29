#!/usr/bin/env bash
# Converts markdown release notes to a simple HTML page for Sparkle/WinSparkle.
#
# Usage: ./scripts/generate_release_notes_html.sh < release-notes.md > release-notes.html
#        cat release-notes.md | ./scripts/generate_release_notes_html.sh > release-notes.html
#
# Reads markdown from stdin, writes HTML to stdout.
# Handles ## headings, ### subheadings, and - bullet points.

set -euo pipefail

BODY=$(cat)

# Convert markdown to basic HTML using awk for proper <ul> wrapping
HTML=$(echo "$BODY" | awk '
BEGIN { in_list = 0 }
/^## / { if (in_list) { print "</ul>"; in_list = 0 }; sub(/^## /, ""); print "<h2>" $0 "</h2>"; next }
/^### / { if (in_list) { print "</ul>"; in_list = 0 }; sub(/^### /, ""); print "<h3>" $0 "</h3>"; next }
/^- / { if (!in_list) { print "<ul>"; in_list = 1 }; sub(/^- /, ""); print "  <li>" $0 "</li>"; next }
/^$/ { if (in_list) { print "</ul>"; in_list = 0 }; next }
{ if (in_list) { print "</ul>"; in_list = 0 }; print "<p>" $0 "</p>" }
END { if (in_list) print "</ul>" }
')

cat <<HTML_TEMPLATE
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<style>
  body {
    font-family: -apple-system, "Segoe UI", Roboto, sans-serif;
    margin: 16px;
    font-size: 14px;
    color: #222;
    line-height: 1.5;
  }
  h2 { font-size: 18px; border-bottom: 1px solid #ddd; padding-bottom: 6px; }
  h3 { font-size: 15px; margin-top: 16px; margin-bottom: 4px; }
  ul { padding-left: 24px; margin-top: 4px; }
  li { margin: 3px 0; }
</style>
</head>
<body>
${HTML}
</body>
</html>
HTML_TEMPLATE
