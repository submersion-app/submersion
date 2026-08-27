# Wiki Documentation Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the Submersion GitHub wiki into a comprehensive, accurate, end-user manual matching the shipping app — 19 content pages + a Glossary + a regrouped sidebar — using GitHub-native markdown, leaving Multi-Device-Sync and Debug-Mode untouched.

**Architecture:** One markdown file per wiki page in the `submersion.wiki` repo, organized by a journey/task-based sidebar. Every page is written **verify-first** (read the cited app code + design specs, then write — code wins over older plans) and declares screenshot "slots" as HTML comments for a later, separate screenshot pipeline to fill. No app code changes.

**Tech Stack:** GitHub-Flavored Markdown (GitHub wiki), GitHub alert callouts (`> [!TIP]`), a small bash page-checker for lint/link verification. Source material: Flutter/Dart app under `submersion/lib/`, plus `submersion/docs/plans/` and `submersion/docs/superpowers/{plans,specs}/`.

**Design spec (source of truth):** `submersion/docs/superpowers/specs/2026-06-15-wiki-docs-redesign-design.md` (on `main`). Read it before starting.

---

## Context, scope & non-goals

- **Where the work happens:** the **wiki repo** at `/Users/ericgriffin/repos/submersion-app/submersion.wiki` (currently on `master`). Pages are root-level `Page-Name.md` files; the title derives from the filename (hyphens → spaces); links use page-name targets, e.g. `[Logging Dives](Dive-Logging)`.
- **Where source material lives:** the **app repo** at `/Users/ericgriffin/repos/submersion-app/submersion` (app is currently **v1.5.1+98** — do not hardcode versions; read `pubspec.yaml`/code at write time). IGNORE `submersion/docs/*.md` wiki **mirror** — it is the bad source.
- **In scope:** the 19 content pages, the Glossary, and `_Sidebar.md`.
- **Non-goals:** (1) the **screenshot generation/inclusion pipeline** — separate future spec/plan; here we only leave slot markers. (2) Editing `Multi-Device-Sync.md` and `Debug-Mode.md`. (3) App code changes — if you find a real bug/confusing UX, record it in the running "Issues found" note (Task 23), don't fix it. (4) Localizing the wiki (English only). (5) Pushing the wiki — commits stay local; the user reviews and pushes to publish.

---

## Conventions for every page task

**§A. Page template** (GitHub-native; matches the kept Multi-Device-Sync quality bar):

```markdown
# <Page Title>

<1–2 sentence lead: what this is and why you'd use it.>

> [!NOTE]
> **Where to find it:** <accurate nav path — desktop rail vs. mobile bottom bar / More menu>

<!-- screenshot: images/<page-slug>/overview.png — <what it shows> -->

## <Task heading>
1. Step…

> [!TIP]
> <helpful aside>

## <Reference heading>
| Field | What it's for |
|-------|---------------|
| … | … |

## See also
- [Related Page](Related-Page)
```

**§B. Style rules:** sentence-case headings; second person; **lead with the common/recreational path, then document technical depth fully** (no shielding — full depth throughout); metric-first with imperial in parentheses ("18 m (60 ft)"); reference tables for dense field lists; GitHub alerts (`> [!NOTE|TIP|WARNING|IMPORTANT|CAUTION]`) — **never** `<div class="...">`; **no Docsify directives** (`<!-- tabs:start -->`, `?>`, `:::`); define abbreviations on first use and link them to the Glossary; a "See also" footer (2–4 links) on every page.

**§C. Screenshot slots:** mark each intended image with an HTML comment (renders as nothing, so no broken images before the pipeline exists):
`<!-- screenshot: images/<page-slug>/<name>.png — <description> -->`
`<page-slug>` = lowercase hyphenated page name (e.g. `dive-logging`, `buddies-and-dive-centers`). The pipeline later replaces each marker with `![<alt>](images/<page-slug>/<name>.png)`.

**§D. Per-page verification** is done by the checker created in Task 1: from the wiki repo root, run `bash /tmp/check-wiki-page.sh <Page>.md` and resolve every reported issue (no legacy directives; no broken internal links).

**§E. Commits:** one commit per page, in the **wiki repo**, conventional style, **no push**:
```bash
cd /Users/ericgriffin/repos/submersion-app/submersion.wiki
git add <Page>.md
git commit -m "docs(wiki): <message>"
```

**§F. The verify→draft→check→lint→commit rhythm** (every page task uses these five steps):
1. **Verify sources** — read the cited `lib/` code + plans/specs; extract exact field names, labels, flows, formats. Code wins over older plans.
2. **Draft** the page per §A/§B/§C and the task's outline.
3. **Accuracy self-check** — confirm every concrete claim traces to something read in step 1; fix any that don't.
4. **Lint & link-check** — `bash /tmp/check-wiki-page.sh <Page>.md`; fix all findings.
5. **Commit** per §E.

---

## File structure (all pages)

| Page (title) | File | Status |
|---|---|---|
| Home | `Home.md` | rewrite |
| Installation | `Installation.md` | rewrite |
| Your First Dive | `First-Dive.md` | rewrite |
| The Dashboard | `Dashboard.md` | new |
| Logging Dives | `Dive-Logging.md` | rewrite |
| Dive Profiles & Deco | `Dive-Profiles.md` | new |
| Dive Computers | `Dive-Computer.md` | rewrite |
| Import & Export | `Import-Export.md` | rewrite |
| Dive Sites | `Dive-Sites.md` | rewrite |
| Trips | `Trips.md` | new |
| Buddies & Dive Centers | `Buddies-and-Dive-Centers.md` | new |
| Marine Life & Photos | `Marine-Life-and-Photos.md` | new |
| Certifications & Courses | `Certifications-and-Courses.md` | new |
| Equipment | `Equipment.md` | rewrite |
| Diver Profile & Multi-Diver | `Diver-Profile.md` | new |
| Statistics & Records | `Statistics.md` | rewrite |
| Planning & Calculators | `Planning.md` | new |
| Settings | `Settings.md` | rewrite |
| Backup & Restore | `Backup-and-Restore.md` | new |
| Glossary | `Glossary.md` | new |
| Sidebar | `_Sidebar.md` | modify |
| Multi-Device Sync | `Multi-Device-Sync.md` | **untouched** |
| Debug Mode | `Debug-Mode.md` | **untouched** |

