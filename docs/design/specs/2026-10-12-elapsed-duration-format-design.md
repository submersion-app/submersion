# Elapsed durations in days and years

Date: 2026-10-12
Status: approved design
Issue: #3119

## Problem

Surface intervals have no upper bound: a dive after a long break gets a
surface interval of thousands of hours. The Insights > Time patterns
"Surface Interval Statistics" card shows them as `157h 42m` and `6379h 45m`,
which nobody can read at a glance. The same hours-only shape is hand-rolled in
about eight other surface-interval displays, and a few other elapsed gaps
(photo distance from the nearest dive, GPS recorded time, "last dive N days
ago") have the same problem at the day level.

There is no shared duration formatter in `lib/`; every site formats its own
`${h}h ${m}m`.

## Goals

- An elapsed duration over 24 hours reads in days and hours, and over 365 days
  in years and days.
- One shared formatter replaces the hand-rolled copies in scope.
- Every in-scope screen that has `AppLocalizations` renders localized units.

## Non-goals

- Career and trip total-time aggregates (Insights total time, dive summary,
  trip runtime, PDF and Excel totals, dashboard "hours underwater"). Divers
  count these in hours underwater; they stay as they are.
- Equipment exposure "dive hours" (a service unit, not elapsed time).
- The surface-interval planner tool (capped at 6 hours), the no-fly and
  CNS/OTU countdowns (already under 48 hours or already day-aware).
- The capture-time correction slider (`formatSignedOffset`), which is a
  locale-independent knob by design.
- Backup age, course "days since start", service-due "in N days" and other
  day counters.
- Localizing `DiveFieldFormatter.formatValue`, which has 22 callers and no
  `AppLocalizations`.

## Format

Each tier shows its two largest units, always both, even when the second is
zero. The formatter cuts its input down to whole minutes
(`Duration.inMinutes`, as every site does today) and every tier below that is
integer division, so dropped units are cut off, never rounded up ("it has been
6d 13h" never overstates the time). A year is a fixed 365 days. The two
callers that hold fractional-minute averages (the Time patterns card and the
Focus metric) round to the nearest whole minute before calling, as the card
does today; cutting off whole seconds elsewhere keeps bottom time and runtime
in the dive table exactly as they render now.

| Input | Tier | en output |
| --- | --- | --- |
| under 60 min | minutes | `42 min` |
| under 24 h | hoursMinutes | `5h 12m` |
| under 365 d | daysHours | `6d 13h`, `2d 0h`, `265d 19h` |
| 365 d and up | yearsDays | `1y 35d`, `2y 0d` |

Rounding the whole average first also removes a latent `5h 60m` from the
current card, which rounds the remainder after flooring the hours.

Day counts (the dashboard "Last dive" chip and the "time since last dive"
observation) keep their current text under 365 days and switch to the
`yearsDays` form from 365 days on. They are never split into hours.

## Formatter

New file `lib/core/utils/elapsed_duration_format.dart`:

- `ElapsedSpan splitElapsed(Duration d)`: pure, no l10n. Returns the tier and
  its two values. Negative input is the caller's business (each caller keeps
  its own guard); the function treats it as zero.
- `String formatElapsed(AppLocalizations l10n, Duration d)`: localized
  renderer over the four `common_elapsed_*` keys.
- `String formatElapsedEnglish(Duration d)`: the same tiers with fixed English
  letters (`42min`, `5h 12m`, `6d 13h`, `1y 35d`), for code paths that have no
  `AppLocalizations` today and already print English letters.
- `String? formatElapsedDays(AppLocalizations l10n, int days)`: `null` under
  365 days, otherwise the localized `yearsDays` form.

## ARB keys

Added to all 11 locales, reusing each locale's existing unit letters (de `T`,
fr `j`, it `g`, nl `u`, hu `n`/`ó`/`p`, he, ar and zh in the style of their
current `safetyHub_cnsOtu_elapsedDaysHours` and
`insights_timePatterns_surfaceInterval_formatHoursMinutes`):

