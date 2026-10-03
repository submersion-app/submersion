# Dive computer support matrix: design

Date: 2026-10-02
Issue: #2616

## Goal

Publish a per-computer matrix of model, transport, platform and verification
status at `https://submersion.app/computers`, so the YouTube description, issue
replies and forum answers have one stable URL to point divers at. It answers
"will my computer work on my phone or laptop?" and shows testers which cells
still need a report.

The matrix is sourced from every place reports live: the ScubaBoard tester
thread, GitHub issues, PRs and discussions, the app's release notes, Reddit
r/submersion, and App Store and Google Play reviews. It stays current through a
monthly re-sweep that opens a PR for review.

## Non-goals

- No in-app surface. The app's computer picker does not show verification
  status in this work.
- No report form. New evidence arrives through the periodic sweep only.
- No fixes to the transport code issues the survey found (see "Follow-ups").
- No status for transports Submersion does not implement (Bluetooth Classic,
  IrDA). They are footnoted, not tracked.

## Background: what the app actually supports

Two layers make up the matrix:

- **Capability**: what is possible. This is mechanical: libdivecomputer's
  `g_descriptors[]` table (`packages/libdivecomputer_plugin/third_party/libdivecomputer/src/descriptor.c`,
  about 356 entries, on the fork's `submersion-patches` branch) intersected
  with what each platform implements.
- **Evidence**: what has been verified in Submersion. This takes judgment and
  comes from human reports.

Transports implemented per platform, from a survey of the native code:

| Platform | BLE | Bluetooth Classic | USB serial | USB HID | IrDA |
|---|---|---|---|---|---|
| iOS | yes | no | no | no | no |
| Android | yes | no (dual-mode radios forced onto LE) | yes | no | no |
| macOS | yes | no | yes (plus raw FTDI fallback) | yes | no |
| Windows | yes | no | yes (COM port only) | yes | no |
| Linux | yes | no | yes (ttyUSB/ttyACM) | yes (hidraw) | no |

Consequences the matrix must show honestly:

- Models listing `USBHID | BLE` (Suunto EON Steel, EON Core, D5, EON Steel
  Black; Scubapro G2, G2 TEK, G2 Console, G3, G2 HUD) are Bluetooth-only on iOS
  and Android, Bluetooth and USB on desktop.
- Scubapro Aladin Square (`USBHID` only) is n/a on iOS and Android.
- The 19 IrDA-only models are unsupported everywhere.
- No model is Bluetooth-Classic-only (all 11 Classic entries also list serial).

The existing prose lists disagree with each other and with the code:
`README.md` says "Confirmed working: Shearwater Teric, Aqualung i300C, Aqualung
i330R"; `docs/guide/dive-computer.md` has a much broader "Fully Tested" table
and lists Bluetooth Classic as a connection type, which no platform implements.
The matrix replaces both.

## Architecture

Three parts, split across the two repos:

| Part | Repo | Path |
|---|---|---|
| Catalog generator and platform rules | `submersion` (app) | `scripts/export_support_matrix_catalog.py`, `scripts/export_support_matrix_catalog_test.py`, `scripts/data/support_matrix_platform_rules.json` |
| Data, page, validator, sweep procedure | `submersion-website` | `computers/index.html`, `computers/matrix.js`, `computers/data/catalog.json`, `computers/data/reports.json`, `tools/support-matrix/validate.mjs`, `tools/support-matrix/SWEEP.md`, tests under `tests/` |
| Monthly sweep | scheduled cloud routine | prompt: follow `tools/support-matrix/SWEEP.md` |

The routine is the only link between the repos. It runs the generator against
app `main`, writes the output into the website repo, and opens one website PR.
No cross-repo CI.

## 1. Data model

### `catalog.json` (generated, never hand-edited)

```json
{
  "generatedFrom": {
    "appCommit": "<sha>",
    "libdcCommit": "<sha>",
    "generatedAt": "2026-10-02T00:00:00Z"
  },
  "models": [
    {
      "id": "shearwater-perdix-3",
      "vendor": "Shearwater",
      "product": "Perdix 3",
      "libdc": ["ble", "serial"],
      "platforms": {
        "ios": ["bluetooth"],
        "android": ["bluetooth"],
        "macos": ["bluetooth"],
        "windows": ["bluetooth"],
        "linux": ["bluetooth"]
      }
    }
  ],
  "unsupported": [
    { "id": "...", "vendor": "...", "product": "...", "reason": "irda-only" }
  ],
  "removed": ["old-model-id"]
}
```

- `libdc` lists the raw libdc transport flags (`serial`, `usb`, `usbhid`,
  `irda`, `bluetooth`, `ble`).
- `platforms` maps each platform to the transport **families** it can reach for
  this model. Two families are shown: `bluetooth` (libdc `ble`) and `usb`
  (libdc `serial`, `usb`, `usbhid`). An empty list means the model is n/a on
  that platform.
- `id` is a slug of vendor and product: lowercase, runs of non-alphanumerics
  collapsed to `-`, trimmed. Ids must stay stable because reports reference
  them. Two descriptors producing the same id is a hard error: the generator
  exits non-zero naming both entries, and a disambiguation is added to the
  rules file by hand.
- `removed` lists ids that appeared in the previous `catalog.json` (passed in
  with `--previous`) but not in this one, so orphaned reports surface.
- `unsupported` lists models with no reachable family on any platform (today
  the IrDA-only models), for the page footnote.

### `support_matrix_platform_rules.json`

```json
{
  "ios": ["ble"],
  "android": ["ble", "serial"],
  "macos": ["ble", "serial", "usbhid"],
  "windows": ["ble", "serial", "usbhid"],
  "linux": ["ble", "serial", "usbhid"],
  "idOverrides": {}
}
```

libdc's `usb` flag (Atomic Aquatics Cobalt and Cobalt 2 only) is not listed for
any platform until the implementation plan confirms which platforms reach it;
see "Open verification items".

### `reports.json` (curated by the sweep)

```json
{
  "watermarks": {
    "scubaboard": { "lastPostId": 10735581, "sweptAt": "2026-10-02" },
    "github": { "since": "2026-10-02T00:00:00Z" },
    "reddit": { "lastCreatedUtc": 1790000000 },
    "appStore": { "lastReviewId": "...", "sweptAt": "2026-10-02" },
    "playStore": { "lastExportMonth": "2026-09" }
  },
  "reports": [
    {
      "model": "shearwater-perdix-3",
      "platform": "android",
      "transport": "bluetooth",
      "outcome": "fails",
      "appVersion": "1.7.2",
      "date": "2026-06-14",
      "source": "github-issue",
      "url": "https://github.com/submersion-app/submersion/issues/723",
      "sourceRef": null,
      "fixedIn": "1.7.3",
      "note": "Name advertised with a trailing NUL; not recognized"
    }
  ]
}
```

Fields:

- `platform`: `ios`, `android`, `macos`, `windows`, `linux`.
- `transport`: `bluetooth` or `usb`.
- `outcome`: `works`, `caveats`, `fails`. An ambiguous report ("works but drops
  halfway") is `caveats`, never `works`; when unsure, record the weaker outcome.
- `appVersion`: as reported, or `null` when the source does not say.
- `source`: `scubaboard`, `github-issue`, `github-pr`, `github-discussion`,
  `reddit`, `app-store`, `play-store`. Release notes are not a source: a note
  saying a fix shipped is not a user verifying it, so release notes only
  corroborate `fixedIn` and never create a report.
- `url`: a permalink to the post, issue comment, discussion comment or Reddit
  comment. For store reviews, which have no public permalink, `url` is the store
  listing and `sourceRef` holds the review id (used for dedupe only, never
  shown).
- `fixedIn`: the first release version containing the fix, resolved with
  `git tag --contains <merge-sha>` on the fixing PR's merge commit. A fix merged
  after the newest tag gets `fixedIn: "unreleased"`.
- `note`: at most 120 characters, a paraphrase in our own words. No quoted post
  or review text.

Content rules: no usernames or display names anywhere in the data or on the
page. The link is the attribution.

### Cell status

A cell is one row (model and transport family) and one platform column:

1. The family is not in `catalog.models[].platforms[platform]`: **n/a**.
2. No reports for the cell: **Untested**.
3. Otherwise take the newest report, ordered by `appVersion` (semver compare;
   `null` sorts oldest), then `date`:
   - `works`: **Verified**, but only if at least one `works` report for the cell
     has a linkable `url` (any source other than `app-store` or `play-store`).
     Otherwise **Issues**.
   - `caveats`: **Issues**.
   - `fails` with `fixedIn` set to a version: **Issues**, labelled "fixed in vX,
     awaiting confirmation".
   - `fails` with `fixedIn: "unreleased"`: **Not working**, labelled "fix
     pending release".
   - `fails` otherwise: **Not working**.

Ordering by app version first stops a report from an old build outranking a
newer build's report just because it was posted later.

## 2. The page

`computers/index.html` with `computers/matrix.js`, plain HTML and JS like the
rest of the site, using the dark visual system from `styles.css` and the same
header and footer as `privacy/`. It fetches both data files from the same
origin and computes every cell status in the browser; the status function is
the single implementation of the rules above.

Top to bottom:

1. **Intro**: one paragraph on what the matrix is, a legend (Verified, Issues,
   Not working, Untested, n/a, each an icon plus a word, never colour alone),
   and "Last updated" from the data.
2. **Controls**: a search box over vendor and product, and filters for brand,
   platform, status and transport. Search and filters are reflected in the URL
   query so a filtered view can be shared.
3. **Table**: columns Model, Transport, iOS, Android, macOS, Windows, Linux. One
   row per model and transport family that is reachable on at least one
   platform. Grouped by vendor; within a vendor, rows with any report sort
   first, then alphabetically.
4. **Cell detail**: tapping a cell that has reports expands a panel under the
   row listing every report for that cell, newest first: outcome, app version,
   date, note and a source link ("GitHub #723", "ScubaBoard post", "Reddit",
   "App Store review").
5. **Help fill the gaps**: points testers to the ScubaBoard thread, r/submersion
   and the GitHub issue tracker, and asks for model, phone or computer OS,
   transport and app version in any report.
6. **Footer**: data provenance (app and libdc commits from `generatedFrom`) and
   the list of unsupported (IrDA-only) models.

Deep links: `/computers#<model-id>` scrolls to that model's rows and highlights
them. A fragment, not a path, so GitHub Pages needs no rewrite rules.

Below about 720 px the table becomes one card per row: model, transport, and
five platform chips on one line. No horizontal scroll.

The homepage's `#computer` zone gains a "See which computers are verified" link
to the page.

## 3. Generator

`scripts/export_support_matrix_catalog.py`, standard library only, runnable on
Python 3.9 or later so it works in the cloud routine as well as locally.

- Parses `g_descriptors[]` entries
  (`{"Vendor", "Product", DC_FAMILY_..., model, DC_TRANSPORT_A | ..., filter}`)
  from `descriptor.c`.
- Reads `scripts/data/support_matrix_platform_rules.json`.
- Optional `--previous <catalog.json>` to compute `removed`.
- Writes `catalog.json` to the path given by `--out`.
- Records the app and libdc submodule commits in `generatedFrom`.

`scripts/export_support_matrix_catalog_test.py` (unittest, same import style as
`check_pr_issue_link_test.py`) must be added to the script-test list in
`.github/workflows/ci.yaml` (around line 560), or CI never runs it. Cases:

- Aladin Square (USBHID only): `usb` on macOS, Windows, Linux; empty on iOS and
  Android.
- G2 and EON Steel (USBHID and BLE): `bluetooth` only on iOS and Android;
  `bluetooth` and `usb` on desktop.
- A Classic plus serial model: no `bluetooth` family anywhere.
- An IrDA-only model: in `unsupported`, not in `models`.
- Two descriptors slugging to the same id: non-zero exit naming both.
- `--previous` with a dropped id: listed in `removed`.
- A parse of the real `descriptor.c` yields more than 300 models (a guard
  against a regex that silently matches nothing).

## 4. Sweep

### Sources

| Source | Initial scope | Monthly scope | Access |
|---|---|---|---|
| ScubaBoard thread 667061 | all 73 pages | pages after `lastPostId` | public fetch with curl |
| GitHub issues | `device sync` label (81) plus full-text vendor-name search over all 1,181, comments included | updated since `github.since` | gh REST dumps grepped locally (search rate-limits) |
| GitHub PRs | merged device fixes | merged since `github.since` | gh REST; `fixedIn` via `git tag --contains` |
| GitHub discussions | all 36 | updated since `github.since` | GraphQL |
| Release notes (corroborate `fixedIn` only) | `docs/releases/` | new files | repo read |
| Reddit r/submersion | all posts and comments | newer than `lastCreatedUtc` | public `/r/submersion/new.json` and per-post comment JSON |
| App Store | public customer-reviews RSS, every storefront | reviews newer than `lastReviewId` | no credentials; about the 500 most recent per storefront |
| Google Play | Play Console monthly review export CSVs | months after `lastExportMonth` | read-only service account on the `pubsite_prod_*` bucket, stored as a routine secret |

The Play Developer API's `reviews.list` returns only the last 7 days and is not
used.

### Initial sweep (one time)

A parallel agent fan-out: about 8 agents over the ScubaBoard pages (about 9
pages each), and one agent each for issues, PRs, discussions, release notes,
Reddit and the App Store. The Play export joins once the service account exists.
Each agent returns candidate records with permalinks. A merge pass then:

- maps family names ("Suunto D-series") to catalog ids, and puts anything it
  cannot map into an `unmapped` list in the PR body for review, never guessed;
- dedupes on (`url` or `sourceRef`, `model`, `platform`, `transport`);
- resolves `fixedIn` for every fixing PR;
- sets the watermarks.

The result is one website PR containing only `reports.json` changes.

### Monthly routine

`tools/support-matrix/SWEEP.md` holds the procedure, so the scheduled prompt
is one line and the procedure is versioned with the data. Each run:

1. Runs the generator against app `main` with `--previous` and writes
   `catalog.json`.
2. Sweeps each source from its own watermark.
3. Runs `validate.mjs`.
4. Opens one website PR with both files, listing new reports, `unmapped`
   items, reports orphaned by `removed`, and any source that failed.

PR titles and bodies carry no tool attribution.

## 5. Validation and error handling

`tools/support-matrix/validate.mjs`, run by the website repo's existing test
workflow, fails when:

- a report's `model` is not in `catalog.models`;
- a report's family is not reachable on its platform per the catalog;
- an enum field has an unknown value;
- two reports share (`url` or `sourceRef`, `model`, `platform`, `transport`);
- a `url` host does not match its `source` (for example a `reddit` source not on
  `reddit.com`);
- a `note` exceeds 120 characters.

Failure handling in the routine:

- A source that is down, blocked or rate-limited keeps its watermark, and the
  PR body names it. Other sources proceed.
- If every source fails, no PR is opened and the run reports why.
- Reports orphaned by `removed` are listed in the PR, never deleted silently.

## 6. Testing

- Generator: the unittest cases in section 3.
- Page: `node --test` cases for the status function (every rule, including
  version-first ordering, `null` versions, `fixedIn` both ways, and the
  linkable-source requirement for Verified), for search and filters, and for
  deep-link resolution.
- Validator: `node --test` with one fixture per failure class.
- Visual: the page checked at phone and desktop widths in a browser before the
  page PR.

## 7. Rollout

| # | Repo | Content | Issue link |
|---|---|---|---|
| 1 | app | generator, platform rules, tests, CI test-list entry | `Refs #2616` |
| 2 | website | page, `matrix.js`, validator, tests, generated `catalog.json`, empty `reports.json`, homepage link | none required |
| 3 | website | initial sweep results in `reports.json` | none required |
| 4 | website | `SWEEP.md`; the scheduled routine is created after the maintainer sets up the Play service account | none required |
| 5 | app | `docs/guide/dive-computer.md` and `README.md` replace their tested lists and the Bluetooth Classic row with a link to the matrix | `Closes #2616` |

PR 5 touches only `docs/` and `README.md`, outside the UI paths, so it needs no
screenshots.

Maintainer steps that cannot be automated: create the Play service account,
grant it Storage Object Viewer on the `pubsite_prod_*` bucket, and add its key
as a secret in the routine's environment. `SWEEP.md` documents these.

## Open verification items

Settle these in the implementation plan, against the code:

- Which platforms reach libdc's `usb` flag (Atomic Aquatics Cobalt and Cobalt
  2), and whether Android exposes it.
- Whether Windows and Linux reach FTDI cables with custom PIDs (Oceanic
  `0x0403:0xF460`) through the OS driver; if not, those models need a per-model
  rule rather than a platform-wide one.
- Whether a cloud routine can fetch ScubaBoard pages, or whether it is blocked
  at the edge; if blocked, `SWEEP.md` documents a local fallback run for that
  source.

## Follow-ups (out of scope)

Found by the transport survey; to be filed separately:

1. iOS shows the USB tab in Add Computer and lists serial models it cannot
   reach (`scan_step_widget.dart`, `discovery_providers.dart:52-63`).
2. A stale comment in Android `DiveComputerHostApiImpl.kt:118-122` says no
   platform implements USB HID.
3. Windows and Linux route an `infrared` device into the BLE and serial download
   branches respectively; unreachable today because the UI never creates one.