---

## Phase 0 — Foundation

### Task 1: Page-checker + regrouped sidebar

**Files:**
- Create: `/tmp/check-wiki-page.sh`
- Modify: `/Users/ericgriffin/repos/submersion-app/submersion.wiki/_Sidebar.md`

- [ ] **Step 1: Create the page checker**

Write `/tmp/check-wiki-page.sh`:

```bash
#!/usr/bin/env bash
# Usage: run from the wiki repo root:  bash /tmp/check-wiki-page.sh <Page>.md
set -u
f="$1"
echo "== checking $f =="
echo "-- legacy Docsify/HTML directives (expect: ok):"
if grep -nE '<!-- *tabs:|tabs:end|<div class=|^\?>|^:::' "$f"; then echo "  !! remove the above legacy directives"; else echo "  ok"; fi
echo "-- broken internal wiki links (expect: none):"
grep -oE '\]\([A-Za-z0-9._#-]+\)' "$f" | sed -E 's/^\]\(|\)$//g; s/#.*$//' | grep -v '^$' | sort -u | while read -r t; do [ -f "$t.md" ] || echo "  BROKEN -> $t"; done
echo "-- markdownlint (optional):"
if command -v markdownlint >/dev/null 2>&1; then markdownlint "$f" || true; else echo "  (not installed — skipping)"; fi
echo "== done =="
```

- [ ] **Step 2: Replace the sidebar** with the grouped structure (links to pages created later will resolve as the plan proceeds; Task 23 verifies all of them):

Overwrite `_Sidebar.md` with exactly:

```markdown
**Getting Started**
- [Home](Home)
- [Installation](Installation)
- [Your First Dive](First-Dive)

**Logging Your Dives**
- [The Dashboard](Dashboard)
- [Logging Dives](Dive-Logging)
- [Dive Profiles & Deco](Dive-Profiles)
- [Dive Computers](Dive-Computer)
- [Import & Export](Import-Export)

**Your Dive World**
- [Dive Sites](Dive-Sites)
- [Trips](Trips)
- [Buddies & Dive Centers](Buddies-and-Dive-Centers)
- [Marine Life & Photos](Marine-Life-and-Photos)

**Diver & Gear**
- [Certifications & Courses](Certifications-and-Courses)
- [Equipment](Equipment)
- [Diver Profile & Multi-Diver](Diver-Profile)

**Insights & Planning**
- [Statistics & Records](Statistics)
- [Planning & Calculators](Planning)

**Setup & Data**
- [Settings](Settings)
- [Backup & Restore](Backup-and-Restore)
- [Multi-Device Sync](Multi-Device-Sync)
- [Debug Mode](Debug-Mode)

**Reference**
- [Glossary](Glossary)
```

- [ ] **Step 3: Commit** (the sidebar only; the checker is a /tmp tool, not committed):

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion.wiki
git add _Sidebar.md
git commit -m "docs(wiki): regroup sidebar by user journey"
```

---

## Phase 1 — Getting Started

### Task 2: Home (`Home.md`, rewrite)

**Files:** Modify `Home.md` · Read: `submersion/README.md`, `submersion/docs/superpowers/specs/2026-06-13-readme-redesign-design.md`, `submersion/lib/shared/widgets/main_scaffold.dart`, `submersion/lib/shared/widgets/nav/nav_primary_provider.dart`.

**Outline:** lead (what Submersion is — free/open-source, local-first data ownership, no account) → "the app at a glance" (the Dashboard + the destination groups) → **accurate navigation model** (desktop/tablet ≥800px = 13-item rail; mobile = customizable 5-slot bottom bar [Home + 3 + More]) → "start here" links (Installation, Your First Dive) → help/links (GitHub issues, repo).

**Must-fix vs current:** delete the wrong "five main tabs: Dives, Sites, Gear, Stats, Settings" table; "Home" = the **Dashboard**.

**Screenshot slots:** `<!-- screenshot: images/home/dashboard-hero.png — the Dashboard on first open -->`

- [ ] **Step 1: Verify sources** (§F.1) — confirm the nav model and positioning from the files above.
- [ ] **Step 2: Draft** `Home.md` per the outline, §A/§B.
- [ ] **Step 3: Accuracy self-check** (§F.3).
- [ ] **Step 4: Lint & link-check** — `cd /Users/ericgriffin/repos/submersion-app/submersion.wiki && bash /tmp/check-wiki-page.sh Home.md`; fix findings.
- [ ] **Step 5: Commit** — `git add Home.md && git commit -m "docs(wiki): rewrite Home with accurate navigation model"`

### Task 3: Installation (`Installation.md`, rewrite)

**Files:** Modify `Installation.md` · Read: `submersion/README.md`; plans `2026-02-12-github-releases-*`, `2026-02-14-auto-update-*`, `2026-02-13-macos-release-automation-*`, `2026-03-02-windows-installer-*`, `2026-03-06-google-play-store-*`, `2026-03-03-check-for-updates-menu*`.

**Outline:** lead → install per platform: **iOS** (App Store), **Android** (Google Play), **macOS / Windows / Linux** (GitHub Releases; how auto-update works; macOS Gatekeeper & Windows installer notes) → updating the app (in-app "Check for Updates") → "Build from source?" → one short paragraph linking the repo `README`/`CONTRIBUTING`.

**Must-fix vs current:** demote build-from-source from the main flow to a pointer; **remove Docsify `<!-- tabs -->`**; verify current platform minimums against the repo rather than copying old numbers.

**Screenshot slots:** `<!-- screenshot: images/installation/check-for-updates.png — desktop Check for Updates dialog -->`

- [ ] **Step 1: Verify sources** (§F.1).
- [ ] **Step 2: Draft** per outline, §A/§B (use `###` headings per platform, not tabs).
- [ ] **Step 3: Accuracy self-check** (§F.3).
- [ ] **Step 4: Lint & link-check** — `cd /Users/ericgriffin/repos/submersion-app/submersion.wiki && bash /tmp/check-wiki-page.sh Installation.md`; fix findings.
- [ ] **Step 5: Commit** — `git add Installation.md && git commit -m "docs(wiki): rewrite Installation for end users (stores + releases + auto-update)"`