| Key | en |
| --- | --- |
| `common_elapsed_minutes` | `{minutes} min` |
| `common_elapsed_hoursMinutes` | `{hours}h {minutes}m` |
| `common_elapsed_daysHours` | `{days}d {hours}h` |
| `common_elapsed_yearsDays` | `{years}y {days}d` |
| `dashboard_gauges_lastDiveSpan` | `Last dive {span} ago` |
| `insights_observations_diveGapSpan` | `Your last dive was {span} ago` |
| `pdf_surfaceIntervalSpan` | `SI: {interval}` |

Keys left without a caller (expected:
`insights_timePatterns_surfaceInterval_formatHoursMinutes`,
`insights_timePatterns_surfaceInterval_formatMinutes`,
`pdf_surfaceIntervalShort`) are removed from every locale after a repo-wide
check that nothing else reads them.

## Call sites

Localized, via `formatElapsed`:

| Screen | Code |
| --- | --- |
| Insights > Time patterns, Surface Interval Statistics | `insights_time_patterns_page.dart` `_formatMinutes` |
| Insights Focus surface-interval metric (list, bars, thresholds) | `focus_metric_units.dart` `_hoursMinutes` |
| Dive detail "Surface Interval" row (two inline copies) | `dive_detail_page.dart` |
| Dive edit read-only surface-interval row | `dive_edit_page.dart` `_surfaceIntervalRow` |
| Combine-dives gap and merged durations | `combine_dives_dialog.dart` `_formatDuration` |
| Sync-conflict dialog duration fields | `conflict_field_format.dart` `formatConflictSeconds`, which gains an `l10n` parameter; the under-a-minute seconds branch and the negative path stay. Past a day it uses `formatElapsedExact` (`6d 13h 42m`, `1y 35d 5h`) so two differing versions never read the same (decided in review, with two more keys: `common_elapsed_daysHoursMinutes`, `common_elapsed_yearsDaysHours`) |
| Detailed PDF surface interval | `pdf_template_detailed.dart` `_duration` |
| NAUI PDF per-dive SI (today raw minutes) | `pdf_template_naui.dart`, via `pdf_surfaceIntervalSpan` |
| Photo review "{gap} after/before the nearest dive" | `file_review_card.dart` |

English letters, via `formatElapsedEnglish`:

| Screen | Code |
| --- | --- |
| Dive table/list column and cell-filter options | `dive_field_formatter.dart` `_formatDuration` (bottom time and runtime share it and never reach a day) |
| GPS track rows, last-fix age, Tracks "Recorded time" total | `track_row_labels.dart` `formatCompactDuration`, so the page keeps one style |

Day counts, via `formatElapsedDays`:

| Screen | Code |
| --- | --- |
| Dashboard "Last dive" chip | `gauge_strip.dart`, `dashboard_gauges_lastDiveSpan` from 365 days |
| "Time since last dive" observation | `observation_sentence.dart`, `insights_observations_diveGapSpan` from 365 days |

## Testing

- `splitElapsed` at 0, 59 min 59 s, 60 min, 23h59m, 24h, 364d23h59m, 365d
  and 730d, plus negative input; the card at an average of 59.6 min.
- `formatElapsed` rendered text in en and de (generated methods take
  placeholders in `@placeholders` order, so assert the string, not the call).
- `formatElapsedEnglish` at each tier; `formatElapsedDays` at 364 and 365.
- Widget test: the Time patterns card with a maximum of 6379h45m shows
  `265d 19h`.
- Existing tests that pin `157h 42m`, `42m` or `SI: Nmin` are updated.
- `test/architecture/`, `test/shared/` and the generated-l10n staleness check.

## Screenshots

Before and after: the Time patterns Surface Interval card, the dive detail
surface-interval row, and the dashboard "Last dive" chip if the dev database
has a gap of a year or more.
