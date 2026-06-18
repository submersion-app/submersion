# Wiki Documentation Redesign — Design

**Date:** 2026-06-15
**Status:** Draft for review
**Author:** Eric Griffin (with Claude)
**Scope of this spec:** The content & information-architecture redesign of the Submersion GitHub **wiki** (`submersion.wiki` repo). The screenshot auto-generation/auto-inclusion pipeline is a **separate, follow-on spec** — this spec only defines the screenshot *slot convention* that the pipeline will fill.

---

## 1. Background & problem

Submersion is a free, open-source, cross-platform (iOS, Android, macOS, Windows, Linux) scuba dive-logging app, currently **v1.4.9+96**. Its user-facing documentation lives in the GitHub wiki (`submersion.wiki`), surfaced through `_Sidebar.md` and one markdown file per page.

The wiki is badly out of date — not merely stale wording, but **describing a much smaller, different app** than the one that ships today:

- **Coverage gap.** The wiki documents ~5 areas (Dives, Sites, Gear, Stats, Settings). The shipping app has ~13 primary destinations plus many sub-features. Entire areas have **zero** documentation: Dashboard, Trips, Buddies, Dive Centers, Certifications, Courses, Planning & calculators, Records, Marine Life, Photos/Media, Diver Profile/Multi-diver, Backup & Restore.
- **Factual errors.** Examples: onboarding is described as name + email + phone, but the real onboarding (`lib/features/onboarding/presentation/pages/welcome_page.dart`) is **name only**. "Five main tabs: Dives, Sites, Gear, Stats, Settings" is wrong — the desktop rail has **13** destinations and the first one ("Home") is the **Dashboard**; mobile shows a **customizable 5-slot** bar + a **More** menu (`lib/shared/widgets/main_scaffold.dart`, `lib/shared/widgets/nav/nav_primary_provider.dart`). The dive entry form was **redesigned 2026-06-11**, so the "Dive Logging" page describes an old UI.
- **Rendering bugs.** Pages were authored in **Docsify** syntax (`<!-- tabs:start -->`, `<div class="tip">`, `?>`), which the GitHub wiki does **not** process. Platform "tabs" render as stacked headers; styled callouts render as unstyled text.
- **Not user-friendly.** Installation leads with build-from-source (a developer task) rather than how an end user actually installs the app (App Store / Google Play / GitHub Releases with auto-update).

**Authoritative sources for accurate content** (per the repo owner): the app **source code**, `submersion/docs/plans/` (~100 feature design+implementation docs), and `submersion/docs/superpowers/{plans,specs}/` (~160 more). The `submersion/docs/*.md` wiki **mirror** is itself the bad source and must be ignored.

The two pages **explicitly kept as-is** — `Multi-Device-Sync.md` and `Debug-Mode.md` — are the visible quality bar to match (clear leads, task-oriented sections, callouts, worked examples).

## 2. Goals

1. A **comprehensive, accurate, end-user** manual that matches the app as it ships today, covering every major feature area.
2. A coherent **journey/task-based information architecture** that scales as the app grows.
3. A consistent, **GitHub-native** page template and markdown style, matched to the Multi-Device-Sync quality bar.
4. **Full-depth** coverage of Submersion's technical-diving capabilities, documented inline at equal weight (open each page with the common path, then go all the way down).
5. A **stable screenshot-slot convention** so every page is screenshot-ready and the follow-on pipeline can populate images without touching prose.

## 3. Non-goals

- **Building the screenshot pipeline.** Generation, population, and broken-image-gap handling are the follow-on spec's job. This spec only fixes the *convention*.
- **Editing the two kept pages' content** (`Multi-Device-Sync.md`, `Debug-Mode.md`). An optional callout-only cosmetic pass on just those two may be considered later; not in scope here.
- **The Docsify `docs/` mirror site.** Out of scope; it is the bad source.
- **App code changes.** Docs only. If the rewrite surfaces a real bug or a confusing UX, note it for a separate issue — do not fix it here.
- **Localizing the wiki.** The app ships 10+ locales, but the wiki is **English-only** for now.

## 4. Audience & voice