### Task 4: Your First Dive (`First-Dive.md`, rewrite)

**Files:** Modify `First-Dive.md` · Read: `submersion/lib/features/onboarding/presentation/pages/welcome_page.dart`, `submersion/docs/superpowers/plans/2026-06-11-edit-form-redesign.md`, `submersion/lib/features/dive_log/presentation/`.

**Outline:** 5-minute quickstart — create your profile (**name only** → "Get Started") → you land on the **Dives** list → add a dive (the redesigned edit form) → fill the essentials (date/time, max depth, duration, site) → save → "what's next" links (Logging Dives, Dive Sites, Equipment, Dive Computers).

**Must-fix vs current:** onboarding is **name-only** (not name + email + phone); correct the add-dive entry point and form to the redesigned form; keep a one-line multi-diver pointer to Diver Profile.

**Screenshot slots:** `<!-- screenshot: images/first-dive/welcome.png — name-only welcome screen -->` and `<!-- screenshot: images/first-dive/new-dive-essentials.png — new dive form, essential fields -->`

- [ ] **Step 1: Verify sources** (§F.1) — especially confirm onboarding fields and the post-onboarding destination.
- [ ] **Step 2: Draft** per outline, §A/§B.
- [ ] **Step 3: Accuracy self-check** (§F.3).
- [ ] **Step 4: Lint & link-check** — `cd /Users/ericgriffin/repos/submersion-app/submersion.wiki && bash /tmp/check-wiki-page.sh First-Dive.md`; fix findings.
- [ ] **Step 5: Commit** — `git add First-Dive.md && git commit -m "docs(wiki): rewrite First Dive to match real onboarding + edit form"`

---

## Phase 2 — Logging Your Dives

### Task 5: The Dashboard (`Dashboard.md`, new)

**Files:** Create `Dashboard.md` · Read: `submersion/lib/features/dashboard/`, plan `2026-04-02-dashboard-revamp.md`.

**Outline:** lead → where to find it (Home/rail position 0; mobile first tab) → what the Dashboard shows (at-a-glance stats, recent activity, quick actions) → the cards/widgets → empty-state guidance for new users → how it fills in as you log dives.

**Screenshot slots:** `<!-- screenshot: images/dashboard/overview.png — populated dashboard -->`, `<!-- screenshot: images/dashboard/empty-state.png — first-run empty dashboard -->`

- [ ] **Step 1: Verify sources** (§F.1) — enumerate the real widgets/cards.
- [ ] **Step 2: Draft** per outline, §A/§B.
- [ ] **Step 3: Accuracy self-check** (§F.3).
- [ ] **Step 4: Lint & link-check** — `cd /Users/ericgriffin/repos/submersion-app/submersion.wiki && bash /tmp/check-wiki-page.sh Dashboard.md`; fix findings.
- [ ] **Step 5: Commit** — `git add Dashboard.md && git commit -m "docs(wiki): add The Dashboard page"`

### Task 6: Logging Dives (`Dive-Logging.md`, rewrite)

**Files:** Modify `Dive-Logging.md` · Read: `submersion/lib/features/dive_log/`; plans `2026-06-11-edit-form-redesign`, `2026-02-13-dive-custom-fields-*`, `2026-03-13-weather-conditions`, `2026-03-19-dive-number-*`, `2026-03-18-default-tank-preset`, `2026-03-27-duration-bottomtime-rename-sac-fix`, `2026-02-04-wearable-integration-*`, `2026-03-21-list-view-modes-all-features`, `2026-04-04-table-view-customizable-columns`.

**Outline (full depth):** lead → creating/editing a dive (redesigned form) → basic info & auto dive-numbering → depth/duration, bottom time vs runtime → location & site auto-match → conditions & weather → **tanks & gas** (multi-tank, presets, nitrox/trimix O2/He) → people (buddies + DM, roles) → equipment & weights → tags/rating/favorite/notes → **custom fields** → marine-life sightings (brief; link Marine Life & Photos) → **technical:** dive mode (OC/CCR/SCR), gradient factors, surface interval, CNS/OTU, altitude → **CCR/SCR fields** (setpoints, diluent, scrubber, loop O2) → wearable-sourced dives → dive list views (table/card), sort/filter/search, bulk operations. → See also: Dive Profiles & Deco, Dive Computers, Import & Export.

**Must-fix vs current:** align field set & layout to the redesigned form; correct duration/bottom-time/SAC terminology; verify tank "role"/material enums against code.

**Screenshot slots:** `<!-- screenshot: images/dive-logging/entry-form.png — dive entry form -->`, `<!-- screenshot: images/dive-logging/tanks-gas.png — tanks & gas section -->`, `<!-- screenshot: images/dive-logging/dive-list-table.png — dive list, table view -->`, `<!-- screenshot: images/dive-logging/dive-detail.png — dive detail page -->`

- [ ] **Step 1: Verify sources** (§F.1) — extract the real field set and enums from the dive entity + edit form.
- [ ] **Step 2: Draft** per outline, §A/§B; preserve the strong reference-table style for field lists.
- [ ] **Step 3: Accuracy self-check** (§F.3).
- [ ] **Step 4: Lint & link-check** — `cd /Users/ericgriffin/repos/submersion-app/submersion.wiki && bash /tmp/check-wiki-page.sh Dive-Logging.md`; fix findings.
- [ ] **Step 5: Commit** — `git add Dive-Logging.md && git commit -m "docs(wiki): rewrite Logging Dives for the redesigned form (full depth)"`

