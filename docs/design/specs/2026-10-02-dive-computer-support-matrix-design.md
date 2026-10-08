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
thread, GitHub issues, PRs and discussions, the app's release notes, and App
Store reviews. It stays current through a
monthly re-sweep that opens a PR for review.

Divers can also report their own result for any model from the page: a
"Report your result" link opens a GitHub issue form with the model, connection
and (from a cell) platform already filled in, and the sweep reads those reports
field by field.

## Non-goals

- No in-app surface. The app's computer picker does not show verification
  status, and the app does not prompt for feedback after a download.
- No report form outside GitHub: no hosted form service and no endpoint
  Submersion runs. A report needs a free GitHub account.
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
| Data, page, validator, sweep procedure | `submersion-website` | `computers/index.html`, `computers/page.css`, pure modules `computers/status.js`, `computers/rows.js`, `computers/render.js`, browser glue `computers/page.js`, data `computers/data/catalog.json` and `computers/data/reports.json`, `tools/support-matrix/validate.mjs`, `tools/support-matrix/merge.mjs`, `tools/support-matrix/SWEEP.md`, tests under `tests/` |
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
- `id` is a slug of vendor and product: lowercase, `+` spelled `plus`, runs of
  other non-alphanumerics collapsed to `-`, trimmed. Ids must stay stable
  because reports reference them.
- Descriptors with an identical vendor and product (seven pairs today, such as
  Oceanic OC1 at three model numbers) are one model to a diver. They merge into
  one entry whose `libdc` list is the union of their transports.
- Two different vendor and product pairs producing the same id is a hard error:
  the generator exits non-zero naming both, and an `idOverrides` entry keyed
  `"Vendor|Product"` is added by hand. One exists today: Subgear "XP Air"
  (Uwatec, IrDA) and "XP-Air" (Oceanic, serial), so `"Subgear|XP Air"` maps to
  `subgear-xp-air-irda`.
- `removed` lists ids that appeared in the previous `catalog.json` (passed in
  with `--previous`) but not in this one, so orphaned reports surface.
- `unsupported` lists models with no reachable family on any platform, for the
  page footnote. `reason` is `irda-only` (the IrDA-only models) or
  `raw-usb-only` (Atomic Aquatics Cobalt and Cobalt 2, see below).

### `support_matrix_platform_rules.json`

```json
{
  "ios": ["ble"],
  "android": ["ble", "serial"],
  "macos": ["ble", "serial", "usbhid"],
  "windows": ["ble", "serial", "usbhid"],
  "linux": ["ble", "serial", "usbhid"],
  "idOverrides": { "Subgear|XP Air": "subgear-xp-air-irda" }
}
```

libdc's raw `usb` flag (Atomic Aquatics Cobalt and Cobalt 2 only) is listed for
no platform. `HAVE_LIBUSB` is commented out in every platform's
`config/config.h`, and the download path (`libdc_download.c`) only ever opens a
custom serial, HID or BLE stream, so nothing can drive a raw USB bulk device.
The Android USB tab does advertise the Cobalt today; that is a follow-up, not a
capability.

### `reports.json` (curated by the sweep)