- **Audience:** end users of the app (recreational through technical divers), not developers. Build-from-source lives in the repo `README`/`CONTRIBUTING`; Installation links there for the few who want it.
- **Voice:** second person ("you"), friendly and concise, task-first. Lead each page with the common/recreational path, then document advanced and technical material fully.
- **Units:** metric-first with imperial in parentheses, e.g. "18 m (60 ft)", "200 bar (~3000 psi)". Note that the app itself honors per-diver unit preferences.
- **Jargon:** define abbreviations on first use per page (SAC, NDL, TTS, GF, CNS, OTU, MOD, END, EAD, CCR, SCR). A dedicated **Glossary** page backs this up (see §9).

## 5. Information architecture

Journey/task grouping (approved). Group headers are organizational only; each bullet is one wiki page.

```
Getting Started
  • Home
  • Installation
  • Your First Dive
Logging Your Dives
  • The Dashboard
  • Logging Dives
  • Dive Profiles & Deco
  • Dive Computers
  • Import & Export
Your Dive World
  • Dive Sites
  • Trips
  • Buddies & Dive Centers
  • Marine Life & Photos
Diver & Gear
  • Certifications & Courses
  • Equipment
  • Diver Profile & Multi-Diver
Insights & Planning
  • Statistics & Records
  • Planning & Calculators
Setup & Data
  • Settings
  • Backup & Restore
  • Multi-Device Sync   (kept as-is)
  • Debug Mode          (kept as-is)
Reference
  • Glossary
```

### `_Sidebar.md`

GitHub wiki sidebars are plain markdown (no native collapsible groups), so groups are rendered as **bold labels + bullet lists**:

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

## 6. Page template & markdown conventions

Every new/rewritten page follows this GitHub-native skeleton:

```markdown
# <Page Title>

<1–2 sentence lead: what this is and why you'd use it.>

> [!NOTE]
> **Where to find it:** <how to reach it in the app, e.g. bottom nav → More → Trips, or rail → Trips>

![<screen> overview](images/<page-slug>/overview.png)

## <Task heading, e.g. "Creating a trip">
1. Step…
2. Step…

> [!TIP]
> <helpful aside>

## <Reference heading, e.g. "Trip fields">
| Field | What it's for |
|-------|---------------|
| … | … |

## See also
- [Related Page](Related-Page)
```

**Conventions**

- **GitHub alerts** (`> [!NOTE]`, `> [!TIP]`, `> [!WARNING]`, `> [!IMPORTANT]`, `> [!CAUTION]`) instead of `<div class="tip">`. Render as styled callouts on the wiki.
- **No Docsify directives** (`<!-- tabs:start -->`, `?>`, `:::`). For per-platform instructions, use clear `###` headings or tables, not tabs.
- **Sentence-case headings.**
- **Reference tables** for dense field/option lists (the current Dive-Logging tables are a good model — preserve that strength).
- **`> [!NOTE] Where to find it`** breadcrumb near the top of every feature page, accurate to the real nav (desktop rail vs. mobile bottom bar/More).
- **"See also"** footer on every page with 2–4 cross-links.
- **Wiki links** use page-name targets: `[Logging Dives](Dive-Logging)`.
- **Internal anchors** for deep links where a page is long (GitHub auto-generates heading anchors).

## 7. Screenshot slot convention (handoff to the pipeline spec)

- Images are committed to the **wiki repo** under `images/<page-slug>/<descriptive-name>.png` and referenced by that **stable relative path** with descriptive alt text:
  `![Dive entry form](images/dive-logging/entry-form.png)`
- `<page-slug>` is the lowercase, hyphenated page name (e.g. `dive-logging`, `dive-profiles`, `buddies-and-dive-centers`).
- Each page in §8 **declares the exact shots it wants** by name. Prose is written to reference those paths now, even before the images exist.
- **Decisions deferred to the pipeline spec:** how shots are generated (the existing `integration_test/screenshots_test.dart` harness + UDDF fixture + `scripts/release/capture_screenshots.sh` cover ~8 screens today), how/where they're committed cross-repo, how often they refresh, and **how we avoid broken-image gaps at publish time** (e.g. stage prose without image refs until shots land, seed an initial set from the existing harness/manual captures, or use placeholders). Per-locale screenshots are out of scope (English-only).