### Task 7: Dive Profiles & Deco (`Dive-Profiles.md`, new)

**Files:** Create `Dive-Profiles.md` · Read: `submersion/lib/core/deco/`, `submersion/lib/features/dive_log/presentation/` (profile widgets); plans `2026-03-09-chart-options-redesign`, `2026-02-23-cns-otu-profile-curves`, `2026-02-28-tissue-heatmap-visualization`, `2026-02-23-gradient-factors-dive-events`, `2026-05-25-gas-timeline-default-visibility`, `2026-03-01-otu-stacked-bars`, `2026-02-16-profile-editing`, `2026-04-08-synchronized-profile-tracking`.

**Outline (full depth):** lead → reading the profile (depth curve, zoom/pan, touch markers) → overlays (temp, tank pressure, SAC, heart rate, ascent rate, ceiling/NDL/TTS, ppO2, CNS, OTU) → event markers (gas switches, deco/ascent violations, bookmarks) → **Bühlmann ZH-L16C** + gradient factors → tissue-loading heatmap/bars → multiple profiles (multi-computer) & primary-profile selection → editing a profile. → See also: Logging Dives, Planning & Calculators.

**Screenshot slots:** `<!-- screenshot: images/dive-profiles/profile-overlays.png — profile with overlays -->`, `<!-- screenshot: images/dive-profiles/tissue-heatmap.png — tissue loading heatmap -->`, `<!-- screenshot: images/dive-profiles/profile-events.png — event markers -->`

- [ ] **Step 1: Verify sources** (§F.1) — list the actual overlays/metrics and event types from code.
- [ ] **Step 2: Draft** per outline, §A/§B; define each abbreviation on first use (link Glossary).
- [ ] **Step 3: Accuracy self-check** (§F.3).
- [ ] **Step 4: Lint & link-check** — `cd /Users/ericgriffin/repos/submersion-app/submersion.wiki && bash /tmp/check-wiki-page.sh Dive-Profiles.md`; fix findings.
- [ ] **Step 5: Commit** — `git add Dive-Profiles.md && git commit -m "docs(wiki): add Dive Profiles & Deco page"`

### Task 8: Dive Computers (`Dive-Computer.md`, rewrite)

**Files:** Modify `Dive-Computer.md` · Read: `submersion/lib/features/dive_computer/`, `submersion/packages/libdivecomputer_plugin/`, `submersion/lib/core/router/app_router.dart` (entry path); plans `2026-02-18-libdivecomputer-platform-channels`, `2026-03-12-incremental-dive-download`, `2026-03-11-ble-pin-code-auth`, `2026-03-19-multi-computer-dive-consolidation`, `2026-03-03-linked-dive-computer`, `2026-05-22-shearwater-swift-gps-entry-exit`, `2026-03-07-download-navigation-guard`, `2026-04-11-per-diver-computer-records`.

**Outline:** lead → **where to find it** (verify the real entry path — via Transfer/Import vs. a dedicated screen) → supported brands/protocols (libdivecomputer; BLE / Bluetooth-classic / USB) → discover & pair (incl. BLE PIN) → download (incremental vs full; navigation guard during download) → duplicate detection & site auto-match → multi-computer consolidation & per-diver records → Shearwater Swift GPS entry/exit. → See also: Logging Dives, Import & Export.

**Must-fix vs current:** confirm the access path and exact flow against the router/UI.

**Screenshot slots:** `<!-- screenshot: images/dive-computer/discover.png — device discovery -->`, `<!-- screenshot: images/dive-computer/download-progress.png — download in progress -->`

- [ ] **Step 1: Verify sources** (§F.1) — confirm entry path + protocols.
- [ ] **Step 2: Draft** per outline, §A/§B.
- [ ] **Step 3: Accuracy self-check** (§F.3).
- [ ] **Step 4: Lint & link-check** — `cd /Users/ericgriffin/repos/submersion-app/submersion.wiki && bash /tmp/check-wiki-page.sh Dive-Computer.md`; fix findings.
- [ ] **Step 5: Commit** — `git add Dive-Computer.md && git commit -m "docs(wiki): rewrite Dive Computers (protocols, pairing, download)"`

### Task 9: Import & Export (`Import-Export.md`, rewrite)

**Files:** Modify `Import-Export.md` · Read: `submersion/lib/features/transfer/`, `submersion/lib/features/universal_import/`, `submersion/lib/features/import_wizard/`; plans `2026-03-23-unified-import-wizard`, `2026-03-24-single-import-entry-point`, `2026-03-29-csv-import-rearchitect`, `2026-03-15-subsurface-xml-import`, `2026-04-21-macdive-*`, `2026-03-27-shearwater-cloud-import`, `2026-04-02-drag-drop-file-import`, `2026-02-02-pdf-templates`, `2026-02-03-excel-kml-export`, `2026-04-13-reimport-all-dives`, `2026-03-26-import-tag-selector`.

**Outline:** lead (the Transfer hub) → **import** via the unified wizard (verify the live format list: UDDF, Subsurface XML/SSRF, MacDive XML & SQLite, CSV w/ field mapping, Garmin FIT, Shearwater Cloud, Apple Watch/HealthKit, dive computer) → drag-and-drop file import → duplicate handling & import tags → **export** (UDDF, CSV, Excel, PDF logbook templates, KML) → re-import all dives. → See also: Dive Computers, Logging Dives, Multi-Device Sync, Backup & Restore.

**Must-fix vs current:** replace the stale format list with the **verified** current one; reflect the single import entry point/wizard.

**Screenshot slots:** `<!-- screenshot: images/import-export/import-wizard.png — import wizard -->`, `<!-- screenshot: images/import-export/export-options.png — export format options -->`

