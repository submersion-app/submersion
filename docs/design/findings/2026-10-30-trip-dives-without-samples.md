# Trip screens and sample decoding: what a trip cost to open

Date: 2026-10-30. Issue #3831.

## Summary

Every trip screen waited on `divesForTripProvider`, which read each dive through
the detail path: one full set of statements per dive, and every profile and
pressure series decoded, on screens that draw neither. On a 200-dive trip of
dense two-computer recordings that was 3,406 statements, 25 MiB of series and
four seconds before the Dives tab or the Overview could show anything.

The provider now reads through `DiveRepository.getDivesByIdsWithoutSamples`: 18
statements whatever the size of the trip, no series read, and about 20 ms. The
statement count no longer grows with the trip.

## Measurements

`test/performance/trip_dives_benchmark_test.dart`, on one Mac, medians of five
runs per path. Each dive is an hour at one sample a second from each of two
computers, plus two cylinders' pressure series at one sample every two seconds.
That is a deliberately dense recording, so these are the upper end: a computer
sampling every 10 seconds costs a tenth of the decoding.

"Before" is the provider's old body put back through an override. Both paths run
the real providers against a database file.

| Dives | Statements | Series read | Profile points held | Dives tab | Overview |
| --- | --- | --- | --- | --- | --- |
| 10 | 176 → 18 | 1,276 KiB → 0 | 72,000 → 0 | 374 → 10 ms | 229 → 16 ms |
| 50 | 856 → 18 | 6,380 KiB → 0 | 360,000 → 0 | 923 → 10 ms | 982 → 14 ms |
| 200 | 3,406 → 18 | 25,520 KiB → 0 | 1,440,000 → 0 | 4,005 → 19 ms | 4,073 → 23 ms |

"Series read" is the blob bytes across the trip's series. Profile points held is
the allocation figure: the points that stayed in memory on the returned dives
for as long as the provider cached them. Dart gives no per-call allocation
counter, so this counts what was retained and not everything that was
allocated along the way.

Time is to the provider's value, the moment a screen has what it needs. The
timings run SQLite on the test isolate, not on the app's background isolate, and
are not from a phone. The statement and byte columns hold on any device; read
the milliseconds as a ratio.

The 10-dive Overview reads lower than its Dives tab. The benchmark reads the Dives
tab first, which may warm the page cache, but that was not measured.

## The rows were not metadata only

The issue took the Overview's rows to be metadata, and the Dives tab's are. The
Overview's are not: `TripStoryDayCard` and `TripDayMapPage` pass the whole `Dive`
to `DiveListItem`, whose configurable card can show SAC, RMV, gas consumed, start
and end pressure, total weight, runtime and water temperature. A plain batched
read would have blanked or changed those on any dive that depended on a fallback.

The detail read and the batched read `getAllDives` already had differ in five
places, found by diffing the mappers. The new read starts from that batched read
and closes each gap, which the next section describes:

| Value | Detail read (`_mapRowToDive`) | `getAllDives` batched read |
| --- | --- | --- |
| Water temperature | the row, else the coldest plausible sample | the row |
| Tank start and end pressure | the row, else the pressure series | the row |
| `profile` | decoded, and step 3 of `effectiveRuntime` | empty |
| Weights | loaded | empty |
| Buddies | empty, `withBuddies` adds them | loaded |

No trip surface reads `profile` itself. That was checked across the Dives tab,
the Overview, the itinerary, the day map, the gallery, the site header, the photo
and Lightroom scans and the assignment dialog.

## How the values stay the same

`getDivesByIdsWithoutSamples` asks one blob-free question first: which of these
dives leave a shown value to their samples? `_diveIdsNeedingSamples` answers it
from the row, `dive_tanks` and the existence of a series. Those dives go through
`_mapRowToDive` on their own; the rest go through the batched read with weights
added. There is no second copy of the fallback logic to drift, and no new field
on `Dive`.

A dive that needs samples costs what it always did. How often that happens is
what makes this cheap:

| Library | Dives | Need samples | Why |
| --- | --- | --- | --- |
| A live logbook | 36 | 0 | |
| A larger backup | 1,542 | 5 | all five for water temperature |

The larger backup averages 49 samples a series, so it looks mostly synthetic:
treat it as a rough signal. A trip where every dive lacks a water temperature
gains little, and pays no more than before.

Each arm of the routing query needs a series behind the gap, so a hand-logged dive
with no water temperature stays on the batched read. Its values would be right
either way, which is why a mutation check found the first version of the tests
could not see it: only a statement count can.

## Not done

- **A new lightweight type.** `DiveFieldExtractor` and `DiveListItem` take a
  `Dive`, so a separate type would mean rewriting both for no gain in what is read.
- **Decoding on an isolate.** Decoding nothing beats decoding elsewhere.
- **A stored summary.** `dive_sensor_summaries.min_temperature` could answer the
  water temperature arm without a decode, but it is a device-local cache rebuilt by
  sweep, and the arm is rare enough not to need it.