> The two efforts stay decoupled through this convention: pages can be written and merged referencing images that don't exist yet; the pipeline fills them later without prose edits.

## 8. Per-page plan

Format per page: **Title** (`Filename.md`, *new* | *rewrite*) — purpose; outline; (rewrites) key fixes vs. current; screenshots; primary sources. Outlines are intentionally high-level; the implementation plan (next step) expands each into tasks, and **every factual claim must be verified against code/specs at write time** (§10).

### Getting Started

1. **Home** (`Home.md`, *rewrite*) — Landing page; what Submersion is (data-ownership/open-source positioning, aligned with the redesigned README), and a guided map into the sections. Outline: value prop → "the app at a glance" (Dashboard + the destination groups) → "start here" links (Installation, First Dive) → help/links. Fixes: replace the wrong "five tabs" table with the real navigation model (Home/Dashboard + groups; desktop rail vs. mobile 5-slot bar + More). Screenshots: `images/home/dashboard-hero.png`. Sources: `README.md`, `docs/superpowers/specs/2026-06-13-readme-redesign-design.md`, `lib/shared/widgets/main_scaffold.dart`.

2. **Installation** (`Installation.md`, *rewrite*) — How an **end user** installs and updates on each platform. Outline: iOS (App Store), Android (Google Play), macOS/Windows/Linux (GitHub Releases + how auto-update works; macOS Gatekeeper/Windows installer notes) → updating the app → "build from source?" pointer to the repo README. Fixes: demote build-from-source; remove Docsify tabs; correct platform minimums. Screenshots: `images/installation/releases-page.png` (optional). Sources: `docs/plans/2026-02-12-github-releases-*`, `2026-02-14-auto-update-*`, `2026-02-13-macos-release-automation-*`, `2026-03-02-windows-installer-*`, `2026-03-06-google-play-store-*`, `2026-03-03-check-for-updates-menu*`, `README.md`.

3. **Your First Dive** (`First-Dive.md`, *rewrite*) — 5-minute quickstart. Outline: create your (name-only) profile → land on Dives → tap **+** to add a dive → fill the essentials (date/time, max depth, duration, site) → save → "what's next" links. Fixes: onboarding is **name only**; correct the add-dive entry point and form to the redesigned edit form; keep the "multi-diver" pointer but move detail to Diver Profile. Screenshots: `images/first-dive/welcome.png`, `images/first-dive/new-dive-essentials.png`. Sources: `lib/features/onboarding/.../welcome_page.dart`, `docs/superpowers/plans/2026-06-11-edit-form-redesign.md`.

### Logging Your Dives

4. **The Dashboard** (`Dashboard.md`, *new*) — The home screen: at-a-glance stats, recent activity, quick actions, empty-state guidance for new users. Outline: what the Dashboard shows → cards/widgets → quick actions → how it changes as you log dives. Screenshots: `images/dashboard/overview.png`, `images/dashboard/empty-state.png`. Sources: `lib/features/dashboard/`, `docs/superpowers/plans/2026-04-02-dashboard-revamp.md`.

5. **Logging Dives** (`Dive-Logging.md`, *rewrite*) — The dive entry form end-to-end, **full depth**. Outline: creating/editing a dive (redesigned form) → basic info & auto dive-numbering → depth/duration & bottom-time vs runtime → location & site auto-match → conditions & weather → **tanks & gas** (multi-tank, presets, nitrox/trimix) → people (buddies/DM roles) → equipment & weights → tags/rating/favorite/notes → **custom fields** → marine-life sightings → **technical**: dive mode (OC/CCR/SCR), GF, surface interval, CNS/OTU, altitude → **CCR/SCR** fields (setpoints, diluent, scrubber, loop O2) → wearable-sourced dives → dive list views (table/card), sorting/filtering/search, bulk ops. Fixes: align field set & form layout to the redesigned form; correct duration/bottom-time/SAC terminology. Screenshots: `images/dive-logging/entry-form.png`, `tanks-gas.png`, `dive-list-table.png`, `dive-detail.png`. Sources: `lib/features/dive_log/`, plans `2026-06-11-edit-form-redesign`, `2026-02-13-dive-custom-fields-*`, `2026-03-13-weather-conditions`, `2026-03-19-dive-number-*`, `2026-03-18-default-tank-preset`, `2026-03-27-duration-bottomtime-rename-sac-fix`, `2026-02-04-wearable-integration-*`, `2026-03-21-list-view-modes-all-features`, `2026-04-04-table-view-customizable-columns`.