- [ ] **Step 1: Verify sources** (§F.1) — enumerate actual import/export formats from the parsers/adapters.
- [ ] **Step 2: Draft** per outline, §A/§B.
- [ ] **Step 3: Accuracy self-check** (§F.3).
- [ ] **Step 4: Lint & link-check** — `cd /Users/ericgriffin/repos/submersion-app/submersion.wiki && bash /tmp/check-wiki-page.sh Import-Export.md`; fix findings.
- [ ] **Step 5: Commit** — `git add Import-Export.md && git commit -m "docs(wiki): rewrite Import & Export with verified formats + wizard"`

---

## Phase 3 — Your Dive World

### Task 10: Dive Sites (`Dive-Sites.md`, rewrite)

**Files:** Modify `Dive-Sites.md` · Read: `submersion/lib/features/dive_sites/`; plans `2026-01-31-maps-visualization`, `2026-02-01-map-list-split-pane`, `2026-02-01-map-view-toggle-implementation`, `2026-05-26-gps-site-matching`, `2026-05-26-site-match-review-map-confirm`, `2026-05-30-site-field-autocomplete`, `2026-05-25-surface-gps-interactive-map`, `2026-05-30-heatmap-density-shader`.

**Outline:** lead → adding a site (manual, GPS capture, reverse-geocoded country/region, field autocomplete) → fields (depth range, difficulty, hazards, access, mooring, altitude, rating) → the **map** (clustering, offline tiles, density heatmap) → map/list split-pane & view toggle → importing sites → merging duplicates → GPS auto-matching of dives to sites (sensitivity). → See also: Logging Dives, Trips, Statistics & Records.

**Must-fix vs current:** add map features, matching, split-pane, autocomplete.

**Screenshot slots:** `<!-- screenshot: images/dive-sites/site-map.png — clustered site map -->`, `<!-- screenshot: images/dive-sites/site-detail.png — site detail -->`, `<!-- screenshot: images/dive-sites/site-list.png — site list -->`

- [ ] **Step 1: Verify sources** (§F.1).
- [ ] **Step 2: Draft** per outline, §A/§B.
- [ ] **Step 3: Accuracy self-check** (§F.3).
- [ ] **Step 4: Lint & link-check** — `cd /Users/ericgriffin/repos/submersion-app/submersion.wiki && bash /tmp/check-wiki-page.sh Dive-Sites.md`; fix findings.
- [ ] **Step 5: Commit** — `git add Dive-Sites.md && git commit -m "docs(wiki): rewrite Dive Sites (maps, matching, split-pane)"`

### Task 11: Trips (`Trips.md`, new)

**Files:** Create `Trips.md` · Read: `submersion/lib/features/trips/`; plans `2026-03-01-liveaboard-tracking`, `2026-01-26-trip-photo-galleries`, `2026-03-04-trip-auto-add-dives`, `2026-04-19-shared-sites-trips`.

**Outline:** lead → where to find it → creating a trip (types: shore, day trip, resort, liveaboard) → auto-adding dives by date → liveaboard details (vessel, operator, cabin, embark/disembark ports, itinerary days) → the trip **photo gallery** → trip stats. → See also: Dive Sites, Marine Life & Photos, Statistics & Records.

**Screenshot slots:** `<!-- screenshot: images/trips/trip-detail.png — trip detail -->`, `<!-- screenshot: images/trips/trip-gallery.png — trip photo gallery -->`

- [ ] **Step 1: Verify sources** (§F.1) — confirm trip types + liveaboard fields.
- [ ] **Step 2: Draft** per outline, §A/§B.
- [ ] **Step 3: Accuracy self-check** (§F.3).
- [ ] **Step 4: Lint & link-check** — `cd /Users/ericgriffin/repos/submersion-app/submersion.wiki && bash /tmp/check-wiki-page.sh Trips.md`; fix findings.
- [ ] **Step 5: Commit** — `git add Trips.md && git commit -m "docs(wiki): add Trips page"`

### Task 12: Buddies & Dive Centers (`Buddies-and-Dive-Centers.md`, new)

**Files:** Create `Buddies-and-Dive-Centers.md` · Read: `submersion/lib/features/buddies/`, `submersion/lib/features/dive_centers/`; plans `2026-03-22-buddy-merge`, `2026-01-31-buddy-signatures`.

**Outline:** lead → **Buddies** (add; contact & cert info; per-dive roles: Buddy/Guide/Instructor/Student/Divemaster/Solo; merge duplicates; buddy signatures on training dives) → **Dive Centers** (add operators/shops; map; import; link to dives) → how each surfaces in stats. → See also: Logging Dives, Certifications & Courses, Statistics & Records.

**Screenshot slots:** `<!-- screenshot: images/buddies-and-dive-centers/buddy-detail.png — buddy detail -->`, `<!-- screenshot: images/buddies-and-dive-centers/dive-center-detail.png — dive center detail -->`

- [ ] **Step 1: Verify sources** (§F.1) — confirm buddy role enum + dive-center fields.
- [ ] **Step 2: Draft** per outline, §A/§B.
- [ ] **Step 3: Accuracy self-check** (§F.3).
- [ ] **Step 4: Lint & link-check** — `cd /Users/ericgriffin/repos/submersion-app/submersion.wiki && bash /tmp/check-wiki-page.sh Buddies-and-Dive-Centers.md`; fix findings.
- [ ] **Step 5: Commit** — `git add Buddies-and-Dive-Centers.md && git commit -m "docs(wiki): add Buddies & Dive Centers page"`

### Task 13: Marine Life & Photos (`Marine-Life-and-Photos.md`, new)

**Files:** Create `Marine-Life-and-Photos.md` · Read: `submersion/lib/features/marine_life/`, media features; plans `2026-01-25-site-marine-life`, `2026-01-25-underwater-photography`, `2026-01-25-photo-picker`, `2026-04-25-media-source-extension-phase1`, `2026-04-27-media-source-extension-phase2`, `2026-04-28-media-source-extension-phase3a/3b/3c`, `2026-02-22-bulk-media-selection`, `2026-03-13-cross-device-photo-resolution`.

