# Release download metrics

This orphan branch holds nothing but `download_counts.csv`, a time series of
GitHub release asset download counts. It shares no history with `main` and is
written only by the `Download Metrics` workflow
(`.github/workflows/download-metrics.yml`), which runs
`scripts/download_metrics.py` once a day.

The branch exists because GitHub reports `download_count` as a single lifetime
integer per asset, with no history and no way to ask what a count was last
week. Recording it daily is the only way to get trend data, and keeping those
commits off `main` stops a daily bot commit from churning the source history
and re-triggering CI.

## Schema

| Column | Meaning |
| --- | --- |
| `captured_at` | UTC date (`YYYY-MM-DD`) the count was read |
| `tag_name` | Release tag the asset belongs to |
| `published_at` | When that release was published |
| `prerelease` | `true` for beta/rc releases |
| `asset_name` | Uploaded asset filename |
| `asset_kind` | Platform bucket, e.g. `macos-dmg`, `updater-feed` |
| `download_count` | Lifetime downloads as of `captured_at` |
| `size_bytes` | Asset size |

## Rows are recorded only when a count changes

Appending every asset daily would add roughly 560 rows a day and grow without
bound. A row is written only when that asset's count differs from the last one
recorded for it, so **a value holds until the next row for the same
`(tag_name, asset_name)`**. Reconstruct a dense series by forward-filling.

Daily downloads are the difference between consecutive rows of one series:

```bash
# Downloads per day for the macOS installer of a given release.
awk -F, -v tag=v1.7.7.8077 \
  '$2==tag && $6=="macos-dmg" {if (prev!="") print $1, $7-prev; prev=$7}' \
  download_counts.csv
```

## Reading the numbers

- **These are downloads, not people.** No unique-user or IP dedup, so
  re-downloads, CI jobs and mirrors all count. GitHub filters some known
  crawlers, but not reliably.
- **`appcast.xml` is not an install.** It is the Sparkle updater feed, fetched
  on every update check, and it accounts for over half of all recorded
  downloads. It is bucketed as `updater-feed` and excluded from the installer
  total. It is a better proxy for *active installs* than for new ones.
- **Source tarball/zipball downloads are invisible.** GitHub counts uploaded
  assets only.
- **A count can go down.** Deleting and re-uploading an asset resets it to zero.
- **History starts when this branch does.** Everything before the first
  `captured_at` is a single lifetime total with no way to break it down.

## Running it by hand

```bash
python3 scripts/download_metrics.py --csv download_counts.csv
python3 scripts/download_metrics.py --csv download_counts.csv --full  # record every asset
```
