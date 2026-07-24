# README Header Minimal Redesign

**Date:** 2026-07-24
**Scope:** `README.md` only — no code changes.

## Problem

The README header (already de-centered) is cluttered: an 80px logo, title,
tagline, a `**Download**` label with five large green `for-the-badge`
platform buttons, a `<sub>License & build status</sub>` label with two flat
badges, and the hero screenshot. The heavy download buttons and label lines
make the header read like a landing page rather than a project README.

## Direction

Minimal & clean header; downloads relocate to a dedicated section.

## Design

### Header (top of README)

```markdown
<img src="assets/icon/icon.png" alt="Submersion logo" width="80">

# Submersion

*Own your dive log. Free and open-source, forever.*

[![License: GPL-3.0](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![CI](https://img.shields.io/github/actions/workflow/status/submersion-app/submersion/ci.yaml?branch=main&label=CI&logo=githubactions&logoColor=white)](https://github.com/submersion-app/submersion/actions/workflows/ci.yaml)

<img src="docs/assets/screenshots/readme/hero.png" alt="Submersion on macOS and iOS" width="900">
```

- Logo stays at 80px above the title.
- One quiet row of the two existing flat badges (License, CI) directly
  under the tagline.
- Removed: the `**Download**` label line, all five `for-the-badge`
  platform buttons, and the `<sub>License &amp; build status</sub>` label.
- Hero image closes the header, unchanged. Everything stays left-aligned.

### New `## Download` section

Inserted immediately after the `## Why Submersion?` section (before
`## Data Philosophy`), so end users reach it before the developer-focused
`## Getting Started`:

```markdown
## Download

- **macOS / Windows / Linux / Android** — [GitHub Releases](https://github.com/submersion-app/submersion/releases)
- **iOS** — [App Store](https://apps.apple.com/us/app/submersion-dive-log/id6757456915)
```

All five destination URLs are preserved exactly from the removed badges
(the four Releases badges all pointed at the same Releases page).

## Out of scope

- Restructuring any other README section.
- The pre-existing markdownlint MD040 warning at line ~352 (fence without
  language) — unrelated to the header.

## Verification

- Preview the rendered README (GitHub or local renderer) to confirm layout.
- Confirm no `for-the-badge` occurrences remain and both new links resolve.