**Outline:** lead → **Marine life** (species catalog; log a sighting w/ count & notes; photo annotation/bounding boxes; sightings stats) → **Photos & media** (add from gallery; underwater enrichment of depth/temp/location from the profile; captions; videos; favorites) → **media sources** (network URLs; connectors like Immich/Dropbox; subscriptions) → bulk media selection → cross-device photo resolution (with sync). → See also: Logging Dives, Trips, Statistics & Records.

**Screenshot slots:** `<!-- screenshot: images/marine-life-and-photos/sighting.png — logging a sighting -->`, `<!-- screenshot: images/marine-life-and-photos/photo-enrichment.png — enriched underwater photo -->`, `<!-- screenshot: images/marine-life-and-photos/media-sources.png — media source config -->`

- [ ] **Step 1: Verify sources** (§F.1) — confirm species categories + media-source connectors.
- [ ] **Step 2: Draft** per outline, §A/§B.
- [ ] **Step 3: Accuracy self-check** (§F.3).
- [ ] **Step 4: Lint & link-check** — `cd /Users/ericgriffin/repos/submersion-app/submersion.wiki && bash /tmp/check-wiki-page.sh Marine-Life-and-Photos.md`; fix findings.
- [ ] **Step 5: Commit** — `git add Marine-Life-and-Photos.md && git commit -m "docs(wiki): add Marine Life & Photos page"`

---

## Phase 4 — Diver & Gear

### Task 14: Certifications & Courses (`Certifications-and-Courses.md`, new)

**Files:** Create `Certifications-and-Courses.md` · Read: `submersion/lib/features/certifications/`, `submersion/lib/features/courses/`; plans `2026-02-01-certification-ecards`, `2026-01-25-training-dives`.

**Outline:** lead → **Certifications** (add; agency/level; card number; issue/expiry; instructor; front/back card photos; expiry warnings; the **e-card wallet** & printing) → **Courses** (add a course; training org/instructor; link dives; signatures; earned cert). → See also: Buddies & Dive Centers, Logging Dives, Diver Profile & Multi-Diver.

**Screenshot slots:** `<!-- screenshot: images/certifications-and-courses/cert-wallet.png — certification wallet -->`, `<!-- screenshot: images/certifications-and-courses/course-detail.png — course detail -->`

- [ ] **Step 1: Verify sources** (§F.1) — confirm agencies/levels enums + e-card behavior.
- [ ] **Step 2: Draft** per outline, §A/§B.
- [ ] **Step 3: Accuracy self-check** (§F.3).
- [ ] **Step 4: Lint & link-check** — `cd /Users/ericgriffin/repos/submersion-app/submersion.wiki && bash /tmp/check-wiki-page.sh Certifications-and-Courses.md`; fix findings.
- [ ] **Step 5: Commit** — `git add Certifications-and-Courses.md && git commit -m "docs(wiki): add Certifications & Courses page"`

### Task 15: Equipment (`Equipment.md`, rewrite)

**Files:** Modify `Equipment.md` · Read: `submersion/lib/features/equipment/`; plans `2026-02-02-gear-maintenance-notifications`, `2026-02-27-equipment-sets-visibility`, and the tank-preset plans (`2026-03-18-default-tank-preset`).

**Outline:** lead → add gear (types; brand/model/serial/size/status/purchase) → **service records** & **maintenance reminders** (notifications; custom intervals) → **equipment sets/bags** & quick-select on a dive → **tank presets** → usage stats. → See also: Logging Dives, Settings, Statistics & Records.

**Must-fix vs current:** add service records, reminders, sets, tank presets (verify the type/status enums against code).

**Screenshot slots:** `<!-- screenshot: images/equipment/item-detail.png — equipment item -->`, `<!-- screenshot: images/equipment/service-reminders.png — service reminders -->`, `<!-- screenshot: images/equipment/equipment-sets.png — equipment sets -->`

- [ ] **Step 1: Verify sources** (§F.1).
- [ ] **Step 2: Draft** per outline, §A/§B.
- [ ] **Step 3: Accuracy self-check** (§F.3).
- [ ] **Step 4: Lint & link-check** — `cd /Users/ericgriffin/repos/submersion-app/submersion.wiki && bash /tmp/check-wiki-page.sh Equipment.md`; fix findings.
- [ ] **Step 5: Commit** — `git add Equipment.md && git commit -m "docs(wiki): rewrite Equipment (service, reminders, sets, presets)"`

### Task 16: Diver Profile & Multi-Diver (`Diver-Profile.md`, new)

**Files:** Create `Diver-Profile.md` · Read: `submersion/lib/features/divers/`, `submersion/lib/features/onboarding/`; plan `2026-02-23-diver-profile-settings`.

**Outline:** lead → the diver profile (personal; **emergency contacts**; **medical** info & clearance; **insurance**; notes) → creating/switching multiple divers → what's **per-diver** (logs, sites, gear, settings, units). → See also: Settings, Certifications & Courses, Your First Dive.

**Screenshot slots:** `<!-- screenshot: images/diver-profile/profile.png — diver profile -->`, `<!-- screenshot: images/diver-profile/switch-diver.png — switching divers -->`

- [ ] **Step 1: Verify sources** (§F.1) — confirm profile sub-sections + per-diver scoping.
- [ ] **Step 2: Draft** per outline, §A/§B.
- [ ] **Step 3: Accuracy self-check** (§F.3).
- [ ] **Step 4: Lint & link-check** — `cd /Users/ericgriffin/repos/submersion-app/submersion.wiki && bash /tmp/check-wiki-page.sh Diver-Profile.md`; fix findings.
- [ ] **Step 5: Commit** — `git add Diver-Profile.md && git commit -m "docs(wiki): add Diver Profile & Multi-Diver page"`