6. **Dive Profiles & Deco** (`Dive-Profiles.md`, *new*) — The dive profile chart and decompression visualization, **full depth**. Outline: reading the profile (depth curve, zoom/pan, touch markers) → overlays (temp, tank pressure, SAC, heart rate, ascent rate, ceiling/NDL/TTS, ppO2, CNS, OTU) → event markers (gas switches, deco/ascent violations, bookmarks) → **Bühlmann ZH-L16C** model, gradient factors → tissue-loading heatmap/bars → multi-profile (multiple computers) & primary-profile selection → editing a profile. Screenshots: `images/dive-profiles/profile-overlays.png`, `tissue-heatmap.png`, `profile-events.png`. Sources: `lib/core/deco/`, `lib/features/dive_log/presentation/` (profile), plans `2026-03-09-chart-options-redesign`, `2026-02-23-cns-otu-profile-curves`, `2026-02-28-tissue-heatmap-visualization`, `2026-02-23-gradient-factors-dive-events`, `2026-05-25-gas-timeline-default-visibility`, `2026-03-01-otu-stacked-bars`, `2026-02-16-profile-editing`, `2026-04-08-synchronized-profile-tracking`.

7. **Dive Computers** (`Dive-Computer.md`, *rewrite*) — Connecting a computer and downloading dives. Outline: supported brands/protocols (libdivecomputer; BLE/Bluetooth-classic/USB) → discover & pair (incl. BLE PIN) → download (incremental vs full; navigation guard during download) → duplicate detection & site auto-match → multi-computer consolidation & per-diver computer records → Shearwater Swift GPS entry/exit. Fixes: verify the real access path (via Transfer/Import vs. dedicated entry) and exact flow. Screenshots: `images/dive-computer/discover.png`, `download-progress.png`. Sources: `lib/features/dive_computer/`, `packages/libdivecomputer_plugin/`, plans `2026-02-18-libdivecomputer-platform-channels`, `2026-03-12-incremental-dive-download`, `2026-03-11-ble-pin-code-auth`, `2026-03-19-multi-computer-dive-consolidation`, `2026-03-03-linked-dive-computer`, `2026-05-22-shearwater-swift-gps-entry-exit`, `2026-03-07-download-navigation-guard`, `2026-04-11-per-diver-computer-records`.

8. **Import & Export** (`Import-Export.md`, *rewrite*) — The Transfer hub. Outline: **import** via the unified wizard (UDDF, Subsurface XML/SSRF, MacDive XML & SQLite, CSV with field mapping, Garmin FIT, Shearwater Cloud, Apple Watch/HealthKit, dive-computer) → drag-and-drop file import → duplicate handling & import tags → **export** (UDDF, CSV, Excel, PDF logbook templates, KML) → re-import all dives. Fixes: replace stale format list; reflect the single import entry point/wizard. Screenshots: `images/import-export/import-wizard.png`, `export-options.png`. Sources: `lib/features/transfer/`, `lib/features/universal_import/`, `lib/features/import_wizard/`, plans `2026-03-23-unified-import-wizard`, `2026-03-24-single-import-entry-point`, `2026-03-29-csv-import-rearchitect`, `2026-03-15-subsurface-xml-import`, `2026-04-21-macdive-*`, `2026-03-27-shearwater-cloud-import`, `2026-04-02-drag-drop-file-import`, `2026-02-02-pdf-templates`, `2026-02-03-excel-kml-export`, `2026-04-13-reimport-all-dives`, `2026-03-26-import-tag-selector`.

### Your Dive World

