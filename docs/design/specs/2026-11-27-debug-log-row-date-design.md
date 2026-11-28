# Debug log rows show the date (#4993)

## Intent

The debug log viewer (Settings > Debug logs, also reachable from Settings >
About > Diagnostics) shows each entry's time as `HH:mm:ss.SSS` with no date.
The list is newest first, so a log that spans more than one day reads out of
order: a `07:29 Session start` sits above a `17:45 Sync failed` from the day
before, and nothing on screen says so. The reporter asked for the date.

The log file already stores the full local timestamp
(`[2026-11-24T07:29:22.932] [APP] [INFO] ...`), and Copy, Save and Share
already export it in full. Only the on-screen row drops the date.

## Goals

- Every row in the viewer shows the calendar date of its entry.
- The date follows the diver's date format setting, like every other date in
  the app.

## Non-goals

- No change to the log file format, the export header, or what Copy, Save and
  Share produce.
- No grouping, filtering or jumping by day.

## Approaches considered

| Approach | Trade-off |
| --- | --- |
| Day headers (a divider row when the day changes) | Rows keep full message width; a row read on its own has no date. |
| Inline date on every row (chosen) | Each row is complete on its own; on a phone the message column loses about 11 characters and wraps sooner. |
| Two-line stamp (date above the time) | No width cost; every row grows taller. |

The maintainer chose the inline date on every row.

## Design

- `LogEntryTile`'s stamp becomes `<date> HH:mm:ss.SSS`.
- The date comes from `UnitFormatter.formatDate`, so it follows
  `DateFormatPreference` (for example `24/11/2026` for `DD/MM/YYYY`).
- The time keeps its fixed 24-hour `HH:mm:ss.SSS` form whatever the diver's
  time format, because millisecond ordering is the point of a debug log.
- `LogEntryTile` becomes a `ConsumerWidget` and reads `unitFormatterProvider`.
- The two month-name formats (`MMM D, YYYY`, `D MMM YYYY`) produce dates of
  varying width, so message columns do not align exactly from row to row under
  them. Accepted: following the diver's setting was preferred over a fixed ISO
  date.

## Tests

- The tile shows the date in the diver's format, under a digit format and a
  month-name format, followed by the millisecond time.
- Two entries on different days show different dates.
- Existing tile tests keep passing under a `ProviderScope`.