---

## Phase 5 — Insights & Planning

### Task 17: Statistics & Records (`Statistics.md`, rewrite)

**Files:** Modify `Statistics.md` · Read: `submersion/lib/features/statistics/`; plans `2026-04-15-statistics-overview`, `2026-02-26-enhanced-range-analysis`, `2026-03-01-cumulative-tissue-otu`.

**Outline:** lead → overview (totals, averages, depth distribution) → the analytics dashboards (gas/SAC, progression, conditions, social, geographic, marine life, time patterns, equipment, profile/deco) → range/date filtering → **Records** (deepest, longest, coldest/warmest, most-in-a-day, etc.) with breakdowns. → See also: Dive Profiles & Deco, Planning & Calculators, Dive Sites.

**Must-fix vs current:** replace the thin stats list with the **verified** real dashboards; fold in Records (confirm its entry path).

**Screenshot slots:** `<!-- screenshot: images/statistics/overview.png — stats overview -->`, `<!-- screenshot: images/statistics/gas-sac.png — gas/SAC dashboard -->`, `<!-- screenshot: images/statistics/records.png — personal records -->`

- [ ] **Step 1: Verify sources** (§F.1) — enumerate the actual stat dashboards + records.
- [ ] **Step 2: Draft** per outline, §A/§B.
- [ ] **Step 3: Accuracy self-check** (§F.3).
- [ ] **Step 4: Lint & link-check** — `cd /Users/ericgriffin/repos/submersion-app/submersion.wiki && bash /tmp/check-wiki-page.sh Statistics.md`; fix findings.
- [ ] **Step 5: Commit** — `git add Statistics.md && git commit -m "docs(wiki): rewrite Statistics & Records with real dashboards"`

### Task 18: Planning & Calculators (`Planning.md`, new)

**Files:** Create `Planning.md` · Read: `submersion/lib/features/planning/` (`dive_planner`, `deco_calculator`, `gas_calculators`, `tools`); plan `2026-02-27-mnd-calculation`.

**Outline (full depth):** lead → **dive planner** (multi-level profiles; gas planning; deco schedules; plan vs. actual) → **deco calculator** (Bühlmann ZH-L16C; GF) → **gas calculators** (nitrox/trimix blending; MOD/END/EAD; best-mix) → **weight calculator** (exposure suit + tank) → **surface-interval** tool. → See also: Dive Profiles & Deco, Logging Dives.

**Screenshot slots:** `<!-- screenshot: images/planning/dive-planner.png — dive planner -->`, `<!-- screenshot: images/planning/gas-calculators.png — gas calculators -->`

- [ ] **Step 1: Verify sources** (§F.1) — confirm which calculators/tools exist + their entry paths.
- [ ] **Step 2: Draft** per outline, §A/§B; define abbreviations (link Glossary).
- [ ] **Step 3: Accuracy self-check** (§F.3).
- [ ] **Step 4: Lint & link-check** — `cd /Users/ericgriffin/repos/submersion-app/submersion.wiki && bash /tmp/check-wiki-page.sh Planning.md`; fix findings.
- [ ] **Step 5: Commit** — `git add Planning.md && git commit -m "docs(wiki): add Planning & Calculators page"`

---

## Phase 6 — Setup & Data

### Task 19: Settings (`Settings.md`, rewrite)

**Files:** Modify `Settings.md` · Read: `submersion/lib/features/settings/`; plans `2026-04-08-appearance-settings-reorganization`, `2026-02-25-app-theme-presets`, `2026-02-17-card-coloring`, `2026-04-20-bottom-nav-customization`, `2026-03-27-dive-detail-section-config`, `2026-04-04-table-view-customizable-columns`, `2026-02-24-tag-management`, `2026-03-17-dive-time-timezone-fix`, `2026-02-23-metric-data-source-switching`, `2026-02-24-platform-parity`.

**Outline (full depth):** lead → units & formats (depth/temp/pressure/volume/weight/altitude/SAC; time & date) → decompression defaults (GF; ppO2 thresholds; CNS warning; ascent-rate thresholds; last-stop/increment) → **appearance** (themes/presets; card coloring; tissue-viz mode; profile-overlay defaults) → **navigation customization** (mobile bottom bar) + **dive-detail section config** + **table columns** → notifications (service reminders; cert expiry) → offline maps → tags & dive types management → media sources → fix-dive-times/timezone; metric data-source switching → cross-links to Backup & Restore and Multi-Device Sync. → See also: Backup & Restore, Multi-Device Sync, Diver Profile & Multi-Diver.

**Must-fix vs current:** replace the stale settings list with the **verified**, reorganized settings (note "Cloud Sync entry now shown on all platforms" per recent change).

**Screenshot slots:** `<!-- screenshot: images/settings/settings-home.png — settings home -->`, `<!-- screenshot: images/settings/units.png — units settings -->`, `<!-- screenshot: images/settings/appearance.png — appearance settings -->`

- [ ] **Step 1: Verify sources** (§F.1) — enumerate the real settings categories.
- [ ] **Step 2: Draft** per outline, §A/§B.
- [ ] **Step 3: Accuracy self-check** (§F.3).
- [ ] **Step 4: Lint & link-check** — `cd /Users/ericgriffin/repos/submersion-app/submersion.wiki && bash /tmp/check-wiki-page.sh Settings.md`; fix findings.
- [ ] **Step 5: Commit** — `git add Settings.md && git commit -m "docs(wiki): rewrite Settings with the real, reorganized options"`

### Task 20: Backup & Restore (`Backup-and-Restore.md`, new)

**Files:** Create `Backup-and-Restore.md` · Read: plans `2026-02-22-file-based-backup-restore`, `2026-06-11-restore-replace-mode`, `2026-04-12-db-backup-before-migration`, `2026-02-27-database-reset`, `2026-06-15-smoother-restore-sync`; settings backup UI under `submersion/lib/features/settings/`.