```json
{
  "watermarks": {
    "scubaboard": { "lastPostId": 10735581, "sweptAt": "2026-10-02" },
    "github": { "since": "2026-10-02T00:00:00Z" },
    "appStore": { "lastReviewId": "...", "sweptAt": "2026-10-02" }
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
  `git tag --contains <merge-sha>` on the fixing PR's merge commit, keeping
  only tags shaped `vX.Y.Z` or `vX.Y.Z.BUILD` (others such as `pre-rebase-228`
  exist) and recording the lowest as `X.Y.Z`. A fix merged after the newest
  tag gets `fixedIn: "unreleased"`.
- `note`: at most 120 characters, a paraphrase in our own words. No quoted post
  or review text.

Content rules: no usernames or display names anywhere in the data or on the
page. The link is the attribution.

### Cell status

A cell is one row (model and transport family) and one platform column:

1. The family is not in `catalog.models[].platforms[platform]`: **n/a**.
2. No reports for the cell: **Untested**.
3. Otherwise take the newest report, ordered by `appVersion` (numeric compare
   part by part; `null` sorts oldest), then `date`, then the weaker outcome
   (`fails` before `caveats` before `works`) so a same-day, same-version
   conflict never resolves to the better result:
   - `works`: **Verified**, but only if at least one `works` report for the cell
     has a linkable `url` (any source other than `app-store` or `play-store`).
     Otherwise **Issues**.
   - `caveats`: **Issues**.
   - `fails` with `fixedIn` set to a version newer than the report's
     `appVersion` (or the report has no version): **Issues**, labelled "fixed
     in vX, awaiting confirmation". A failure reported on the fixed version or
     later means the fix did not hold, so it stays **Not working**.
   - `fails` with `fixedIn: "unreleased"`: **Not working**, labelled "fix
     pending release".
   - `fails` otherwise: **Not working**.

Ordering by app version first stops a report from an old build outranking a
newer build's report just because it was posted later.

## 2. The page

`computers/index.html`, plain HTML and JS like the rest of the site, using the
dark visual system from `styles.css` and the same header and footer as
`privacy/`. It follows the passport pages' split: pure ES modules that
`node --test` imports (`status.js` for the cell rules, `rows.js` for rows,
search, filters and URL state, `render.js` for markup), and one browser glue
file (`page.js`) for fetching, events and deep links. It fetches both data
files from the same origin and computes every cell status in the browser;
`status.js` is the single implementation of the rules above.

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
   "App Store review"), then a "Report your result" link for that cell.
5. **Help fill the gaps**: points testers to the report form first, then the
   ScubaBoard thread and r/submersion, and asks for model, phone or computer
   OS, connection and app version in any report.
6. **Footer**: data provenance (app and libdc commits from `generatedFrom`) and
   the list of unsupported (IrDA-only) models.

Deep links: `/computers#<model-id>` scrolls to that model's rows and highlights
them. A fragment, not a path, so GitHub Pages needs no rewrite rules.

Below about 720 px the table becomes one card per row: the model with the
connection pinned to its right, then one "platform + status" pair per platform
in a grid of at least 140 px per pair (two per line on a phone; five worded
pills do not fit on one line). No horizontal scroll.

Text on the water takes its ink from the site's `ocean.js`, which inks only
children of `main .zone__inner`, so the intro, controls, help and footer sit in
`.zone__inner` blocks. The table sits outside them on its own dark panel with
fixed light text, and the legend pills carry the panel colour, so both read at
any depth.

### Reporting a result

The app repo gains an issue form, `.github/ISSUE_TEMPLATE/computer-report.yml`,
labelled `computer-report`. Its fields, by id (the ids are what a link
pre-fills):

| id | Type | Content |
|---|---|---|
| `model` | input, required | the catalog id and display name, e.g. `shearwater-perdix-3 (Shearwater Perdix 3)` |
| `platform` | dropdown, required | iOS, Android, macOS, Windows, Linux |
| `connection` | dropdown, required | Bluetooth, USB |
| `outcome` | dropdown, required | Downloaded dives; Downloaded with problems; Did not work |
| `app_version` | input, required | the Submersion version, e.g. 1.8.1 |
| `device` | input, optional | phone or computer model and OS version |
| `details` | textarea, optional | what happened |

A notice at the top says the report is public and asks for no personal
details.

`render.js` gains `reportUrl({ id, vendor, product, family, platform })`,
returning
`https://github.com/submersion-app/submersion/issues/new?template=computer-report.yml&labels=computer-report&title=...&model=...&connection=...&platform=...`,
URL-encoded, with `platform` omitted when not given. The title reads
"Computer report: Shearwater Perdix 3, Android, Bluetooth" (the platform part
dropped when absent). The page places it:

- on every row's model cell, with the model and connection filled in;
- in every cell's detail panel, with the platform filled in too;
- in "Help fill the gaps", as the blank form.

The links open in a new tab with `rel="noreferrer"`.

The homepage's `#computer` zone gains a "See which computers are verified" link
to the page.

## 3. Generator

`scripts/export_support_matrix_catalog.py`, standard library only, runnable on
Python 3.9 or later so it works in the cloud routine as well as locally.

- Parses `g_descriptors[]` entries
  (`{"Vendor", "Product", DC_FAMILY_..., model, DC_TRANSPORT_A | ..., filter}`)
  from `descriptor.c`. Every entry must parse: each opening brace outside a
  string literal (after comments are stripped) starts an entry, and one the
  parser cannot read, or a transport flag it does not know, fails the run
  naming the row. A model is never dropped silently.