9. **Dive Sites** (`Dive-Sites.md`, *rewrite*) — Building and managing the site database. Outline: adding a site (manual, GPS capture, reverse-geocoded country/region) → fields (depth range, difficulty, hazards, access, mooring, altitude) → the **map** (clustering, offline tiles, heatmap density) → map/list split-pane & view toggle → importing sites → merging duplicates → GPS auto-matching of dives to sites. Fixes: add map features, matching, split-pane. Screenshots: `images/dive-sites/site-map.png`, `site-detail.png`, `site-list.png`. Sources: `lib/features/dive_sites/`, plans `2026-01-31-maps-visualization`, `2026-02-01-map-list-split-pane`, `2026-02-01-map-view-toggle`, `2026-05-26-gps-site-matching`, `2026-05-26-site-match-review-map-confirm`, `2026-05-30-site-field-autocomplete`, `2026-05-25-surface-gps-interactive-map`, `2026-05-30-heatmap-density-shader`.

10. **Trips** (`Trips.md`, *new*) — Grouping dives into trips/expeditions. Outline: creating a trip (types: shore, day trip, resort, liveaboard) → auto-adding dives by date → liveaboard details (vessel, operator, cabin, ports, itinerary) → the trip **photo gallery** → trip stats. Screenshots: `images/trips/trip-detail.png`, `trip-gallery.png`. Sources: `lib/features/trips/`, plans `2026-03-01-liveaboard-tracking`, `2026-01-26-trip-photo-galleries`, `2026-03-04-trip-auto-add-dives`, `2026-04-19-shared-sites-trips`.

11. **Buddies & Dive Centers** (`Buddies-and-Dive-Centers.md`, *new*) — People and operators. Outline: **Buddies** (add, contact/cert info, per-dive roles, merge duplicates, buddy signatures on training dives) → **Dive Centers** (add operators/shops, map, import, link to dives) → how each appears in stats. Screenshots: `images/buddies-and-dive-centers/buddy-detail.png`, `dive-center-detail.png`. Sources: `lib/features/buddies/`, `lib/features/dive_centers/`, plans `2026-03-22-buddy-merge`, `2026-01-31-buddy-signatures`.

12. **Marine Life & Photos** (`Marine-Life-and-Photos.md`, *new*) — Sightings and media. Outline: **Marine life** (species catalog, log a sighting w/ count & notes, photo annotation/bounding boxes, sightings stats) → **Photos & media** (add from gallery, underwater enrichment of depth/temp/location from the profile, captions, videos, favorites) → **media sources** (network URLs, connectors like Immich/Dropbox, subscriptions) → bulk media selection → cross-device photo resolution (with sync). Screenshots: `images/marine-life-and-photos/sighting.png`, `photo-enrichment.png`, `media-sources.png`. Sources: `lib/features/marine_life/`, media tables, plans `2026-01-25-site-marine-life`, `2026-01-25-underwater-photography`, `2026-01-25-photo-picker`, `2026-04-25/27/28-media-source-extension-phase*`, `2026-02-22-bulk-media-selection`, `2026-03-13-cross-device-photo-resolution`.

### Diver & Gear

13. **Certifications & Courses** (`Certifications-and-Courses.md`, *new*) — Training record. Outline: **Certifications** (add, agency/level, card number, issue/expiry, instructor, front/back card photos, expiry warnings, the **e-card wallet** & printing) → **Courses** (add a course/training org/instructor, link dives, signatures, earned cert). Screenshots: `images/certifications-and-courses/cert-wallet.png`, `course-detail.png`. Sources: `lib/features/certifications/`, `lib/features/courses/`, plans `2026-02-01-certification-ecards`, `2026-01-25-training-dives`.

14. **Equipment** (`Equipment.md`, *rewrite*) — Gear inventory & service. Outline: add gear (types, brand/model/serial/size/status/purchase) → **service records** & **maintenance reminders** (notifications, custom intervals) → **equipment sets/bags** & quick-select on a dive → **tank presets** → usage stats. Fixes: add service records, reminders, sets, tank presets. Screenshots: `images/equipment/item-detail.png`, `service-reminders.png`, `equipment-sets.png`. Sources: `lib/features/equipment/`, plans `2026-02-02-gear-maintenance-notifications`, `2026-02-27-equipment-sets-visibility`, tank-preset plans.

