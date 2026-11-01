# Public Download Count

Status: design for review, 2026-11-01

## Intent

Anyone visiting `submersion.app` should be able to gauge how popular Submersion
is. GitHub keeps a download counter on every release file, but it only exposes
running totals through its API, with no history. This work collects those
counters daily and shows them publicly, labelled honestly for what they are.

This phase covers GitHub only. App Store and Google Play numbers are a separate
follow-up.

## Goals

- A quiet line under the download button on the home page reads
  "11,452 downloads from GitHub" (live figure) and links to a new page.
- A new page at `submersion.app/downloads/` shows the total, a platform
  breakdown, recent releases and a trend over time.
- A daily job saves per-file counts, so history builds up from the first run.

## Non-goals

- App Store and Google Play installs (follow-up).
- Unique users, geography or referrers. GitHub does not expose them.
- A README badge or any display inside the app.
- The `beta-builds` repo.
- Reconstructing history from before the first snapshot.

## Anti-goals

These would make the work a failure even if it technically functioned:

- Calling the number "users", "installs" or "people". It counts file fetches,
  including app updates and some automated fetches.
- Showing the raw API total. Over half of it is `appcast.xml`, which is the
  updater polling for new versions.
- Showing an invented, estimated or placeholder number.
- Adding analytics or tracking to the website.
- Making visitors' browsers walk the GitHub API. Anonymous requests are limited
  to 60 an hour per IP address, and the existing request reads only the first
  30 of 59 releases.

## Decisions Made By The Maintainer

- The number is public and is a popularity gauge.
- GitHub only for now, stores as a follow-up.
- Placement: the quiet line under the download button (mockup option A).
- Breakdown: its own page linked from that line (mockup option B), with
  platform, recent releases and trend.
- Snapshots live on an orphan `metrics` branch in
  `submersion-app/submersion`.
- Snapshots keep per-file counts.
- As played back and accepted: the counting rules, including counting
  prereleases; the website reading a summary file from the `metrics` branch; and
  hiding the number whenever the data is unavailable.

## Approved Mockups

Saved beside this document in `2026-11-01-public-download-count-mockups/`:

- `placement.html`: option A is the approved home page line.
- `breakdown.html`: option B is the approved `/downloads/` page.

They are HTML fragments for review, not production markup. Their figures were
real on 2026-11-01. Where they differ from this document, this document wins,
including the trend placeholder wording.

## What Counts

Applied to non-draft releases in `submersion-app/submersion`, matching file
names case-insensitively by suffix:

| Platform | Suffixes |
| --- | --- |
| macOS | `.dmg` |
| Windows | `.exe` |
| Android | `.apk` |
| Linux | `.tar.gz`, `.deb`, `.rpm` |

Prereleases in this repo count toward the total (143 today). Everything else is
excluded: `appcast.xml`, `.aab`, `.ipa`, checksums, `release-notes.html`, and the
`demo-data` release's `.zip` and `.json` files.

Reference figures from 2026-11-01: total 11,452, made up of macOS 7,271,
Android 2,028, Windows 1,537 and Linux 616. Use these to check the classifier
against a live run, allowing for growth since that date.

The job authenticates, so the API returns drafts too. Drafts must be filtered
out explicitly.

## Data Flow

```
GitHub releases API
        |  daily scheduled job on main
        v
metrics branch: per-file snapshot + summary.json
        |  browser fetch, raw.githubusercontent.com
        v
submersion.app home line and /downloads/ page
```

Confirmed on 2026-11-01: `raw.githubusercontent.com` sends
`access-control-allow-origin: *` with `cache-control: max-age=300`, and the site
sets no content security policy. The `metrics` branch matches no active ruleset
or branch protection, and is not targeted by `ci.yaml`.

## Collector (`submersion-app/submersion`)

- A new workflow in `.github/workflows/` runs daily and on
  `workflow_dispatch`. Scheduled workflows only run from the default branch, so
  this lands through a normal PR to `main`.
- The repo's default token is read-only, so the workflow must declare
  `permissions: contents: write`.
- A new Python script in `scripts/`, standard library only, with a
  `<name>_test.py` beside it, run from `ci.yaml` like the other script tests.
  CI treats `.github/*` as inert but not `scripts/*`, so a PR touching both runs
  the full pipeline. That is expected.
- The first run creates the orphan branch with a short `README.md` explaining
  what the branch is. Later runs add to it.
- A failed or incomplete fetch fails the job and writes nothing. The script must
  read every page of releases.

### Files on the `metrics` branch

```
README.md
downloads/YYYY/MM/YYYY-MM-DD.json   one full per-file snapshot per UTC day
downloads/summary.json              the one file the website reads
```

A daily snapshot is a full per-file record, about 30 KB. The earlier idea of
storing only the changes is dropped: git already compresses near-identical
files well, and full files are simpler to read and repair. A rerun on the same
UTC day overwrites that day's file.