- Reads `scripts/data/support_matrix_platform_rules.json`, which must be a JSON
  object listing every platform with known libdc transport names; each
  `idOverrides` value must itself be a lowercase-hyphen id.
- Optional `--previous <catalog.json>` to compute `removed`.
- Writes `catalog.json` to the path given by `--out` through a sibling
  `.partial` file swapped into place, so a failed write leaves the existing
  catalog whole (the sweep passes the same path as `--previous` and `--out`).
- Records the app and libdc submodule commits in `generatedFrom`.
- Any failure prints `error: ...` and exits 1. Two conditions warn without
  failing: an `idOverrides` key that matches no descriptor, and uncommitted
  changes to the generator or its rules (which the recorded `appCommit` does
  not contain).

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
- The generator refuses to write a catalog from fewer than `--min-descriptors`
  (default 300) parsed entries, a guard against a parser that silently matches
  nothing. CI's script-test job checks out without submodules, so the unit
  tests use fixture text copied from the real table's formats, and the real
  file is exercised by every generator run (the plan's manual run and each
  monthly sweep), where the guard fails loudly.

## 4. Sweep

### Sources

| Source | Initial scope | Monthly scope | Access |
|---|---|---|---|
| ScubaBoard thread 667061 | all 73 pages | pages after `lastPostId` | public fetch with curl |
| Report form (`computer-report` label) | every labelled issue | updated since `github.since` | gh REST; parsed field by field, not interpreted |
| GitHub issues | `device sync` label (81) plus full-text vendor-name search over all 1,181, comments included | updated since `github.since` | gh REST dumps grepped locally (search rate-limits) |
| GitHub PRs | merged device fixes | merged since `github.since` | gh REST; `fixedIn` via `git tag --contains` |
| GitHub discussions | all 36 | updated since `github.since` | gh REST (GraphQL is not available in the cloud routine) |
| Release notes (corroborate `fixedIn` only) | `docs/releases/` | new files | repo read |
| App Store | public customer-reviews RSS, every storefront | reviews newer than `lastReviewId` | no credentials; about the 500 most recent per storefront |

Google Play is not swept. Its reviews are readable only through the Play
Console's monthly export bucket, which needs a service account kept as a
routine secret, and the Play Developer API's `reviews.list` returns only the
last 7 days. The maintainer chose to leave Play out rather than run that
account.

Reddit r/submersion is not swept either. It rate-limited the initial sweep's
per-post fetches, and the first cloud run got HTTP 429 on its very first
request, so it would fail every month. The `reddit` source value stays valid
for a report added by hand.

### Initial sweep (one time)

A parallel agent fan-out: about 8 agents over the ScubaBoard pages (about 9
pages each), and one agent each for issues, PRs, discussions, release notes
and the App Store.
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
- a `note` exceeds 120 characters or contains an em dash;
- an `appVersion` or `fixedIn` is not dotted numbers (`fixedIn` may also be
  `"unreleased"`), or a `date` is not `YYYY-MM-DD`;
- a store-review report lacks a `sourceRef`, or any other report has one.

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
| 1 | app | generator, platform rules, tests, CI test-list entry, `computer-report` issue form (and the label, created on the repo with this PR) | `Refs #2616` |
| 2 | website | page and its modules, report links, validator, tests, generated `catalog.json`, empty `reports.json`, homepage link | none required |
| 3 | website | initial sweep results in `reports.json` | none required |
| 4 | website | `SWEEP.md`; the scheduled routine follows it | none required |
| 5 | app | `docs/guide/dive-computer.md` and `README.md` replace their tested lists and the Bluetooth Classic row with a link to the matrix | `Closes #2616` |

PR 5 touches only `docs/` and `README.md`, outside the UI paths, so it needs no
screenshots.

## Verification items

Settled while planning:

- libdc's raw `usb` flag is reachable on no platform (see the platform rules
  above). The Cobalts are `unsupported` with reason `raw-usb-only`.
- FTDI cables with custom PIDs (Oceanic `0x0403:0xF460`) on Windows and Linux
  depend on the OS driver, which the code cannot show. The platform-wide rule
  stays: the capability layer says what the app implements, and the evidence
  layer says what a diver's cable actually did. No per-model rule.

Still open, settled in the sweep-routine task:

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