15. **Diver Profile & Multi-Diver** (`Diver-Profile.md`, *new*) — Your profile and sharing a device. Outline: the diver profile (personal, **emergency contacts**, **medical** info & clearance, **insurance**, notes) → creating/switching multiple divers → what's per-diver (logs, sites, gear, settings, units). Screenshots: `images/diver-profile/profile.png`, `switch-diver.png`. Sources: `lib/features/divers/`, plan `2026-02-23-diver-profile-settings`.

### Insights & Planning

16. **Statistics & Records** (`Statistics.md`, *rewrite*) — Analytics + personal records. Outline: overview (totals, averages, depth distribution) → the analytics dashboards (gas/SAC, progression, conditions, social, geographic, marine life, time patterns, equipment, profile/deco) → range/date filtering → **Records** (deepest, longest, coldest/warmest, most-in-a-day, etc.) with breakdowns. Fixes: replace thin stats list with the real dashboards; fold in Records. Screenshots: `images/statistics/overview.png`, `gas-sac.png`, `records.png`. Sources: `lib/features/statistics/`, plans `2026-04-15-statistics-overview`, `2026-02-26-enhanced-range-analysis`, `2026-03-01-cumulative-tissue-otu`.

17. **Planning & Calculators** (`Planning.md`, *new*) — Pre-dive tools, **full depth**. Outline: **dive planner** (multi-level profiles, gas planning, deco schedules, plan vs. actual) → **deco calculator** (Bühlmann ZH-L16C, GF) → **gas calculators** (nitrox/trimix blending, MOD/END/EAD, best-mix) → **weight calculator** (exposure suit + tank) → **surface-interval** tool. Screenshots: `images/planning/dive-planner.png`, `gas-calculators.png`. Sources: `lib/features/planning/` (`dive_planner`, `deco_calculator`, `gas_calculators`, `tools`), plan `2026-02-27-mnd-calculation`.

### Setup & Data

18. **Settings** (`Settings.md`, *rewrite*) — App configuration, **full depth**. Outline: units & formats (depth/temp/pressure/volume/weight/altitude/SAC; time & date) → decompression defaults (GF, ppO2 thresholds, CNS warning, ascent-rate thresholds, last-stop/increment) → **appearance** (themes/presets, card coloring, tissue-viz mode, profile overlay defaults) → **navigation customization** (mobile bottom bar) & **dive-detail section config** & **table columns** → notifications (service reminders, cert expiry) → offline maps → tags & dive types management → media sources → fix-dive-times/timezone, metric data-source switching. Cross-link Backup & Restore and Multi-Device Sync. Fixes: replace the stale settings list with the real, reorganized settings. Screenshots: `images/settings/settings-home.png`, `units.png`, `appearance.png`. Sources: `lib/features/settings/`, plans `2026-04-08-appearance-settings-reorganization`, `2026-02-25-app-theme-presets`, `2026-02-17-card-coloring`, `2026-04-20-bottom-nav-customization`, `2026-03-27-dive-detail-section-config`, `2026-04-04-table-view-customizable-columns`, `2026-02-24-tag-management`, `2026-03-17-dive-time-timezone-fix`, `2026-02-23/24-metric-data-source-switching`, `2026-02-24-platform-parity`.

19. **Backup & Restore** (`Backup-and-Restore.md`, *new*) — Local backups distinct from sync. Outline: what a backup contains (full database) → create/export a backup file → restore (incl. **replace** mode) → automatic DB backup before migrations → database reset → how this relates to (but differs from) Multi-Device Sync. Screenshots: `images/backup-and-restore/backup.png`, `restore.png`. Sources: plans `2026-02-22-file-based-backup-restore`, `2026-06-11-restore-replace-mode`, `2026-04-12-db-backup-before-migration`, `2026-02-27-database-reset`, `2026-06-15-smoother-restore-sync`.

### Kept as-is (not edited)

- **Multi-Device Sync** (`Multi-Device-Sync.md`) — quality-bar reference; cross-link from Settings/Backup/Installation.
- **Debug Mode** (`Debug-Mode.md`) — cross-link from Settings.

### Reference