### `summary.json` contract

This is the interface between the two repos.

```json
{
  "schema": 1,
  "generated_at": "2026-11-01T04:17:00Z",
  "total": 11452,
  "platforms": { "macos": 7271, "android": 2028, "windows": 1537, "linux": 616 },
  "recent_releases": [
    { "tag": "v1.8.3.9095", "published_at": "2026-10-26T00:00:00Z", "downloads": 317 }
  ],
  "history": [
    { "date": "2026-11-01", "total": 11452,
      "platforms": { "macos": 7271, "android": 2028, "windows": 1537, "linux": 616 } }
  ]
}
```

- `recent_releases`: the four newest non-prerelease, non-draft releases that
  have at least one counted file, newest first.
- `history`: one entry per snapshot, oldest first. It is rebuilt from the
  snapshot files, so a hand-corrected snapshot flows through on the next run.
- Missed days simply have no entry. Counters are cumulative, so a gap widens one
  interval and loses nothing.
- The total can fall if a release is deleted, because its counts go with it.
  Publish the true figure and emit a workflow warning.

## Website (`submersion-app/submersion-website`)

The site is static HTML, CSS and JavaScript on GitHub Pages, deployed from
`main`, with no build step and no dependencies beyond Google Fonts. Tests run
with `node --test tests/*.test.mjs`. Follow the `computers/` feature as the
pattern: `index.html`, `page.css`, a `page.js` entry point and separate
render modules that tests can import.

### Home page line

- Sits directly under `#download-primary` in `index.html`, above the store
  badges, using the site's existing water and ink tokens.
- Text: "11,452 downloads from GitHub", number emphasised, linking to
  `/downloads/`. Show the exact number, formatted with `en-US` separators.
- Hidden by default and revealed only once valid data arrives, so there is no
  empty flash, and nothing shows without JavaScript.
- Loads independently of the existing release lookup, so a failure in either one
  cannot affect the other or delay the download button.

### `/downloads/` page

- Matches the site's other subpages: header, ocean background, canonical URL and
  Open Graph tags.
- Shows the total, the label "downloads from GitHub, including app updates", and
  a line saying App Store and Google Play installs are not counted.
- By platform: macOS, Android, Windows, Linux, using the mockup's order.
- Recent releases: show the tag without its build number, so
  `v1.8.3.9095` reads as `v1.8.3`.
- Trend: cumulative total as an inline SVG line, with real dates on the time axis
  so gaps are not hidden, and a text alternative for screen readers.
- Until the placeholder threshold is reached, the trend area shows exactly:
  "The trend will appear here once a few weeks of daily snapshots have built up.
  GitHub keeps no history, so it starts from the first snapshot."
- Shows the date the numbers were last updated.

### Failure behaviour

Treat data as unavailable if the fetch fails or times out, the JSON is malformed,
`schema` is not 1, the numbers are invalid, or `generated_at` is more than 7 days
old.

- Home page: the line stays hidden.
- Page: a short "numbers aren't available right now" message, with a link to the
  GitHub releases page. Stale or partial figures are never shown.

All values are written with `textContent`, never as HTML.

## Delivery Order

1. Open an issue in `submersion-app/submersion`. Its PR must say `Closes #N`
   (the "PR Issue Link" check blocks the merge otherwise).
2. Merge the collector, run it once by hand and confirm the live total against
   the reference figures.
3. Build the website PR against the live `summary.json`. It is safe to merge at
   any time because of the failure behaviour, but merging after step 2 lets it
   be checked for real. The PR needs screenshots of the home line and the page.
4. File the App Store and Google Play follow-up as its own issue.

## Testing

- Collector, from fixtures of the releases API response: suffix classification
  including `.tar.gz` versus other `.gz`, draft filtering, prerelease counting,
  the `demo-data` release, reading every page, same-day overwrite, `history` built
  from several snapshots, `recent_releases` selection, a falling total, and a
  failed fetch writing nothing.
- Website, with `node --test`: rendering from a fixture, number and tag
  formatting, each unavailable case, and the placeholder threshold.

## Left To The Builder

- Workflow and script names, and the cron time. Avoid the top of the hour.
- The commit message format on `metrics`, within the repo's attribution rules.
- CSS details, within the approved mockups and the site's tokens.
- The trend placeholder threshold. The suggested value is 14 snapshots.
- How and whether the page's Open Graph text mentions the number.

## Calls Made During Design

These are final unless the maintainer changes them when reviewing this document.
None of them were played back during the design conversation:

- Full daily snapshots instead of change-only files.
- A 7-day limit before data counts as stale.
- `summary.json` replaces the previously suggested `downloads/latest.json`.
- `/downloads/` is reached from the home line only, with no new item in the top
  navigation.
- Prereleases count toward the total but are not listed under recent releases.
- The trend placeholder wording above.