**Outline:** lead → what a backup contains (full database) → create/export a backup file → restore (incl. **replace** mode) → automatic DB backup before migrations → database reset → how this relates to but differs from **Multi-Device Sync** (backup = point-in-time file; sync = continuous shared library). → See also: Multi-Device Sync, Settings, Import & Export.

**Screenshot slots:** `<!-- screenshot: images/backup-and-restore/backup.png — create backup -->`, `<!-- screenshot: images/backup-and-restore/restore.png — restore with replace mode -->`

- [ ] **Step 1: Verify sources** (§F.1) — confirm backup contents + restore modes.
- [ ] **Step 2: Draft** per outline, §A/§B.
- [ ] **Step 3: Accuracy self-check** (§F.3).
- [ ] **Step 4: Lint & link-check** — `cd /Users/ericgriffin/repos/submersion-app/submersion.wiki && bash /tmp/check-wiki-page.sh Backup-and-Restore.md`; fix findings.
- [ ] **Step 5: Commit** — `git add Backup-and-Restore.md && git commit -m "docs(wiki): add Backup & Restore page"`

---

## Phase 7 — Reference

### Task 21: Glossary (`Glossary.md`, new)

**Files:** Create `Glossary.md` · Read: `submersion/lib/core/deco/` and the technical pages drafted above (for consistent definitions).

**Outline:** short lead → an alphabetical list of diving & app terms/abbreviations, each 1–2 lines, linking to the page that uses it. Include at least: SAC/RMV, NDL, TTS, RBT, GF (gradient factors), CNS, OTU, ppO2, MOD, END, EAD, CCR, SCR, OC, deco, trimix, nitrox/EANx, Bühlmann ZH-L16C, surface interval, ascent rate. → See also: Dive Profiles & Deco, Planning & Calculators, Logging Dives.

- [ ] **Step 1: Verify sources** (§F.1) — make definitions match how the app uses each term.
- [ ] **Step 2: Draft** `Glossary.md` (alphabetical; concise; link terms to their pages).
- [ ] **Step 3: Accuracy self-check** (§F.3).
- [ ] **Step 4: Lint & link-check** — `cd /Users/ericgriffin/repos/submersion-app/submersion.wiki && bash /tmp/check-wiki-page.sh Glossary.md`; fix findings.
- [ ] **Step 5: Commit** — `git add Glossary.md && git commit -m "docs(wiki): add Glossary"`

---

## Phase 8 — Finalize & QA

### Task 22: Cross-link & "See also" pass

**Files:** any page needing link fixes (wiki repo).

- [ ] **Step 1:** Re-read each page's "See also" footer; ensure every page is reachable from at least two others and that related pages cross-reference each other (e.g., Logging Dives ↔ Dive Profiles ↔ Dive Computers ↔ Import & Export; Backup & Restore ↔ Multi-Device Sync).
- [ ] **Step 2:** Add any missing cross-links.
- [ ] **Step 3: Commit** — `cd /Users/ericgriffin/repos/submersion-app/submersion.wiki && git add -A && git commit -m "docs(wiki): tighten cross-links and See also footers"`

### Task 23: Whole-wiki verification

**Files:** none (verification only) — plus a running "Issues found" note for any app bugs/UX surprises discovered while writing (report to the user; do not fix app code).

- [ ] **Step 1: Every page passes the checker.** Run:

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion.wiki
for f in *.md; do bash /tmp/check-wiki-page.sh "$f"; done
```
Expected: every page "ok" for directives and no "BROKEN ->" lines.

- [ ] **Step 2: Sidebar links all resolve.** Run:

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion.wiki
grep -oE '\]\([A-Za-z0-9._-]+\)' _Sidebar.md | sed -E 's/^\]\(|\)$//g' | while read -r t; do [ -f "$t.md" ] || echo "MISSING PAGE -> $t"; done
```
Expected: no output (all 21 linked pages exist).

- [ ] **Step 3: No legacy Docsify syntax anywhere.** Run:

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion.wiki
grep -rnE '<!-- *tabs:|tabs:end|<div class=|^\?>' --include='*.md' . | grep -v -e 'Multi-Device-Sync.md' -e 'Debug-Mode.md' || echo "clean (kept pages excluded)"
```
Expected: "clean" (the two untouched pages may still contain legacy syntax — that's allowed).

- [ ] **Step 4: Confirm kept pages untouched.** Run:

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion.wiki
git log --oneline -1 -- Multi-Device-Sync.md Debug-Mode.md
git status --short Multi-Device-Sync.md Debug-Mode.md
```
Expected: their last commit predates this work; `git status` shows no changes to them.

- [ ] **Step 5:** Summarize for the user: pages written, the "Issues found" note, and the reminder that **screenshots are slot-marked but not yet generated** (the separate pipeline spec) and that **nothing has been pushed** — the wiki publishes only when the user pushes. No commit (reporting step).

---

## Self-review checklist (run before handoff)

- **Spec coverage:** every spec §8 page → a task here (Tasks 2–21); sidebar §5 → Task 1; conventions §6 → §A–§C; screenshot slots §7 → §C; accuracy discipline §10 → §F + per-task Step 1/3; Glossary → Task 21. Kept pages (§3) → Task 23 Step 4.
- **No placeholders:** every task names exact files, the concrete outline, the exact checker/commit commands. Prose is written at execution (the deliverable), guided by per-page outlines + sources — not stubbed here.
- **Consistency:** filenames in the File-structure table match the sidebar (Task 1) and each task's Files line; screenshot slug = lowercase-hyphenated filename throughout.

## Execution notes

- Do the tasks **in order** (Task 1 first — it creates the checker and sidebar). Pages may otherwise be written in any order; links resolve progressively and are confirmed in Task 23.
- One commit per page in the **wiki repo** (`submersion.wiki`), **never pushed** by the worker.
- If a page's reality diverges from this outline, **trust the code** and adjust the page (and note it for the user).