20. **Glossary** (`Glossary.md`, *new*) — Alphabetical diving & app terms/abbreviations (SAC/RMV, NDL, TTS, RBT, GF, CNS, OTU, ppO2, MOD/END/EAD, CCR/SCR, deco, trimix, nitrox/EANx, etc.), each 1–2 lines, linking to the page that uses it. **Confirmed in scope for this pass.**

## 9. Cross-cutting content

- **Glossary** as above; define abbreviations on first use per page regardless.
- **Home** doubles as the orientation hub and must accurately describe the navigation model (Dashboard + groups; desktop rail vs. mobile bar + More).
- **"See also"** footers create a navigable web (e.g. Logging Dives ↔ Dive Profiles ↔ Dive Computers ↔ Import & Export).
- **Consistent terminology** with the app's actual labels (e.g. "Transfer" vs. "Import & Export" — page title can be user-friendly while noting the in-app label).

## 10. Accuracy & source-of-truth discipline (hard requirement)

Inaccuracy is the #1 problem, so the rewrite must be **verification-driven, not memory-driven**:

1. For each page, read the relevant `lib/features/<area>/` code **and** the cited `docs/plans` / `docs/superpowers/specs` before writing.
2. Every concrete claim (field names, steps, labels, nav paths, supported formats/devices) must be traceable to current code or a current spec. When code and an older plan disagree, **code wins**.
3. Prefer describing **behavior and labels the user sees**; avoid version-specific or implementation-detail claims that will rot.
4. Note any discovered bug/confusing-UX in the implementation plan's "issues found" list — do not fix app code in this effort.

## 11. Publishing mechanics

- Target repo: `submersion.wiki` (the GitHub wiki). Pages are root-level `Page-Name.md` files; titles derive from filenames (hyphens → spaces). Links use page-name targets.
- New pages = new files; rewrites keep existing filenames where possible (`Dive-Logging.md`, `Dive-Sites.md`, `Equipment.md`, `Statistics.md`, `Settings.md`, `Import-Export.md`, `Dive-Computer.md`, `Installation.md`, `First-Dive.md`, `Home.md`) to preserve inbound links/history.
- `_Sidebar.md` updated to the grouped structure.
- Images committed under `images/<page-slug>/` (mechanism finalized in the pipeline spec).
- This **design spec** lives in the **main app repo** (`submersion/docs/superpowers/specs/`), matching existing convention — never in the wiki repo (wiki files publish as public pages).

## 12. Success criteria

- All 19 content pages + Glossary + `_Sidebar.md` written; 2 kept pages untouched.
- Each page: accurate vs. the shipping app (verified per §10), covers its area at **full depth**, opens with the common path, follows the §6 template, uses GitHub-native markdown (no Docsify), and ends with "See also".
- Sidebar reflects the journey grouping and every link resolves.
- Every page declares its screenshot slots using the §7 convention.
- A new user can go Install → First Dive → and find a complete, correct guide to every major feature.

## 13. Open questions & risks

- **Glossary:** decided — included in this pass.
- **Broken-image gap:** how pages look before the pipeline populates images — resolved in the pipeline spec; may influence whether we seed an initial screenshot set during this effort.
- **Kept-page consistency:** the two kept pages use old `<div>` callouts; a future cosmetic-only pass could unify them.
- **Combined pages** (Buddies & Dive Centers; Marine Life & Photos; Certifications & Courses; Statistics & Records; Diver Profile & Multi-Diver): if any grows too long, split it.
- **Drift:** the app changes fast (many recent plans). Screenshot automation + the §10 discipline mitigate; consider a short "docs reflect vX.Y" note or a periodic review.
- **Access-path accuracy:** confirm real nav entry points for Dive Computers, Records, and Planning sub-tools (rail vs. More vs. within Transfer) during writing.

## 14. Next step

After approval: invoke the **writing-plans** skill to turn this into a phased implementation plan (likely: foundation/template + sidebar → Getting Started → Logging group → Dive World group → Diver & Gear group → Insights & Planning → Setup & Data → Glossary, with per-page verification tasks). The screenshot pipeline gets its own brainstorm → spec → plan afterward.
