# Download metrics

Machine-written download counts for Submersion, saved once a day by
`.github/workflows/download-metrics.yml` on `main`. This branch shares no
history with `main`.

- `downloads/YYYY/MM/YYYY-MM-DD.json`: every release file's count on that day.
- `downloads/summary.json`: the file submersion.app reads.

The counts are installer fetches, so they include app updates. App Store and
Google Play installs are not counted.
