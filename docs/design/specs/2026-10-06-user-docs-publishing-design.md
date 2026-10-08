# User Documentation in the Repository, Published at submersion.app/guide/ (Spec 2 of 2)

**Status:** Approved design, 2026-10-06
**Follows:** `docs/design/specs/2026-10-06-docs-restructure-design.md` (Spec 1, merged as #3057)
**Repositories:** `submersion-app/submersion` (content, guard) and
`submersion-app/submersion-website` (the `/guide/` page)

## Goal

The GitHub wiki is today's authoritative user documentation, but it cannot
take pull requests, it has drifted from the app, and a second, partial copy
lives in `docs/user/guide/` and `docs/user/features/`. This design makes
`docs/user/` the single source of user documentation, edited through normal
pull requests, published at `submersion.app/guide/`, and accurate against the
code. The GitHub wiki is emptied so it can be used for something else.

Success looks like this:

- A diver finds the complete, current guide at `submersion.app/guide/`.
- A contributor edits one Markdown file in `docs/user/`, opens a PR, and the
  site shows the change within minutes of merge, with no sync job.
- Every page's user-facing claims have been checked against the code.
- The wiki has no pages.

## Decisions

| Question | Decision |
| --- | --- |
| Authoritative source | The wiki. `docs/user/guide/` and `docs/user/features/` contribute only verified content the wiki lacks; the rest is discarded. |
| Site path | `submersion.app/guide/`. The website's own `docs/` folder is untouched. |
| Rendering | Client-side docsify on the website, reading Markdown from this repo at view time. |
| Wiki afterwards | Completely empty: every page deleted, `Home.md` and `_Sidebar.md` included. |
| Content scope | Move, fold, refresh against the code, and publish, all in this design. |

## Current state

- **Wiki:** 28 pages plus `_Sidebar.md`, 5,130 lines, every commit by
  the maintainer. Markdown in use: 97 GitHub alert callouts (`> [!NOTE]` 42,
  `[!TIP]` 48, `[!WARNING]` 6, `[!IMPORTANT]` 1), 100 tables, 33 raw
  `<div class="tip">` / `<div class="warning">` blocks, inline `<strong>`,
  `<em>`, `<code>`, `<sub>`, 4 `<img>` tags (all on Debug-Mode, hosted on
  `github.com/user-attachments`), 45 `<!-- screenshot: images/... -->`
  placeholders, 313 page-name links (`](Dive-Sites)`), one wiki-style link
  (`[[Dive Sites|Dive-Sites]]`), two `<a href="Page">` links, 17 same-page
  anchors, one fenced code block, and HTML entities (264 `&mdash;`).
- **Wiki accuracy:** a spot check of 10 claims found all 10 stale (iOS and
  macOS minimums, Linux packaging, the first-run flow, long-press selection,
  DAN DL7 import, Android USB, Insights filters, ascent-rate settings, the
  "Use Set" label, gradient factor range).
- **`docs/user/guide/` (11 pages) and `docs/user/features/` (10 pages):**
  17 pages hold verified content the wiki lacks; 4 (`guide/README.md`,
  `guide/debug-mode.md`, `features/README.md`, `features/multi-gas.md`) add
  nothing. The page-by-page fold list is in "Fold-in map" below.
- **`docs/user/` docsify shell:** `index.html`, `.nojekyll`, `_sidebar.md`,
  `README.md`, not published anywhere.
- **Website:** static HTML on GitHub Pages from `main`, no
  Content-Security-Policy, no subresource-integrity use yet, a hand-repeated
  header nav on every page, CSS variables for its dark ocean theme
  (`--ink`, `--cyan`, `--panel`, ...), and Node tests under `tests/`.
- **Inbound wiki links:** none in the app (`lib/`); one in
  `docs/developer/release-process.md` (Update Channels); one in the historical
  release note `docs/releases/v1.5.0.97.md`.

## Target layout of `docs/user/`

Flat: every page sits directly in `docs/user/`, so a link such as
`dive-sites.md` resolves identically on GitHub, in an editor, and in docsify
(which resolves links from its base path).

```
docs/user/
  README.md              home page (from wiki Home.md)
  _sidebar.md            navigation (from wiki _Sidebar.md)
  installation.md        one file per wiki page, lowercase-kebab
  first-dive.md          (Dive-Logging.md -> dive-logging.md, ...)
  ...
  cylinder-passports.md  new page
  images/                screenshots, starting with Debug-Mode's 4
```

Removed: `docs/user/guide/`, `docs/user/features/`, `docs/user/index.html`,
`docs/user/.nojekyll`, and the old `docs/user/_sidebar.md` and
`docs/user/README.md` (replaced by the wiki's).

### Conversion rules (mechanical move)

| Wiki form | `docs/user/` form |
| --- | --- |
| File `Dive-Logging.md` | `dive-logging.md` (lowercased; `_Sidebar.md` becomes `_sidebar.md`, `Home.md` becomes `README.md`) |
| `](Dive-Sites)` | `](dive-sites.md)` |
| `](Dive-Sites#section)` | `](dive-sites.md#section)` |
| `[[Dive Sites\|Dive-Sites]]` | `[Dive Sites](dive-sites.md)` |
| `<a href="Media-Sync">text</a>` | `[text](media-sync.md)` |
| `](Home)` | `](README.md)` |
| `<img alt="A" src="https://github.com/user-attachments/...">` | `![A](images/debug-mode-<n>.png)`, file downloaded into `images/` |
| `<div class="tip">` ... `</div>` | `> [!TIP]` callout, each inner line prefixed `> ` |
| `<div class="warning">` ... `</div>` | `> [!WARNING]` callout, likewise |

Why the HTML forms change (found in the 2026-10-06 dry run): docsify rebases
Markdown links and images onto its base path but leaves raw HTML untouched,
so a relative `<img src>` or `<a href>` works on GitHub and 404s on the
published guide. And GitHub strips the `class` from `<div class="tip">`
while docsify's theme does not style it, so those 33 blocks rendered as plain
text in both places; as callouts they render styled in both. After the move
the guide has 130 callouts and no raw `<div>`, `<a href>` or `<img>`.

Kept exactly as written: alert callouts (rendered by GitHub natively and by
docsify through the alerts plugin), inline formatting HTML (`<strong>`,
`<em>`, `<code>`, `<sub>`), same-page anchors, screenshot placeholder
comments, tables, and HTML entities. docsify 5's heading slugs match GitHub's except that docsify
prefixes a slug that starts with a digit with `_`; 8 wiki headings start with
a digit (numbered steps in Multi-Device-Sync and Weight-Planner) and no link
targets them, so every existing anchor works in both. Guard rule 3 keeps it
that way.

The move PR changes nothing else, so a reviewer can compare it with the wiki
page by page.

## Content work: fold and refresh

All 28 pages are audited against the code after the move.

### What counts as verified

Every user-actionable claim (a label, a menu path, a step, a number, a
platform statement) must match the code:

- UI labels: the English strings in `lib/l10n/arb/app_en.arb`.
- Menu paths and screens: the navigation and page code under `lib/`.
- Numbers (limits, defaults, thresholds): the constants that define them.
- Platform support and minimums: build configuration (`ios/`, `macos/`,
  `android/`, release workflows).

A claim that cannot be verified is rewritten to what the code does, or
removed. It is never left as is. Each content PR's description lists its
principal claims with the file each was checked against.

### Known stale claims (fixed during the audit)

1. Home: 13 rail destinations including "Statistics"; the app has 16
   (`lib/shared/widgets/nav/nav_destinations.dart`), and Statistics is
   Insights.
2. Installation: iOS 14 / macOS 11; the app needs iOS 15 / macOS 12. Linux is
   described as a tarball only; releases ship `.deb` and `.rpm` with
   `install.sh`, udev rules, and a glibc 2.38 floor.
3. First-Dive: a name-only welcome; the app runs a four-step setup wizard
   (Profile, Units, Backup, Done) with a restore path.
4. Dive-Logging, Dive-Sites, Buddies: "long-press to select"; selection is
   **Select items** in the overflow menu (#2775).
5. Import-Export: DAN DL7 "not yet readable"; it has a parser, as do Diving
   Log SQLite and Ratio XML.
6. Dive-Computer: USB is desktop-only; Android supports USB serial.
7. Statistics: no filters; Insights takes the dive filter, and has Dive focus
   and Observations pages the wiki omits.
8. Dive-Profiles: ascent-rate thresholds are adjustable in Settings; the
   Settings UI does not offer them.
9. Equipment: "Apply set"; the button is **Use Set**.
10. Glossary: gradient factors range 10-100; the sliders start at 15.

### Fold-in map

Only items marked true against the code in the 2026-10-06 comparison are
carried over. Stale items in the source pages are discarded.

| Source | Into | Content |
| --- | --- | --- |
| `guide/installation.md` | Installation | Linux `.deb`/`.rpm`, `install.sh`, udev rules, `uninstall.sh`, glibc 2.38; optional ffmpeg; iOS 15 / macOS 12 |
| `guide/first-dive.md` | First-Dive | Setup wizard (new profile or existing data: restore, cloud sync, folder); Day Trip for a single dive |
| `guide/dive-logging.md` | Dive-Logging | Tanks or Equipment explanation; **Fill from my cylinders**; registered-transmitter matching; weight names and `weights[label ~ ...]` search; **Select items**; renumber all dives |
| `guide/dive-sites.md` | Dive-Sites | Map wraps across the 180th meridian; site Dive Statistics card; tides on site detail with no API key |
| `guide/equipment.md` | Equipment | Cylinders on a dive and Fill from my cylinders; a Tank item in a set links as equipment only |
| `guide/insights.md` | Statistics | Insights takes the dive filter, with the dive-count bar |
| `guide/import-export.md` | Import-Export | DAN DL7 including the DiveCloud ZIP; five-file CSV export with units choice and header-detected re-import; dives placed into trips by date on import; Import from Garmin Device |
| `guide/dive-computer.md` | Dive-Computer | Per-platform transport matrix (Android USB serial); support matrix link `submersion.app/computers`; Garmin FIT, cable and Garmin Connect; **Combine** and **Merge as another computer** (Best fit / Align starts) |
| `guide/settings.md` | Settings | ppO2 limits for open circuit (working 1.4, maximum 1.6) |
| `guide/multi-device-sync.md` | Multi-Device-Sync | What syncs between devices; duplicate diver profiles banner and Merge; R2 EU and FedRAMP endpoints |
| `features/buddies.md` | Buddies-and-Dive-Centers | Import from Contacts; Capture Instructor Signature |
| `features/trips.md` | Trips | Day Trip end date locked to start; six tabs on every trip type (Overview, Itinerary, Gear, Checklist, Dives, Photos); itinerary days Travel / Dive / Rest with planned dives; countdown and day-by-day story with day maps |
| `features/tags.md` | Dive-Logging | "Tags and dive types" section: 20 tag colours, tag merge, 15 built-in dive types, custom dive types |
| `features/marine-life.md` | Marine-Life-and-Photos | Freshwater species and catalog updates on launch; Species page (search, sort, Manage catalog); **Look up online** (iNaturalist); **Suggest for the catalog**; species photo tagging. Its maintainer section moves to developer docs |
| `features/media-matching.md` | Marine-Life-and-Photos | "How photos are matched": time windows, EXIF and video date order, GoPro, no-capture-date messages, **Choose dive**, **Shift capture times by** |
| `features/profile-analysis.md` | Dive-Profiles | Data Sources comparison grid; hiding a computer hides its temperature, events and pressure; Unlink; Export as image |
| `features/decompression.md` | Dive-Profiles | Compartment half-times (4 to 635 minutes) |
| `features/oxygen-tracking.md` | Glossary | CNS surface half-time of 90 minutes |
| `docs/user/README.md` (old) | README (Home) | The tagline "Dive safe. Log everything." |

New page: `cylinder-passports.md` (what a passport holds, writing and
scanning QR and NFC tags, the `submersion.app/c` landing page, and a link to
the format spec in `docs/developer/reference/formats/`). Added to the sidebar
under Diver and Gear.

Discarded entirely: `guide/README.md`, `guide/debug-mode.md` (the wiki page
is the same text with screenshots), `features/README.md`,
`features/multi-gas.md`.

### Writing conventions

- Keep the wiki's voice and page structure.
- No em-dash or en-dash as punctuation and no spaced hyphen as punctuation:
  each `&mdash;` is rewritten as its sentence is touched (all 264 are touched,
  since every page is audited), never substituted mechanically.
- Measurements carry both unit systems, as the wiki already does.
- No emoji.

## The website page: `/guide/`

A single new file, `guide/index.html`, in `submersion-website`. It holds no
content.

- **Scripts:** docsify `5.0.0` and `docsify-plugin-flexible-alerts` `1.3.0`
  from `cdn.jsdelivr.net`, pinned to exact versions with `integrity`
  (subresource integrity) and `crossorigin="anonymous"` on every script and
  stylesheet tag. The search plugin is `dist/plugins/search.min.js` from the
  same pinned docsify release.
- **Configuration:**
  - `basePath`: `https://raw.githubusercontent.com/submersion-app/submersion/main/docs/user/`
  - `homepage`: `README.md`
  - `loadSidebar`: `true` (reads `_sidebar.md` from the base path)
  - `relativePath`: `false` (correct for the flat layout)
  - `routerMode`: `hash` (URLs such as `/guide/#/dive-logging`; GitHub Pages
    cannot route a clean path to one HTML file)
  - `search`: over every sidebar page
  - alerts plugin: GitHub syntax (`> [!NOTE]`, `[!TIP]`, `[!IMPORTANT]`,
    `[!WARNING]`, `[!CAUTION]`)
- **Edit this page:** a docsify plugin hook appends a link to
  `https://github.com/submersion-app/submersion/edit/main/docs/user/<file>`
  on every page.
- **Look:** docsify's `core` theme with its dark add-on, recoloured by a
  `guide/guide.css` to the site's palette and font. The brand (favicon and
  "Submersion Guide") heads the sidebar, and a small fixed link row (Home,
  Download, GitHub) sits top right. The site's full header is not copied in:
  docsify owns the page layout, and a second fixed header would fight its
  sidebar.
- **No JavaScript:** a `<noscript>` link to
  `https://github.com/submersion-app/submersion/tree/main/docs/user`.
- **Navigation:** a "Guide" link in the header nav (`index.html`,
  `computers/`, `privacy/`, `terms/`) and a "User Guide" link in the footer
  link row (the same four pages; `lightroom/` has no link row). The existing
  `tests/support-matrix-page.test.mjs` compares each inner page's menu with
  the homepage's after rebasing the homepage's `#section` links with `../`;
  it is widened to rebase every site-relative link, so `guide/` matches
  `../guide/`.
- **Failure:** if `raw.githubusercontent.com` is unreachable, docsify shows its
  not-found page. Accepted as the cost of client-side rendering.

### Website tests

New `tests/guide-page.test.mjs` (Node test runner, as the existing tests):

- every external script and stylesheet in `guide/index.html` carries an
  `integrity` attribute and a version-pinned URL (no `@latest`, no bare major);
- `basePath` is the `main/docs/user/` raw URL;
- `loadSidebar` is enabled and `routerMode` is `hash`;
- the edit-link template points at `edit/main/docs/user/`;
- every HTML page with a header nav includes a link to `/guide/`.

## Guard extensions in this repository

`scripts/check_docs_links.py` gains `docs/user/` as a checked tree, plus
four rules that apply to it only. Tests first, in
`scripts/check_docs_links_test.py`.

1. **Flat:** no subdirectory in `docs/user/` other than `images/`, and no
   Markdown file inside `images/`.
2. **Sidebar complete:** every `.md` file in `docs/user/` other than
   `README.md` and `_sidebar.md` is linked from `_sidebar.md`.
3. **Anchors resolve:** every link with a `#fragment` to a `docs/user/` page
   (same page or another) matches a heading of the target under GitHub's slug
   rules (lowercase; drop characters other than letters, digits, spaces and
   hyphens; each space becomes a hyphen; a repeated slug gains `-1`, `-2`).
   A link whose target heading's slug starts with a digit fails, because
   docsify prefixes that slug with `_` and the two renderers would disagree.
   Unlinked digit-leading headings (the numbered steps) are allowed.

4. **No raw relative HTML links or images:** an `<a href>` or `<img src>`
   whose URL is relative fails with a message to use Markdown
   (`[text](page.md)`, `![alt](images/x.png)`), for the reason given under the
   conversion rules.

Wiki-style links (`](Dive-Sites)`) need no rule: no file has that name, so
the existing broken-link check fails them.

## Cutover order

1. **App PR 1, mechanical move:** wiki content into `docs/user/` by the
   conversion rules; `guide/`, `features/` and the docsify shell removed;
   guard extensions and tests; inbound-link updates; the "Writing user docs"
   section. The content still matches the wiki.
2. **Website PR:** `guide/index.html`, the Guide nav links, and its tests.
   Merged after app PR 1, so the guide goes live with complete content.
3. **Wiki cleared:** one commit to `submersion.wiki.git` deleting every page,
   pushed only after the maintainer confirms at that step. The wiki's git
   history retains every page.
4. **App PRs 2 to 8, content:** one per sidebar section, in any order,
   independent of each other:
   - Getting Started (README, installation, first-dive)
   - Logging Your Dives (dashboard, dive-logging, dive-profiles,
     dive-computer, import-export, data-quality-assistant)
   - Your Dive World (dive-sites, trips, buddies-and-dive-centers,
     marine-life-and-photos)
   - Diver and Gear (certifications-and-courses, equipment, diver-profile,
     cylinder-passports)
   - Insights and Planning (statistics, planning, weight-planner, safety)
   - Setup and Data (settings, update-channels, backup-and-restore,
     multi-device-sync, media-sync, encrypted-sync, debug-mode)
   - Reference (glossary)

   A PR that creates a page adds its `_sidebar.md` entry itself (guard rule 2
   fails it otherwise), so Diver and Gear adds Cylinder Passports.

   Each PR folds in its pages' rows of the fold-in map, fixes the known stale
   claims on its pages, audits every remaining claim, and lists the claims it
   checked.

## Inbound links and contributor docs (in app PR 1)

- `docs/developer/release-process.md`: the Update Channels wiki link becomes
  `https://submersion.app/guide/#/update-channels`.
- `README.md`: a link to the user guide at `https://submersion.app/guide/`.
- `CONTRIBUTING.md`: the documentation bullet says user docs are edited in
  `docs/user/` and appear at `submersion.app/guide/` once merged.
- `docs/README.md`: the `user/` row says the folder is published at
  `submersion.app/guide/`.
- `docs/contributing/README.md`: a "Writing user docs" section with the
  conventions above (flat folder, lowercase-kebab names, file-relative `.md`
  links, new pages added to `_sidebar.md`, GitHub alert syntax, screenshots in
  `images/`, no em-dashes or emoji).
- Three references to `docs/user/guide/` pages that the guard reports once
  the folder is gone:
  - `docs/developer/database.md` links "What Syncs Between Devices" in
    `../user/guide/multi-device-sync.md`; PR 1 points it at
    `../user/multi-device-sync.md` without an anchor, and the Setup and Data
    content PR, which adds that section, restores the
    `#what-syncs-between-devices` anchor.
  - `lib/core/services/sync/device_local_fields.dart` (a comment) names
    `docs/user/guide/multi-device-sync.md`; it becomes
    `docs/user/multi-device-sync.md`.
  - `.github/workflows/build-all.yml` (a comment) names
    `docs/user/guide/installation.md`; it becomes `docs/user/installation.md`.
- `docs/releases/v1.5.0.97.md` keeps its wiki link: it is a historical release
  note, and the GitHub release published from it does not change.

## Verification

- Guard: `python3 scripts/check_docs_links.py` passes on every app PR, and its
  tests cover each new rule failing and passing.
- Move PR: a script lists each wiki page and its `docs/user/` counterpart with
  a diff limited to the conversion rules; any other difference is a defect.
- Website: `node --test tests/*.test.mjs` passes; after the website PR merges,
  `https://submersion.app/guide/` is opened in a browser and checked for the
  home page, the sidebar, search, an alert callout, a table, a cross-page link,
  a same-page anchor, and the edit link.
- Content PRs: each lists its verified claims and the files they were checked
  against; a reviewer spot-checks them.
- Wiki: after clearing, `git ls-remote` and a fresh clone of the wiki show no
  pages.

## Risks

- **Raw file server availability and caching.** Every guide view fetches from
  `raw.githubusercontent.com`; an outage shows docsify's not-found page, and a
  merged edit can take about five minutes to appear (its cache lifetime).
- **Search quality and indexing.** Client-side rendering means search engines
  index little of the guide. Accepted with the docsify choice.
- **Third-party script.** docsify and the alerts plugin run on submersion.app;
  integrity hashes limit this to the exact pinned files.
- **Audit size.** About 5,100 lines across 28 pages. Splitting by sidebar
  section keeps each PR's claims reviewable; the PRs can run in parallel.
- **Stale branches.** A branch opened before PR 1 that edits
  `docs/user/guide/` or `docs/user/features/` conflicts after it merges; its
  change belongs in the matching `docs/user/` page.

## Out of scope

- What the wiki is used for next.
- Producing the screenshots the 45 placeholders describe.
- Moving or unpublishing the website's own `docs/` folder, and the test
  database it serves (`docs/submersion-test_data.db`), raised separately.
- Translating the guide.
