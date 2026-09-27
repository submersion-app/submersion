# Tide Site Time and Offline Grid Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make tide predictions for dives correct in the dive site's local time, and replace the 1-degree offline FES2022 grid with an 11 km coastal grid.

**Architecture:** A new `SiteTimeZone` unit (a vendored CC0 tz-lookup quadtree plus the bundled `timezone` tzdata) converts dive wall-clock times to real instants before they reach the harmonic engine, and converts the engine's instants back to site wall-clock before display. The offline grid becomes a binary asset (a manifest, a 1-degree global layer, and 0.1-degree coastal tiles) written by a numpy extraction script and read by a new `FesGridReader` that interpolates in the complex plane.

**Tech Stack:** Flutter/Dart, Riverpod, `package:timezone` 0.11.0, Python 3.14 with `numpy` and `netCDF4` (extraction only), node (fixture generation only).

**Spec:** `docs/superpowers/specs/2026-09-26-tide-site-time-and-grid-design.md`

## Global Constraints

- Never write an em-dash, or an en-dash or double hyphen used as punctuation, in any file, comment, commit message or PR text.
- No commit, PR, issue or comment text may mention Claude, Claude Code or Anthropic. No `Co-Authored-By` trailers.
- Test paths are built with `p.join(...)` (`package:path/path.dart as p`), never with a literal `/`.
- Imports are grouped: dart, flutter, packages, local.
- Distances shown to the diver go through `UnitFormatter.formatGeoDistance` so they follow unit settings.
- Run `dart format .` at the end of every task, before committing.
- System `python3` is 3.9; use `python3.14`. The extraction needs a venv with `numpy` and `netCDF4` (see Task 8).
- The Bash tool refuses a command containing a bare `build` word; use `./scripts/setup.sh` for code generation.
- tz-lookup is pinned to commit `6051e7e2fe8b754e23d40aff0120cf9b38bde608` (CC0-1.0).
- FES2022b source data lives at `~/repos/fes2022b/ocean_tide_extrapolated` (34 `*_fes2022.nc` files plus `mask_fes2022B.nc`).
- Grid constituent order, exactly: `M2, S2, N2, K2, 2N2, Mu2, Nu2, L2, T2, Eps2, La2, R2, K1, O1, P1, Q1, J1, Mf, Mm, Ssa, Sa, Msqm, Mtm, M4, MS4`.
- The August NOAA golden tests in `test/core/tide/tide_golden_test.dart` and the M2 period regression must pass unmodified.
- Stage explicit paths only (never `git add -A` or `git add -u`).

## Review Focus

1. A dive whose stored entry time is a local (non-UTC) `DateTime` with the same digits must convert to the same instant as the wall-clock-as-UTC value. Pinned in Task 2.
2. Sites on or near the antimeridian (Fiji, Tonga) must get the right zone and the grid must wrap in longitude. Pinned in Task 1 (parity fixture rows at longitude plus and minus 180), Task 2 (Fiji conversion) and Task 7 (wrap sample).
3. A salt-water site geocoded far inland must show "no tide data", not crash or return garbage. Pinned in Task 8 (a Sahara point returns null from the bundled grid).
4. On the site page, "Today" and "Tomorrow" in the tide table must be judged in site time, so `now` handed to the table must be the site's wall-clock, not the device's. Pinned in Task 5.
5. Self-heal must converge: after one overwrite, viewing the dive again must not rewrite the record. Pinned in Task 4.

Deviations from the spec, flagged for review:

- The accuracy test's time tolerance is 12 minutes, not 10. The worst measured site was 9 minutes using 8 constituents; the test uses 25, so 12 leaves headroom. Two sites carry a documented wider time limit (Vieques 40 minutes, a near-flat tide whose height error is 0.7 cm; Maldives 15 minutes, which falls back to the global layer). Every site keeps the 5 cm height limit.
- `tideStatusForDive` gains a synchronous twin, `tideStatusForDiveSync`, because the dive detail page computes an uncached fallback inside `build`.
- The extraction script writes the accuracy vectors in the same pass as the assets instead of behind a `--vectors` flag, because the vectors need the same full native arrays.

---

### Task 0: Workspace readiness

**Files:** none changed.

- [ ] **Step 1: Initialize the worktree**

Run:
```bash
git submodule update --init --recursive
flutter pub get
./scripts/setup.sh
```
Expected: codegen completes without errors. (This worktree's generated Drift code is stale; without codegen every test fails to load on `cloudAssetId`.)

- [ ] **Step 2: Baseline the tide tests**

Run:
```bash
flutter test test/core/tide test/features/tides test/features/dive_log/presentation/pages/dive_detail_tide_card_test.dart
```
Expected: all pass. If anything fails here, stop and report; do not start Task 1 on a red baseline.

---

### Task 1: Zone lookup (vendored tz-lookup)

**Files:**
- Create: `scripts/tide/generate_tz_lookup_data.py`
- Create: `scripts/tide/generate_tz_lookup_fixture.js`
- Create (generated): `lib/core/util/tz_lookup_data.dart`
- Create: `lib/core/util/site_time_zone.dart`
- Create (generated): `test/core/util/fixtures/tz_lookup_parity.json`
- Create: `test/core/util/site_time_zone_test.dart`

**Interfaces:**
- Produces: `abstract final class SiteTimeZone` with `static String zoneIdFor(double latitude, double longitude)`. Later tasks add conversions to the same class.
- Produces: `const String tzLookupData`, `const List<String> tzLookupZones` in `tz_lookup_data.dart`.

- [ ] **Step 1: Write the data generator**

Create `scripts/tide/generate_tz_lookup_data.py`:

```python
#!/usr/bin/env python3
"""Generate lib/core/util/tz_lookup_data.dart from photostructure/tz-lookup.

tz-lookup (CC0-1.0) maps a coordinate to an IANA zone id with a compact
quadtree. This script downloads tz.js at a pinned commit, checks that the
decoder constants still match the Dart port in
lib/core/util/site_time_zone.dart, and writes the quadtree string and zone
list as Dart constants.

Usage (from the repo root):
    python3.14 scripts/tide/generate_tz_lookup_data.py
"""

import json
import re
import urllib.request
from pathlib import Path

COMMIT = "6051e7e2fe8b754e23d40aff0120cf9b38bde608"
URL = f"https://raw.githubusercontent.com/photostructure/tz-lookup/{COMMIT}/tz.js"
OUT = Path("lib/core/util/tz_lookup_data.dart")

# Constants baked into the Dart decoder. If upstream changes any of them the
# port must change too, so fail loudly instead of emitting mismatched data.
REQUIRED_SNIPPETS = [
    "48*(180+W)/360.00000000000006",
    "24*(90-Y)/180.00000000000003",
    "K=96*$+2*Z",
    "-1995",
    "K+T.length<3136",
    "+2304)",
]


def extract_js_string(src: str, start: int) -> tuple[str, int]:
    """Decode the double-quoted JS string literal that starts at src[start]."""
    if src[start] != '"':
        raise SystemExit("tz.js changed: data string not found")
    end = start + 1
    while src[end] != '"':
        end += 2 if src[end] == "\\" else 1
    return json.loads(src[start : end + 1]), end + 1


def dart_literal(text: str) -> str:
    escaped = text.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")
    return "'" + escaped + "'"


def main() -> None:
    req = urllib.request.Request(URL, headers={"User-Agent": "submersion"})
    with urllib.request.urlopen(req, timeout=60) as response:
        src = response.read().decode("utf-8")

    for snippet in REQUIRED_SNIPPETS:
        if snippet not in src:
            raise SystemExit(f"tz.js changed: missing decoder snippet {snippet!r}")

    data, after = extract_js_string(src, src.index('var X="') + len("var X="))
    zones_match = re.search(r"T=(\[[^\]]*\])", src[after:])
    if zones_match is None:
        raise SystemExit("tz.js changed: zone list not found")
    zones = json.loads(zones_match.group(1))
    if any(not (32 <= ord(ch) < 127) for ch in data):
        raise SystemExit("tz.js data has non-printable characters")

    chunks = [data[i : i + 70] for i in range(0, len(data), 70)]
    lines = [
        "// GENERATED by scripts/tide/generate_tz_lookup_data.py. Do not edit.",
        "//",
        "// Quadtree and zone list from photostructure/tz-lookup at commit",
        f"// {COMMIT}.",
        "// The upstream authors released this data under CC0-1.0.",
        "",
        "/// Quadtree nodes: pairs of characters read as base-56 integers.",
        "const String tzLookupData =",
        *[f"    {dart_literal(chunk)}" for chunk in chunks[:-1]],
        f"    {dart_literal(chunks[-1])};",
        "",
        "/// IANA zone ids addressed by the quadtree leaves.",
        "const List<String> tzLookupZones = [",
        *[f"  {dart_literal(zone)}," for zone in zones],
        "];",
        "",
    ]
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {len(data)} data chars and {len(zones)} zones to {OUT}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Write the parity fixture generator**

Create `scripts/tide/generate_tz_lookup_fixture.js`:

```js
// Writes test/core/util/fixtures/tz_lookup_parity.json: coordinates and the
// zone ids that upstream tz.js returns for them. The Dart port in
// lib/core/util/site_time_zone.dart must match every row.
//
// Usage (from the repo root, node 18 or newer):
//   node scripts/tide/generate_tz_lookup_fixture.js
'use strict';

const fs = require('fs');
const https = require('https');
const os = require('os');
const path = require('path');

const COMMIT = '6051e7e2fe8b754e23d40aff0120cf9b38bde608';
const URL = `https://raw.githubusercontent.com/photostructure/tz-lookup/${COMMIT}/tz.js`;
const OUT = path.join('test', 'core', 'util', 'fixtures', 'tz_lookup_parity.json');

// Public dive sites and time zone edge cases.
const NAMED = [
  ['Bonaire', 12.15, -68.27],
  ['Cozumel', 20.35, -87.03],
  ['San Juan station', 18.458944, -66.11642],
  ['Vieques', 18.10, -65.47],
  ['Santa Cruz', 36.95, -122.02],
  ['San Francisco station', 37.8063, -122.4659],
  ['Monterey', 36.62, -121.90],
  ['Sydney', -33.86, 151.21],
  ['Adelaide', -34.93, 138.60],
  ['Koh Tao', 10.10, 99.84],
  ['Tulamben', -8.27, 115.59],
  ['Komodo', -8.55, 119.55],
  ['Gili', -8.35, 116.04],
  ['Raja Ampat', -0.55, 130.55],
  ['Cornwall', 50.07, -5.70],
  ['Silfra', 64.26, -21.12],
  ['Nanaimo', 49.17, -123.94],
  ['Sharm el Sheikh', 27.85, 34.32],
  ['Cairns', -16.75, 145.98],
  ['Malta', 36.05, 14.19],
  ['Tenerife', 28.05, -16.73],
  ['Sipadan', 4.11, 118.63],
  ['Galapagos', -0.75, -90.30],
  ['Roatan', 16.33, -86.53],
  ['Maldives', 4.18, 73.52],
  ['Blue Hole', 17.32, -87.53],
  ['Eilat', 29.53, 34.93],
  ['Fiji Beqa', -18.40, 178.10],
  ['Tonga', -18.65, -174.0],
  ['Scapa Flow', 58.90, -3.20],
  ['Chuuk', 7.42, 151.78],
  ['Palau', 7.13, 134.22],
  ['Open Atlantic', 30.0, -40.0],
  ['Open Indian Ocean', -30.0, 100.5],
  ['North pole', 90.0, 0.0],
  ['South pole', -90.0, 0.0],
  ['Antimeridian east', -18.4, 180.0],
  ['Antimeridian west', -18.4, -180.0],
];

function fetch(url) {
  return new Promise((resolve, reject) => {
    https
      .get(url, { headers: { 'User-Agent': 'submersion' } }, (res) => {
        if (res.statusCode !== 200) {
          reject(new Error(`HTTP ${res.statusCode} for ${url}`));
          return;
        }
        let body = '';
        res.setEncoding('utf8');
        res.on('data', (chunk) => {
          body += chunk;
        });
        res.on('end', () => resolve(body));
      })
      .on('error', reject);
  });
}

async function main() {
  const source = await fetch(URL);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'tzlookup-'));
  const file = path.join(dir, 'tz.js');
  fs.writeFileSync(file, source);
  const tzlookup = require(file);

  const points = [...NAMED];
  for (let lat = -75; lat <= 75; lat += 15) {
    for (let lon = -180; lon <= 180; lon += 20) {
      points.push([`grid ${lat},${lon}`, lat, lon]);
    }
  }
  const rows = points.map(([name, lat, lon]) => ({ name, lat, lon, zone: tzlookup(lat, lon) }));
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(
    OUT,
    JSON.stringify({ source: `photostructure/tz-lookup@${COMMIT}`, points: rows }, null, 1) + '\n',
  );
  console.log(`Wrote ${rows.length} points to ${OUT}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
```

- [ ] **Step 3: Generate the data file and the fixture**

Run:
```bash
python3.14 scripts/tide/generate_tz_lookup_data.py
node scripts/tide/generate_tz_lookup_fixture.js
```
Expected: `Wrote 65016 data chars and 436 zones to lib/core/util/tz_lookup_data.dart` and `Wrote 247 points to test/core/util/fixtures/tz_lookup_parity.json`.

- [ ] **Step 4: Write the failing test**

Create `test/core/util/site_time_zone_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/util/site_time_zone.dart';

void main() {
  group('SiteTimeZone.zoneIdFor', () {
    final fixture =
        json.decode(
              File(
                p.join('test', 'core', 'util', 'fixtures', 'tz_lookup_parity.json'),
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final points = (fixture['points'] as List).cast<Map<String, dynamic>>();

    test('matches upstream tz.js at every fixture point', () {
      expect(points.length, greaterThan(200));
      for (final point in points) {
        expect(
          SiteTimeZone.zoneIdFor(
            (point['lat'] as num).toDouble(),
            (point['lon'] as num).toDouble(),
          ),
          point['zone'],
          reason: '${point['name']} (${point['lat']}, ${point['lon']})',
        );
      }
    });

    test('invalid coordinates fall back to a longitude zone', () {
      expect(SiteTimeZone.zoneIdFor(95.0, -68.0), 'Etc/GMT+5');
      expect(SiteTimeZone.zoneIdFor(10.0, 200.0), 'Etc/GMT-12');
      expect(SiteTimeZone.zoneIdFor(double.nan, double.nan), 'Etc/GMT');
    });
  });
}
```

- [ ] **Step 5: Run the test to verify it fails**

Run: `flutter test test/core/util/site_time_zone_test.dart`
Expected: FAIL to load with `site_time_zone.dart` not found.

- [ ] **Step 6: Implement `zoneIdFor`**

Create `lib/core/util/site_time_zone.dart`:

```dart
import 'package:submersion/core/util/tz_lookup_data.dart';

/// Offline mapping from a coordinate to its local clock.
///
/// Dive times are stored as wall-clock-as-UTC (see `wall_clock_utc.dart`),
/// but tide predictions need real instants. The zone for a coordinate comes
/// from a quadtree ported from photostructure/tz-lookup (data in
/// `tz_lookup_data.dart`, generated by
/// `scripts/tide/generate_tz_lookup_data.py`).
abstract final class SiteTimeZone {
  /// IANA zone id for the coordinate. Never throws: open ocean yields an
  /// `Etc/GMT` zone from the data itself, and coordinates outside the valid
  /// range yield the `Etc/GMT` zone for their longitude.
  static String zoneIdFor(double latitude, double longitude) {
    final valid =
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
    if (!valid) return etcZoneForLongitude(longitude);
    if (latitude >= 90) return 'Etc/GMT';

    // Port of tzlookup() in tz.js. Variable names follow the original:
    // s/z track the column, u/d the row, k the node offset, v the level base.
    var v = -1;
    var s = 48 * (180 + longitude) / 360.00000000000006;
    var u = 24 * (90 - latitude) / 180.00000000000003;
    var z = s.toInt();
    var d = u.toInt();
    var k = 96 * d + 2 * z;
    k = 56 * tzLookupData.codeUnitAt(k) + tzLookupData.codeUnitAt(k + 1) - 1995;
    while (k + tzLookupZones.length < 3136) {
      v = v + k + 1;
      u = 2 * (u - d) % 2;
      d = u.toInt();
      s = 2 * (s - z) % 2;
      z = s.toInt();
      k = 8 * v + 4 * d + 2 * z + 2304;
      k =
          56 * tzLookupData.codeUnitAt(k) +
          tzLookupData.codeUnitAt(k + 1) -
          1995;
    }
    return tzLookupZones[k + tzLookupZones.length - 3136];
  }

  /// The fixed-offset `Etc/GMT` zone nearest to [longitude]. POSIX zone
  /// names invert the sign: 15 degrees east is `Etc/GMT-1`.
  static String etcZoneForLongitude(double longitude) {
    if (!longitude.isFinite) return 'Etc/GMT';
    final hours = (longitude.clamp(-180.0, 180.0) / 15).round().clamp(-12, 12);
    if (hours == 0) return 'Etc/GMT';
    return hours > 0 ? 'Etc/GMT-$hours' : 'Etc/GMT+${-hours}';
  }
}
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `flutter test test/core/util/site_time_zone_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format lib/core/util test/core/util
flutter analyze lib/core/util test/core/util
git add scripts/tide/generate_tz_lookup_data.py scripts/tide/generate_tz_lookup_fixture.js lib/core/util/tz_lookup_data.dart lib/core/util/site_time_zone.dart test/core/util/fixtures/tz_lookup_parity.json test/core/util/site_time_zone_test.dart
git commit -m "Add offline coordinate to time zone lookup ported from tz-lookup"
```

---

### Task 2: Wall-clock and instant conversion

**Files:**
- Modify: `lib/core/util/site_time_zone.dart`
- Modify: `test/core/util/site_time_zone_test.dart`

**Interfaces:**
- Consumes: `SiteTimeZone.zoneIdFor`, `SiteTimeZone.etcZoneForLongitude` (Task 1).
- Produces:
  - `static DateTime SiteTimeZone.instantFromWallClock(DateTime wallClock, double latitude, double longitude)` returning a UTC `DateTime`.
  - `static DateTime SiteTimeZone.wallClockFromInstant(DateTime instant, double latitude, double longitude)` returning a `DateTime.utc` carrying the site's digits.
  - `@visibleForTesting static String Function(double, double)? debugZoneIdOverride`.

- [ ] **Step 1: Write the failing tests**

Append this group inside `main()` in `test/core/util/site_time_zone_test.dart`, and add `tearDown(() => SiteTimeZone.debugZoneIdOverride = null);` at the top of `main()`:

```dart
  group('SiteTimeZone conversions', () {
    const monterey = (36.62, -121.90);
    const sydney = (-33.86, 151.21);
    const adelaide = (-34.93, 138.60);
    const bonaire = (12.15, -68.27);
    const openAtlantic = (30.0, -40.0);
    const fiji = (-18.40, 178.10);

    DateTime instant((double, double) site, DateTime wallClock) =>
        SiteTimeZone.instantFromWallClock(wallClock, site.$1, site.$2);

    test('northern DST follows the date', () {
      expect(
        instant(monterey, DateTime.utc(2026, 1, 15, 10)),
        DateTime.utc(2026, 1, 15, 18),
      );
      expect(
        instant(monterey, DateTime.utc(2026, 7, 15, 10)),
        DateTime.utc(2026, 7, 15, 17),
      );
    });

    test('southern DST, half-hour zones, no-DST and open ocean', () {
      expect(
        instant(sydney, DateTime.utc(2026, 1, 15, 10)),
        DateTime.utc(2026, 1, 14, 23),
      );
      expect(
        instant(sydney, DateTime.utc(2026, 7, 15, 10)),
        DateTime.utc(2026, 7, 15, 0),
      );
      expect(
        instant(adelaide, DateTime.utc(2026, 7, 15, 10)),
        DateTime.utc(2026, 7, 15, 0, 30),
      );
      expect(
        instant(bonaire, DateTime.utc(2026, 3, 28, 10)),
        DateTime.utc(2026, 3, 28, 14),
      );
      expect(
        instant(openAtlantic, DateTime.utc(2026, 3, 28, 10)),
        DateTime.utc(2026, 3, 28, 13),
      );
    });

    test('spring-forward gap rolls forward; fall-back overlap takes daylight time', () {
      // 02:30 does not exist on 2026-03-08 in Pacific time: it reads as 03:30 PDT.
      expect(
        instant(monterey, DateTime.utc(2026, 3, 8, 2, 30)),
        DateTime.utc(2026, 3, 8, 10, 30),
      );
      // 01:30 happens twice on 2026-11-01: the first (PDT) occurrence is used.
      expect(
        instant(monterey, DateTime.utc(2026, 11, 1, 1, 30)),
        DateTime.utc(2026, 11, 1, 8, 30),
      );
    });

    test('a local DateTime with the same digits gives the same instant', () {
      expect(
        instant(bonaire, DateTime(2026, 3, 28, 10)),
        instant(bonaire, DateTime.utc(2026, 3, 28, 10)),
      );
    });

    test('wall clock round-trips and crosses the antimeridian', () {
      final wallClock = DateTime.utc(2026, 7, 15, 9, 45);
      final there = instant(sydney, wallClock);
      expect(
        SiteTimeZone.wallClockFromInstant(there, sydney.$1, sydney.$2),
        wallClock,
      );
      expect(
        SiteTimeZone.wallClockFromInstant(
          DateTime.utc(2026, 7, 15),
          fiji.$1,
          fiji.$2,
        ),
        DateTime.utc(2026, 7, 15, 12),
      );
      expect(
        SiteTimeZone.wallClockFromInstant(
          DateTime.utc(2026, 7, 15),
          bonaire.$1,
          bonaire.$2,
        ).isUtc,
        isTrue,
      );
    });

    test('a zone missing from tzdata falls back to the longitude zone', () {
      SiteTimeZone.debugZoneIdOverride = (_, _) => 'Nope/Zone';
      // Longitude -68.27 rounds to 5 hours west: Etc/GMT+5.
      expect(
        instant(bonaire, DateTime.utc(2026, 3, 28, 10)),
        DateTime.utc(2026, 3, 28, 15),
      );
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/util/site_time_zone_test.dart`
Expected: FAIL to compile: `instantFromWallClock` and `debugZoneIdOverride` are not defined.

- [ ] **Step 3: Implement the conversions**

In `lib/core/util/site_time_zone.dart`, replace the import block with:

```dart
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:submersion/core/util/tz_lookup_data.dart';
```

Replace the class doc comment's last sentence block and add these members inside `SiteTimeZone`, above `zoneIdFor`:

```dart
  /// Replaces [zoneIdFor] inside the conversions, for tests only.
  @visibleForTesting
  static String Function(double latitude, double longitude)?
  debugZoneIdOverride;

  static final Set<String> _loggedMissingZones = {};

  /// The UTC instant at which the site's clocks show [wallClock]'s digits.
  ///
  /// Only the calendar and clock components of [wallClock] are read, so a
  /// wall-clock-as-UTC value and a local `DateTime` with the same digits
  /// give the same answer. The offset comes from tzdata for that date. In a
  /// spring-forward gap the time rolls forward by the gap (02:30 reads as
  /// 03:30 daylight time); in a fall-back overlap the earlier, daylight-time
  /// occurrence is used. Both behaviors are `package:timezone`'s.
  static DateTime instantFromWallClock(
    DateTime wallClock,
    double latitude,
    double longitude,
  ) {
    final local = tz.TZDateTime(
      _locationFor(latitude, longitude),
      wallClock.year,
      wallClock.month,
      wallClock.day,
      wallClock.hour,
      wallClock.minute,
      wallClock.second,
      wallClock.millisecond,
    );
    return DateTime.fromMillisecondsSinceEpoch(
      local.millisecondsSinceEpoch,
      isUtc: true,
    );
  }

  /// The site's wall-clock digits at [instant], as a wall-clock-as-UTC value
  /// (the flavor every tide formatter prints verbatim).
  static DateTime wallClockFromInstant(
    DateTime instant,
    double latitude,
    double longitude,
  ) {
    final local = tz.TZDateTime.from(
      instant,
      _locationFor(latitude, longitude),
    );
    return DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
    );
  }

  static tz.Location _locationFor(double latitude, double longitude) {
    // Initializing resets tz.local, so never re-initialize a database the
    // notification service already loaded.
    if (!tz.timeZoneDatabase.isInitialized) tzdata.initializeTimeZones();
    final id = (debugZoneIdOverride ?? zoneIdFor)(latitude, longitude);
    try {
      return tz.getLocation(id);
    } on tz.LocationNotFoundException {
      if (_loggedMissingZones.add(id)) {
        developer.log(
          'Zone $id is missing from tzdata; using the longitude offset',
          name: 'SiteTimeZone',
        );
      }
      return tz.getLocation(etcZoneForLongitude(longitude));
    }
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/util/site_time_zone_test.dart`
Expected: PASS (8 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/core/util test/core/util
flutter analyze lib/core/util test/core/util
git add lib/core/util/site_time_zone.dart test/core/util/site_time_zone_test.dart
git commit -m "Convert between site wall-clock and real instants with tzdata"
```

---

### Task 3: Tide status at a dive entry, verified against NOAA local time

**Files:**
- Create: `lib/features/tides/domain/services/tide_status_for_dive.dart`
- Create: `lib/features/tides/domain/services/site_wall_clock.dart`
- Create: `scripts/tide/fetch_noaa_local_time_fixtures.py`
- Create (generated): `test/core/tide/fixtures/noaa_local_9414290.json`, `test/core/tide/fixtures/noaa_local_9755371.json`
- Create: `test/features/tides/domain/tide_status_for_dive_test.dart`
- Create: `test/features/tides/domain/site_wall_clock_test.dart`

**Interfaces:**
- Consumes: `SiteTimeZone.instantFromWallClock`, `SiteTimeZone.wallClockFromInstant` (Task 2).
- Produces (in `tide_status_for_dive.dart`):
  - `DateTime diveEntryInstant(DateTime entryWallClock, GeoPoint location)`
  - `Future<TideStatus> tideStatusForDive({required TideCalculator calculator, required DateTime entryWallClock, required GeoPoint location})`
  - `TideStatus tideStatusForDiveSync({required TideCalculator calculator, required DateTime entryWallClock, required GeoPoint location})`
- Produces (in `site_wall_clock.dart`):
  - `DateTime siteWallClock(DateTime instant, GeoPoint location)`
  - `List<TideExtreme> extremesAtSiteWallClock(List<TideExtreme> extremes, GeoPoint location)`
  - `List<TidePrediction> predictionsAtSiteWallClock(List<TidePrediction> predictions, GeoPoint location)`
  - `extension TideRecordSiteWallClock on TideRecord { TideRecord toSiteWallClock(GeoPoint location) }`

- [ ] **Step 1: Write the NOAA fixture fetcher**

Create `scripts/tide/fetch_noaa_local_time_fixtures.py`:

```python
#!/usr/bin/env python3
"""Fetch NOAA local-time tide fixtures for the site-time golden test.

For each station: harmonic constituents (GMT phases), the MSL minus MLLW
datum offset, the station coordinates, and NOAA's own high/low predictions
in the station's local standard or daylight time (time_zone=lst_ldt). NOAA
performs the local-time conversion, independently of Submersion's code.

Usage (from the repo root):
    python3.14 scripts/tide/fetch_noaa_local_time_fixtures.py
"""

import json
import urllib.request
from pathlib import Path

MDAPI = "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations"
DATAGETTER = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"
OUT_DIR = Path("test/core/tide/fixtures")

# Same spelling map as NoaaStationService._nameMap.
NAME_MAP = {
    "NU2": "Nu2",
    "MU2": "Mu2",
    "LAM2": "La2",
    "RHO": "Rho1",
    "MM": "Mm",
    "SSA": "Ssa",
    "SA": "Sa",
    "MF": "Mf",
}

STATIONS = [
    # San Francisco (Pacific time): windows straddle both 2026 DST changes.
    ("9414290", [("20260307", "20260309"), ("20261031", "20261102")]),
    # San Juan, Puerto Rico (Atlantic time, no DST).
    ("9755371", [("20260714", "20260716")]),
]


def get_json(url: str) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": "submersion"})
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.load(response)


def main() -> None:
    for station, windows in STATIONS:
        meta = get_json(f"{MDAPI}/{station}.json")["stations"][0]
        harcon = get_json(f"{MDAPI}/{station}/harcon.json?units=metric")
        datums = get_json(f"{MDAPI}/{station}/datums.json?units=metric")["datums"]
        datum = {d["name"]: d["value"] for d in datums}

        constituents = {}
        for c in harcon["HarmonicConstituents"]:
            if c["amplitude"] <= 0:
                continue
            name = NAME_MAP.get(c["name"], c["name"])
            constituents[name] = {"amplitude": c["amplitude"], "phase": c["phase_GMT"]}

        extremes = []
        for begin, end in windows:
            url = (
                f"{DATAGETTER}?product=predictions&application=submersion"
                f"&begin_date={begin}&end_date={end}&datum=MLLW&station={station}"
                "&time_zone=lst_ldt&units=metric&interval=hilo&format=json"
            )
            for p in get_json(url)["predictions"]:
                extremes.append(
                    {"localTime": p["t"], "type": p["type"], "height": float(p["v"])}
                )

        fixture = {
            "station": station,
            "name": meta["name"],
            "latitude": meta["lat"],
            "longitude": meta["lng"],
            "source": "NOAA CO-OPS harcon, datums and hilo predictions, time_zone=lst_ldt",
            "z0MetersAboveMllw": round(datum["MSL"] - datum["MLLW"], 4),
            "constituents": constituents,
            "expectedLocalExtremes": extremes,
        }
        out = OUT_DIR / f"noaa_local_{station}.json"
        out.write_text(json.dumps(fixture, indent=1) + "\n", encoding="utf-8")
        print(f"Wrote {len(extremes)} extremes for {station} to {out}")


if __name__ == "__main__":
    main()
```

Run: `python3.14 scripts/tide/fetch_noaa_local_time_fixtures.py`
Expected: two `Wrote ... extremes` lines, about 24 extremes for 9414290 and 12 for 9755371.

- [ ] **Step 2: Write the failing tests**

Create `test/features/tides/domain/tide_status_for_dive_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/tide/tide.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tides/domain/services/site_wall_clock.dart';
import 'package:submersion/features/tides/domain/services/tide_status_for_dive.dart';

/// NOAA prints "2026-03-08 03:31"; the digits are site wall-clock.
DateTime _wallClock(String noaaLocal) {
  final parsed = DateTime.parse(noaaLocal.replaceFirst(' ', 'T'));
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
  );
}

({TideCalculator calculator, GeoPoint location, List<Map<String, dynamic>> extremes})
_load(String station) {
  final fixture =
      json.decode(
            File(
              p.join('test', 'core', 'tide', 'fixtures', 'noaa_local_$station.json'),
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final constituents = <String, TideConstituent>{
    for (final entry
        in (fixture['constituents'] as Map<String, dynamic>).entries)
      entry.key: TideConstituent(
        name: entry.key,
        amplitude: ((entry.value as Map)['amplitude'] as num).toDouble(),
        phase: ((entry.value as Map)['phase'] as num).toDouble(),
      ),
  };
  return (
    calculator: TideCalculator(
      constituents: constituents,
      z0: (fixture['z0MetersAboveMllw'] as num).toDouble(),
    ),
    location: GeoPoint(
      (fixture['latitude'] as num).toDouble(),
      (fixture['longitude'] as num).toDouble(),
    ),
    extremes: (fixture['expectedLocalExtremes'] as List)
        .cast<Map<String, dynamic>>(),
  );
}

/// Minutes from [expected] to the nearest same-type extreme in [status],
/// after mapping it with [toDisplay].
double _errorMinutes(
  TideStatus status,
  TideExtremeType type,
  DateTime expected,
  DateTime Function(DateTime) toDisplay,
) {
  final candidates = [status.previousExtreme, status.nextExtreme]
      .whereType<TideExtreme>()
      .where((e) => e.type == type)
      .map((e) => toDisplay(e.time).difference(expected).inSeconds.abs() / 60);
  return candidates.isEmpty ? double.infinity : candidates.reduce(math.min);
}

void main() {
  for (final station in ['9414290', '9755371']) {
    test('NOAA $station local-time extremes round-trip through site time', () {
      final data = _load(station);
      expect(data.extremes, isNotEmpty);
      for (final e in data.extremes) {
        final expected = _wallClock(e['localTime'] as String);
        final type = e['type'] == 'H'
            ? TideExtremeType.high
            : TideExtremeType.low;
        final status = tideStatusForDiveSync(
          calculator: data.calculator,
          entryWallClock: expected.subtract(const Duration(hours: 1)),
          location: data.location,
        );
        final error = _errorMinutes(
          status,
          type,
          expected,
          (instant) => siteWallClock(instant, data.location),
        );
        expect(
          error,
          lessThanOrEqualTo(20),
          reason: '$station ${e['type']} at ${e['localTime']}',
        );
      }
    });
  }

  test('the old path (wall clock fed in as an instant) misses by hours', () {
    final data = _load('9755371');
    final errors = <double>[];
    for (final e in data.extremes) {
      final expected = _wallClock(e['localTime'] as String);
      final type = e['type'] == 'H'
          ? TideExtremeType.high
          : TideExtremeType.low;
      final status = data.calculator.getStatus(
        expected.subtract(const Duration(hours: 1)),
      );
      errors.add(_errorMinutes(status, type, expected, (t) => t));
    }
    errors.sort();
    expect(errors[errors.length ~/ 2], greaterThanOrEqualTo(60));
  });

  test('diveEntryInstant reads the site clock', () {
    expect(
      diveEntryInstant(
        DateTime.utc(2026, 3, 28, 10),
        const GeoPoint(12.15, -68.27),
      ),
      DateTime.utc(2026, 3, 28, 14),
    );
  });

  test('async and sync variants agree', () async {
    final data = _load('9755371');
    final entry = DateTime.utc(2026, 7, 14, 10);
    final sync = tideStatusForDiveSync(
      calculator: data.calculator,
      entryWallClock: entry,
      location: data.location,
    );
    final async = await tideStatusForDive(
      calculator: data.calculator,
      entryWallClock: entry,
      location: data.location,
    );
    expect(async, sync);
  });
}
```

Create `test/features/tides/domain/site_wall_clock_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/tide/tide.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';
import 'package:submersion/features/tides/domain/services/site_wall_clock.dart';

const _bonaire = GeoPoint(12.15, -68.27); // America/Caracas, UTC-4, no DST

void main() {
  test('record times move to site wall clock; other fields are kept', () {
    final record = TideRecord(
      id: 'r1',
      diveId: 'd1',
      heightMeters: 0.3,
      tideState: TideState.rising,
      highTideTime: DateTime.utc(2026, 3, 28, 18, 20),
      highTideHeight: 0.4,
      lowTideTime: DateTime.utc(2026, 3, 28, 12, 20),
      lowTideHeight: 0.1,
      createdAt: DateTime.utc(2026, 3, 28),
    );
    final mapped = record.toSiteWallClock(_bonaire);
    expect(mapped.highTideTime, DateTime.utc(2026, 3, 28, 14, 20));
    expect(mapped.lowTideTime, DateTime.utc(2026, 3, 28, 8, 20));
    expect(mapped.heightMeters, 0.3);
    expect(mapped.id, 'r1');
  });

  test('missing record times stay missing', () {
    final record = TideRecord(
      id: 'r1',
      diveId: 'd1',
      heightMeters: 0.3,
      tideState: TideState.rising,
      createdAt: DateTime.utc(2026, 3, 28),
    );
    final mapped = record.toSiteWallClock(_bonaire);
    expect(mapped.highTideTime, isNull);
    expect(mapped.lowTideTime, isNull);
  });

  test('extremes and predictions map element-wise', () {
    final extremes = [
      TideExtreme(
        type: TideExtremeType.high,
        time: DateTime.utc(2026, 3, 28, 18),
        heightMeters: 0.4,
      ),
    ];
    final predictions = [
      TidePrediction(time: DateTime.utc(2026, 3, 28, 4), heightMeters: 0.2),
    ];
    expect(
      extremesAtSiteWallClock(extremes, _bonaire).single.time,
      DateTime.utc(2026, 3, 28, 14),
    );
    expect(
      predictionsAtSiteWallClock(predictions, _bonaire).single.time,
      DateTime.utc(2026, 3, 28),
    );
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/features/tides/domain/tide_status_for_dive_test.dart test/features/tides/domain/site_wall_clock_test.dart`
Expected: FAIL to compile: `tide_status_for_dive.dart` and `site_wall_clock.dart` not found.

- [ ] **Step 4: Implement both files**

Create `lib/features/tides/domain/services/tide_status_for_dive.dart`:

```dart
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/tide/tide_calculator.dart';
import 'package:submersion/core/util/site_time_zone.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The real instant of a dive entry stored as site wall-clock
/// (wall-clock-as-UTC, see `wall_clock_utc.dart`).
DateTime diveEntryInstant(DateTime entryWallClock, GeoPoint location) =>
    SiteTimeZone.instantFromWallClock(
      entryWallClock,
      location.latitude,
      location.longitude,
    );

/// Tide status at a dive's entry. The engine is evaluated at the real
/// instant; the returned extremes are real UTC instants, to be mapped with
/// `toSiteWallClock` (site_wall_clock.dart) before display.
Future<TideStatus> tideStatusForDive({
  required TideCalculator calculator,
  required DateTime entryWallClock,
  required GeoPoint location,
}) => calculator.getStatusAsync(diveEntryInstant(entryWallClock, location));

/// Synchronous twin of [tideStatusForDive] for code already inside `build`.
TideStatus tideStatusForDiveSync({
  required TideCalculator calculator,
  required DateTime entryWallClock,
  required GeoPoint location,
}) => calculator.getStatus(diveEntryInstant(entryWallClock, location));
```

Create `lib/features/tides/domain/services/site_wall_clock.dart`:

```dart
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/core/tide/entities/tide_prediction.dart';
import 'package:submersion/core/util/site_time_zone.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';

/// The site's wall clock at [instant], as wall-clock-as-UTC.
DateTime siteWallClock(DateTime instant, GeoPoint location) =>
    SiteTimeZone.wallClockFromInstant(
      instant,
      location.latitude,
      location.longitude,
    );

/// [extremes] with their times moved to site wall clock, for display.
List<TideExtreme> extremesAtSiteWallClock(
  List<TideExtreme> extremes,
  GeoPoint location,
) => [
  for (final e in extremes) e.copyWith(time: siteWallClock(e.time, location)),
];

/// [predictions] with their times moved to site wall clock, for display.
List<TidePrediction> predictionsAtSiteWallClock(
  List<TidePrediction> predictions,
  GeoPoint location,
) => [
  for (final prediction in predictions)
    prediction.copyWith(time: siteWallClock(prediction.time, location)),
];

extension TideRecordSiteWallClock on TideRecord {
  /// This record with its high and low times moved from real instants to
  /// site wall clock, for display. Storage always keeps instants.
  TideRecord toSiteWallClock(GeoPoint location) => copyWith(
    highTideTime: highTideTime == null
        ? null
        : siteWallClock(highTideTime!, location),
    lowTideTime: lowTideTime == null
        ? null
        : siteWallClock(lowTideTime!, location),
  );
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/tides/domain/tide_status_for_dive_test.dart test/features/tides/domain/site_wall_clock_test.dart`
Expected: PASS (5 and 3 tests).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/features/tides/domain test/features/tides/domain
flutter analyze lib/features/tides/domain test/features/tides/domain
git add scripts/tide/fetch_noaa_local_time_fixtures.py test/core/tide/fixtures/noaa_local_9414290.json test/core/tide/fixtures/noaa_local_9755371.json lib/features/tides/domain/services/tide_status_for_dive.dart lib/features/tides/domain/services/site_wall_clock.dart test/features/tides/domain/tide_status_for_dive_test.dart test/features/tides/domain/site_wall_clock_test.dart
git commit -m "Evaluate dive tides at the real instant and verify against NOAA local time"
```

---

### Task 4: Dive save, self-heal and dive page use site time

**Files:**
- Modify: `lib/features/tides/presentation/providers/tide_providers.dart` (`healedTideRecordProvider`, around lines 44-73)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (tide recording block, around lines 5526-5550)
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (`_tideCard`, around lines 3944-3998, and the two stale comments in `_buildTideCard`)
- Create: `test/features/tides/presentation/providers/healed_tide_record_provider_test.dart`
- Modify: `test/features/dive_log/presentation/pages/dive_detail_tide_card_test.dart`

**Interfaces:**
- Consumes: `tideStatusForDive`, `tideStatusForDiveSync` (Task 3); `TideRecordSiteWallClock.toSiteWallClock` (Task 3).
- Produces: no new API. `healedTideRecordProvider`'s family key is unchanged.

- [ ] **Step 1: Write the failing provider test**

Create `test/features/tides/presentation/providers/healed_tide_record_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/tide/tide.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tides/data/repositories/tide_record_repository.dart';
import 'package:submersion/features/tides/data/services/tide_constituent_resolver.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';

class _FakeDiveRepository extends Fake implements DiveRepository {
  @override
  Stream<void> watchDiveDetailChanges() => const Stream<void>.empty();
}

class _FakeTideRecordRepository extends TideRecordRepository {
  _FakeTideRecordRepository(this.stored);

  TideRecord? stored;
  int writes = 0;

  @override
  Future<TideRecord?> getTideRecordForDive(String diveId) async => stored;

  @override
  Future<TideRecord> createFromStatus({
    required String diveId,
    required TideStatus status,
  }) async {
    writes++;
    final record = TideRecord.fromStatus(
      id: 'healed-$writes',
      diveId: diveId,
      status: status,
    );
    stored = record;
    return record;
  }
}

const _bonaire = GeoPoint(12.15, -68.27); // UTC-4, no DST
final _entryWallClock = DateTime.utc(2026, 3, 28, 10);
final _calculator = TideCalculator(
  constituents: {
    'M2': const TideConstituent(name: 'M2', amplitude: 1.0, phase: 0.0),
  },
);

ProviderContainer _container(_FakeTideRecordRepository repository) {
  final container = ProviderContainer(
    overrides: [
      diveRepositoryProvider.overrideWithValue(_FakeDiveRepository()),
      tideRecordRepositoryProvider.overrideWithValue(repository),
      resolvedTideDataProvider(_bonaire).overrideWith(
        (ref) async => ResolvedTideData(
          calculator: _calculator,
          source: const TideDataSource.fesModel(),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

final _key = (diveId: 'd1', location: _bonaire, entryTime: _entryWallClock);

void main() {
  test('a record computed at the wall clock as an instant is healed', () async {
    // The pre-fix save path evaluated the engine at 10:00Z, four hours early.
    final stale = TideRecord.fromStatus(
      id: 'stale',
      diveId: 'd1',
      status: _calculator.getStatus(_entryWallClock),
    );
    final repository = _FakeTideRecordRepository(stale);
    final container = _container(repository);

    final healed = await container.read(healedTideRecordProvider(_key).future);

    final fresh = _calculator.getStatus(DateTime.utc(2026, 3, 28, 14));
    expect(repository.writes, 1);
    expect(healed!.id, 'healed-1');
    expect(healed.heightMeters, closeTo(fresh.currentHeight, 1e-9));
  });

  test('healing converges: a second view does not rewrite', () async {
    final stale = TideRecord.fromStatus(
      id: 'stale',
      diveId: 'd1',
      status: _calculator.getStatus(_entryWallClock),
    );
    final repository = _FakeTideRecordRepository(stale);
    final container = _container(repository);

    await container.read(healedTideRecordProvider(_key).future);
    container.invalidate(healedTideRecordProvider(_key));
    final again = await container.read(healedTideRecordProvider(_key).future);

    expect(repository.writes, 1);
    expect(again!.id, 'healed-1');
  });

  test('a record computed at the real instant is left alone', () async {
    final correct = TideRecord.fromStatus(
      id: 'correct',
      diveId: 'd1',
      status: _calculator.getStatus(DateTime.utc(2026, 3, 28, 14)),
    );
    final repository = _FakeTideRecordRepository(correct);
    final container = _container(repository);

    final result = await container.read(healedTideRecordProvider(_key).future);

    expect(repository.writes, 0);
    expect(result!.id, 'correct');
  });
}
```

(`DiveRepository` is a concrete class; `Fake implements` it so only the stream the provider watches needs a body.)

- [ ] **Step 2: Run the provider test to verify it fails**

Run: `flutter test test/features/tides/presentation/providers/healed_tide_record_provider_test.dart`
Expected: the first two tests FAIL (the provider still evaluates at 10:00Z, so the stale record matches the fresh computation and `writes` is 0); the third FAILS because the correct record is rewritten.

- [ ] **Step 3: Switch the healed provider to `tideStatusForDive`**

In `lib/features/tides/presentation/providers/tide_providers.dart`, add the import:

```dart
import 'package:submersion/features/tides/domain/services/tide_status_for_dive.dart';
```

Replace:

```dart
      final status = await resolved.calculator.getStatusAsync(params.entryTime);
```

with:

```dart
      // entryTime is the dive's wall clock; the engine needs the instant.
      final status = await tideStatusForDive(
        calculator: resolved.calculator,
        entryWallClock: params.entryTime,
        location: location,
      );
```

- [ ] **Step 4: Run the provider test to verify it passes**

Run: `flutter test test/features/tides/presentation/providers/healed_tide_record_provider_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Switch the save path**

In `lib/features/dive_log/presentation/pages/dive_edit_page.dart`, add the import:

```dart
import 'package:submersion/features/tides/domain/services/tide_status_for_dive.dart';
```

In the tide recording block, replace:

```dart
            // Record tide status at dive entry time
            final status = resolved.calculator.getStatus(entryDateTime);
```

with:

```dart
            // entryDateTime is the dive's wall clock (DateTime.utc of the
            // picked digits); evaluate the tide at the real instant.
            final status = await tideStatusForDive(
              calculator: resolved.calculator,
              entryWallClock: entryDateTime,
              location: _selectedSite!.location!,
            );
```

- [ ] **Step 6: Write the failing dive page test**

In `test/features/dive_log/presentation/pages/dive_detail_tide_card_test.dart`:

1. Add imports:
```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
```
2. Change `_pumpDetailPage` to take an optional dive: add the parameter `Dive? dive,` after `TideRecord record, {`, and replace `final dive = createTestDiveWithBottomTime();` with `final shownDive = dive ?? createTestDiveWithBottomTime();`, then rename every later use of `dive` inside the helper to `shownDive`.
3. Append this group inside `main()`:

```dart
  group('DiveDetailPage tide card site-local times', () {
    // Bonaire resolves to America/Caracas: UTC-4 with no DST.
    const bonaire = GeoPoint(12.15, -68.27);

    testWidgets('stored instants are shown in the site wall clock', (
      tester,
    ) async {
      final dive = createTestDiveWithBottomTime().copyWith(
        site: const DiveSite(id: 'site-1', name: 'Salt Pier', location: bonaire),
      );
      await _pumpDetailPage(
        tester,
        _tideRecord(
          highTideTime: DateTime.utc(2026, 3, 28, 18, 20),
          lowTideTime: DateTime.utc(2026, 3, 28, 12, 20),
        ),
        dive: dive,
      );

      expect(find.text('Sat, Mar 28 | 08:20 - 20:20'), findsOneWidget);
      expect(find.textContaining('at 14:20'), findsOneWidget);
      expect(find.textContaining('at 08:20'), findsOneWidget);
    });
  });
```

- [ ] **Step 7: Run the dive page test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_tide_card_test.dart`
Expected: the new test FAILS (the card prints `18:20` and `12:20`); the three existing tests PASS.

- [ ] **Step 8: Map the dive page's tide card to site time**

In `lib/features/dive_log/presentation/pages/dive_detail_page.dart`, add imports:

```dart
import 'package:submersion/features/tides/domain/services/site_wall_clock.dart';
import 'package:submersion/features/tides/domain/services/tide_status_for_dive.dart';
```

Replace the body of `_tideCard` from `final tideRecordAsync = ref.watch(` through the end of the method with:

```dart
    final siteLocation = dive.site?.location;
    final tideRecordAsync = ref.watch(
      healedTideRecordProvider((
        diveId: dive.id,
        location: siteLocation,
        entryTime: dive.effectiveEntryTime,
      )),
    );

    return tideRecordAsync.when<Widget?>(
      data: (tideRecord) {
        if (tideRecord != null) {
          // Stored times are real instants. Without coordinates there is
          // no site clock to map to, so they are shown as stored.
          return _buildTideCard(
            context,
            siteLocation == null
                ? tideRecord
                : tideRecord.toSiteWallClock(siteLocation),
            entryTime: dive.effectiveEntryTime,
          );
        }

        // No stored record: calculate from the tide model if we have
        // coordinates.
        if (siteLocation == null) return null;

        final entryTime = dive.effectiveEntryTime;
        final calculatorAsync = ref.watch(tideCalculatorProvider(siteLocation));

        return calculatorAsync.when<Widget?>(
          data: (calculator) {
            if (calculator == null) return null; // No tide data here.

            final status = tideStatusForDiveSync(
              calculator: calculator,
              entryWallClock: entryTime,
              location: siteLocation,
            );
            final record = TideRecord.fromStatus(
              id: 'calculated',
              diveId: dive.id,
              status: status,
            ).toSiteWallClock(siteLocation);

            return _buildTideCard(
              context,
              record,
              isCalculated: true,
              entryTime: entryTime,
            );
          },
          loading: () => null,
          error: (_, _) => null,
        );
      },
      loading: () => null,
      error: (_, _) => null,
    );
  }
```

In `_buildTideCard`, replace the comment

```dart
    // Cycle bounds are stored wall-clock instants, not device-local times:
    // format them verbatim without any timezone conversion.
```

with

```dart
    // The record's times arrive already mapped to the dive site's wall
    // clock (wall-clock-as-UTC), so format them verbatim.
```

- [ ] **Step 9: Run the dive page and provider tests to verify they pass**

Run:
```bash
flutter test test/features/dive_log/presentation/pages/dive_detail_tide_card_test.dart test/features/tides/presentation/providers/healed_tide_record_provider_test.dart test/features/dive_log/presentation/pages/dive_detail_page_paired_sections_test.dart
```
Expected: PASS.

- [ ] **Step 10: Format, analyze, commit**

```bash
dart format lib/features/tides lib/features/dive_log/presentation/pages test/features/tides test/features/dive_log/presentation/pages
flutter analyze lib/features/tides lib/features/dive_log/presentation/pages test/features/tides test/features/dive_log/presentation/pages
git add lib/features/tides/presentation/providers/tide_providers.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/tides/presentation/providers/healed_tide_record_provider_test.dart test/features/dive_log/presentation/pages/dive_detail_tide_card_test.dart
git commit -m "Record, heal and show dive tides in the dive site's local time"
```

---

### Task 5: Site page tide section in site time

**Files:**
- Modify: `lib/features/tides/presentation/widgets/tide_section.dart` (`_TideSectionContent.build` and `_buildChartTimeRange`)
- Modify: `test/features/tides/presentation/widgets/tide_section_time_format_test.dart`

**Interfaces:**
- Consumes: `siteWallClock`, `extremesAtSiteWallClock`, `predictionsAtSiteWallClock` (Task 3).
- Produces: `_buildChartTimeRange` gains a required `DateTime now` parameter (private).

- [ ] **Step 1: Update the existing test and add the failing ones**

In `test/features/tides/presentation/widgets/tide_section_time_format_test.dart`:

1. Add imports:
```dart
import 'package:submersion/core/util/site_time_zone.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_times_table.dart';
```
2. Replace the comment above `_extremes` with:
```dart
// The provider returns real instants. The section shows them in the site's
// wall clock: Santa Cruz is America/Los_Angeles, PDT (UTC-7) on both
// fixture dates. The chart window runs from the newest extreme before now
// (minus 30min) to the second extreme after now (plus 30min); far-past and
// far-future fixtures keep the result independent of the real clock and of
// the host's UTC offset. (#222)
```
3. Replace the existing expectation and its comment with:
```dart
    // Low 06:15Z Mar 10 2020 is 23:15 PDT Mar 9, minus 30min = 22:45.
    // Low 14:30Z May 20 2030 is 07:30 PDT, plus 30min = 08:00.
    expect(find.text('Mon, Mar 9 | 22:45 - 08:00 (May 20)'), findsOneWidget);
```
4. Add this helper above `main()`, and replace the body of the existing test up to its `pumpAndSettle` with `await _pumpSection(tester);`:

```dart
Future<void> _pumpSection(WidgetTester tester) async {
  final settings = MockSettingsNotifier();
  await settings.setTimeFormat(TimeFormat.twentyFourHour);
  final overrides = await getBaseOverrides(settingsNotifier: settings);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        hasTideDataProvider(_location).overrideWith((ref) async => true),
        currentTideStatusProvider(_location).overrideWith((ref) async => null),
        tidePredictionsProvider(
          _location,
        ).overrideWith((ref) async => <TidePrediction>[]),
        tideExtremesProvider(_location).overrideWith((ref) async => _extremes),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: TideSection(location: _location)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
```

Then append inside `main()`:

```dart
  testWidgets('the times table gets site-clock extremes and a site-clock now', (
    tester,
  ) async {
    await _pumpSection(tester);

    final table = tester.widget<TideTimesTable>(find.byType(TideTimesTable));
    expect(table.extremes.map((e) => e.time).toList(), [
      DateTime.utc(2020, 3, 9, 23, 15),
      DateTime.utc(2030, 5, 20, 1),
      DateTime.utc(2030, 5, 20, 7, 30),
    ]);

    // "Today" and "Tomorrow" must be judged on the site's calendar.
    final siteNow = SiteTimeZone.wallClockFromInstant(
      DateTime.now(),
      _location.latitude,
      _location.longitude,
    );
    expect(table.now, isNotNull);
    expect(table.now!.difference(siteNow).inMinutes.abs(), lessThanOrEqualTo(1));
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/tides/presentation/widgets/tide_section_time_format_test.dart`
Expected: both tests FAIL (the label still reads `Tue, Mar 10 | 05:45 - 15:00 (May 20)`, and the table gets unmapped extremes with `now` null).

- [ ] **Step 3: Map extremes, predictions and now in the section**

In `lib/features/tides/presentation/widgets/tide_section.dart`, add the import:

```dart
import 'package:submersion/features/tides/domain/services/site_wall_clock.dart';
```

In `_TideSectionContent.build`, after `final extremesAsync = ref.watch(tideExtremesProvider(location));`, add:

```dart
    // Providers compute with real instants; everything absolute on screen
    // is shown in the site's wall clock. CurrentTideIndicator keeps the
    // real status because it only shows durations from the real now.
    final siteNow = siteWallClock(DateTime.now(), location);
```

Then make these replacements inside the same `build`:

- `_buildChartTimeRange(context, extremes, settings.timeFormat, settings.dateFormat,)` becomes `_buildChartTimeRange(context, extremesAtSiteWallClock(extremes, location), siteNow, settings.timeFormat, settings.dateFormat,)`.
- In all three `TideChart(` constructions, `predictions: predictions,` becomes `predictions: predictionsAtSiteWallClock(predictions, location),`, and add `now: siteNow,` after it. In the `data:` branch, `extremes: extremes,` becomes `extremes: extremesAtSiteWallClock(extremes, location),`.
- In `TideTimesTable(`, `extremes: extremes,` becomes `extremes: extremesAtSiteWallClock(extremes, location),`, and add `now: siteNow,`.

Change `_buildChartTimeRange`'s signature and first lines to:

```dart
  Widget _buildChartTimeRange(
    BuildContext context,
    List<TideExtreme> extremes,
    DateTime now,
    TimeFormat timeFormat,
    DateFormatPreference dateFormat,
  ) {
    if (extremes.isEmpty) return const SizedBox.shrink();
```

(delete its `final now = DateTime.now();` line), and replace its comment

```dart
    // Window bounds are stored wall-clock instants, not device-local times:
    // format them verbatim without any timezone conversion.
```

with

```dart
    // Extremes and now arrive in the site's wall clock (wall-clock-as-UTC),
    // so format them verbatim.
```

- [ ] **Step 4: Run the tide widget tests to verify they pass**

Run: `flutter test test/features/tides/presentation/widgets`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/tides test/features/tides
flutter analyze lib/features/tides test/features/tides
git add lib/features/tides/presentation/widgets/tide_section.dart test/features/tides/presentation/widgets/tide_section_time_format_test.dart
git commit -m "Show site-page tide times in the dive site's local time"
```

---

### Task 6: FES grid binary format and decoding

**Files:**
- Create: `scripts/tide/fes_grid_format.py`
- Create: `scripts/tide/write_fes_grid_test_fixtures.py`
- Create (generated): `test/features/tides/data/fixtures/fes_grid/manifest.json`, `.../global.bin`, `.../coastal/tile_0_0.bin`, `.../coastal/tile_1_0.bin`, `.../coastal/tile_0_179.bin`, `.../coastal/tile_1_179.bin`
- Create: `lib/features/tides/data/services/fes_grid/fes_grid_manifest.dart`
- Create: `lib/features/tides/data/services/fes_grid/fes_grid_layers.dart`
- Create: `test/features/tides/data/fes_grid/fes_grid_decoding_test.dart`

**Interfaces:**
- Produces (Dart):
  - `class FesLayerGeometry { double latMin, lonMin, resolution; int rows, cols; double get resolutionKm; }`
  - `class FesGridManifest { String model; String extractionDate; double bandKm; List<String> constituents; FesLayerGeometry coastal; int tileSize; Set<(int, int)> coastalTiles; FesLayerGeometry global; static FesGridManifest parse(String source); static const manifestPath = 'manifest.json'; static const globalPath = 'global.bin'; static String tilePath(int tileRow, int tileCol); }`
  - `class FesCell { double? amplitudeMeters(int index); double phaseDegrees(int index); }`
  - `class FesTile { static FesTile parse(ByteData data, {required int expectedConstituents}); int tileRow, tileCol, rows, cols; FesCell? cellAt(int row, int col); }`
  - `class FesGlobalLayer { static FesGlobalLayer parse(ByteData data, {required int expectedConstituents}); int rows, cols; FesCell? cellAt(int row, int col); }`
  - All `parse` methods throw `FormatException` on malformed input.
- Produces (Python, `fes_grid_format.py`): `CONSTITUENTS`, `NO_DATA`, `quantize(amplitude_m, phase_deg)`, `encode_tile(tile_row, tile_col, present, amp_mm, ph_cd)`, `decode_tile(data)`, `encode_global(amp_mm, ph_cd)`, `write_manifest(root, **fields)`.

- [ ] **Step 1: Write the Python format module**

Create `scripts/tide/fes_grid_format.py`:

```python
"""Binary format of Submersion's bundled FES2022 tide grid.

Shared by extract_fes_grid.py (real data) and
write_fes_grid_test_fixtures.py (synthetic fixtures), so the Dart reader is
tested against the exact bytes the extractor writes.

Layout, all little-endian:
  cell:   per constituent, int16 amplitude (mm, -1 = no data) then
          uint16 phase (hundredths of a degree, Greenwich lag)
  tile:   "SFT1", uint16 version, int16 tile row, int16 tile col,
          uint16 rows, uint16 cols, uint16 constituent count (16 bytes),
          occupancy bitmap (row-major, LSB first, ceil(rows*cols/8) bytes),
          uint32 populated-cells-before-row per row, packed populated cells
  global: "SFG1", uint16 version, uint16 rows, uint16 cols,
          uint16 constituent count (12 bytes), then every cell row-major
"""

import json
import struct
from pathlib import Path

import numpy as np

FORMAT_NAME = "submersion-fes-grid"
FORMAT_VERSION = 1
TILE_MAGIC = b"SFT1"
GLOBAL_MAGIC = b"SFG1"
NO_DATA = -1

# Per-cell field order. Must be a subset of the Dart engine's
# constituentSpeeds keys (guarded by fes_grid_accuracy_test.dart).
CONSTITUENTS = [
    "M2", "S2", "N2", "K2", "2N2", "Mu2", "Nu2", "L2", "T2", "Eps2", "La2",
    "R2", "K1", "O1", "P1", "Q1", "J1", "Mf", "Mm", "Ssa", "Sa", "Msqm",
    "Mtm", "M4", "MS4",
]


def quantize(amplitude_m, phase_deg):
    """Float arrays (..., C) in metres and degrees to (int16 mm, uint16 cdeg).

    A non-finite amplitude or phase marks that constituent as no data.
    """
    amp = np.asarray(amplitude_m, dtype=np.float64)
    ph = np.asarray(phase_deg, dtype=np.float64)
    missing = ~np.isfinite(amp) | ~np.isfinite(ph)
    amp_mm = np.rint(np.nan_to_num(amp) * 1000.0)
    if np.any(amp_mm[~missing] > 32767) or np.any(amp_mm[~missing] < 0):
        raise ValueError("amplitude outside the int16 millimetre range")
    amp_mm = np.where(missing, NO_DATA, amp_mm).astype(np.int16)
    ph_cd = np.rint(np.mod(np.nan_to_num(ph), 360.0) * 100.0).astype(np.int64) % 36000
    ph_cd = np.where(missing, 0, ph_cd).astype(np.uint16)
    return amp_mm, ph_cd


def _encode_cells(amp_mm, ph_cd):
    n, c = amp_mm.shape
    out = np.empty((n, c, 2), dtype="<u2")
    out[:, :, 0] = amp_mm.astype("<i2").view("<u2")
    out[:, :, 1] = ph_cd.astype("<u2")
    return out.tobytes()


def encode_tile(tile_row, tile_col, present, amp_mm, ph_cd):
    """present: bool (rows, cols). amp_mm, ph_cd: (rows, cols, C)."""
    rows, cols = present.shape
    count = amp_mm.shape[2]
    header = TILE_MAGIC + struct.pack(
        "<HhhHHH", FORMAT_VERSION, tile_row, tile_col, rows, cols, count
    )
    bitmap = np.packbits(present.reshape(-1), bitorder="little").tobytes()
    per_row = present.sum(axis=1).astype(np.int64)
    before = np.concatenate([[0], np.cumsum(per_row)[:-1]]).astype("<u4").tobytes()
    return header + bitmap + before + _encode_cells(amp_mm[present], ph_cd[present])


def decode_tile(data):
    """Inverse of encode_tile: (tile_row, tile_col, present, amp_mm, ph_cd)."""
    if data[:4] != TILE_MAGIC:
        raise ValueError("not an FES tile")
    _, tile_row, tile_col, rows, cols, count = struct.unpack_from("<HhhHHH", data, 4)
    bitmap_len = (rows * cols + 7) // 8
    bits = np.frombuffer(data, dtype=np.uint8, count=bitmap_len, offset=16)
    present = np.unpackbits(bits, bitorder="little")[: rows * cols].astype(bool)
    present = present.reshape(rows, cols)
    cells_offset = 16 + bitmap_len + rows * 4
    n = int(present.sum())
    raw = np.frombuffer(data, dtype="<u2", count=n * count * 2, offset=cells_offset)
    raw = raw.reshape(n, count, 2)
    amp_mm = np.full((rows, cols, count), NO_DATA, dtype=np.int16)
    ph_cd = np.zeros((rows, cols, count), dtype=np.uint16)
    amp_mm[present] = raw[:, :, 0].view("<i2")
    ph_cd[present] = raw[:, :, 1]
    return tile_row, tile_col, present, amp_mm, ph_cd


def encode_global(amp_mm, ph_cd):
    """amp_mm, ph_cd: (rows, cols, C); a no-data cell has every amplitude -1."""
    rows, cols, count = amp_mm.shape
    header = GLOBAL_MAGIC + struct.pack("<HHHH", FORMAT_VERSION, rows, cols, count)
    return header + _encode_cells(amp_mm.reshape(-1, count), ph_cd.reshape(-1, count))


def write_manifest(root: Path, *, model, extraction_date, band_km, coastal,
                   tile_size, tiles, global_, constituents=CONSTITUENTS):
    manifest = {
        "format": FORMAT_NAME,
        "version": FORMAT_VERSION,
        "model": model,
        "extractionDate": extraction_date,
        "bandKm": band_km,
        "constituents": list(constituents),
        "coastal": {**coastal, "tileSize": tile_size, "tiles": tiles},
        "global": global_,
    }
    (root / "manifest.json").write_text(json.dumps(manifest, indent=1) + "\n")
```

- [ ] **Step 2: Write the synthetic fixture writer**

Create `scripts/tide/write_fes_grid_test_fixtures.py`:

```python
#!/usr/bin/env python3
"""Write the synthetic FES grid fixtures used by the Dart decoding tests.

Values follow simple formulas so the Dart tests can state expectations
without re-implementing the encoder. Two constituents only: M2 and K1.

  coastal: latMin 10, lonMin -180, 0.5 degree, 5 rows x 720 cols, tiles 4x4
    present cells: (0,0) (0,1) (0,3) (1,1) (1,2) (3,0) (3,1) (3,2) (3,3)
                   (4,0) (0,719) (1,719) (4,719)
    row 2 is empty inside tile (0,0); tile row 1 is a single-row edge tile
    M2 amplitude = 1000 + 100*row + col mm
    M2 phase     = 180*(col % 2) degrees on row 3, else (37*row + 11*col) % 360
    K1 amplitude = 100 mm, except no data at (3,3)
    K1 phase     = 350 degrees on even cols, 10 on odd cols
  global: latMin 0, lonMin -180, 5 degree, 5 rows x 72 cols
    every cell present except (0,0)
    M2 amplitude = 2000 + 10*row + col mm, phase 90
    K1 amplitude = 50 mm, phase 0

Usage (from the repo root, in a venv with numpy):
    python3 scripts/tide/write_fes_grid_test_fixtures.py
"""

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fes_grid_format as fmt  # noqa: E402

ROOT = Path("test/features/tides/data/fixtures/fes_grid")
NAMES = ["M2", "K1"]
PRESENT = [(0, 0), (0, 1), (0, 3), (1, 1), (1, 2), (3, 0), (3, 1), (3, 2),
           (3, 3), (4, 0), (0, 719), (1, 719), (4, 719)]
ROWS, COLS, TILE = 5, 720, 4


def coastal_values():
    amp = np.full((ROWS, COLS, 2), np.nan)
    ph = np.full((ROWS, COLS, 2), np.nan)
    for r, c in PRESENT:
        amp[r, c, 0] = (1000 + 100 * r + c) / 1000.0
        ph[r, c, 0] = 180.0 * (c % 2) if r == 3 else float((37 * r + 11 * c) % 360)
        if (r, c) != (3, 3):
            amp[r, c, 1] = 0.1
            ph[r, c, 1] = 350.0 if c % 2 == 0 else 10.0
    return amp, ph


def main() -> None:
    (ROOT / "coastal").mkdir(parents=True, exist_ok=True)
    for old in (ROOT / "coastal").glob("*.bin"):
        old.unlink()

    amp, ph = coastal_values()
    amp_mm, ph_cd = fmt.quantize(amp, ph)
    present = np.zeros((ROWS, COLS), dtype=bool)
    for r, c in PRESENT:
        present[r, c] = True

    tiles = []
    for tile_row in range((ROWS + TILE - 1) // TILE):
        for tile_col in range(COLS // TILE):
            rs = slice(tile_row * TILE, min((tile_row + 1) * TILE, ROWS))
            cs = slice(tile_col * TILE, (tile_col + 1) * TILE)
            if not present[rs, cs].any():
                continue
            data = fmt.encode_tile(tile_row, tile_col, present[rs, cs],
                                   amp_mm[rs, cs], ph_cd[rs, cs])
            (ROOT / "coastal" / f"tile_{tile_row}_{tile_col}.bin").write_bytes(data)
            tiles.append([tile_row, tile_col])

    g_amp = np.zeros((5, 72, 2))
    g_ph = np.zeros((5, 72, 2))
    for r in range(5):
        for c in range(72):
            g_amp[r, c] = [(2000 + 10 * r + c) / 1000.0, 0.05]
            g_ph[r, c] = [90.0, 0.0]
    g_amp[0, 0] = np.nan
    g_amp_mm, g_ph_cd = fmt.quantize(g_amp, g_ph)
    (ROOT / "global.bin").write_bytes(fmt.encode_global(g_amp_mm, g_ph_cd))

    fmt.write_manifest(
        ROOT,
        model="synthetic",
        extraction_date="2026-09-26",
        band_km=30,
        coastal={"latMin": 10.0, "lonMin": -180.0, "resolution": 0.5,
                 "rows": ROWS, "cols": COLS},
        tile_size=TILE,
        tiles=tiles,
        global_={"latMin": 0.0, "lonMin": -180.0, "resolution": 5.0,
                 "rows": 5, "cols": 72},
        constituents=NAMES,
    )
    print(f"Wrote {len(tiles)} tiles and global.bin to {ROOT}")


if __name__ == "__main__":
    main()
```

Run (a venv with numpy is enough; Task 8 creates the full one):
```bash
python3.14 -m venv ~/.venvs/submersion-tide
~/.venvs/submersion-tide/bin/pip install numpy netCDF4
~/.venvs/submersion-tide/bin/python scripts/tide/write_fes_grid_test_fixtures.py
```
Expected: `Wrote 4 tiles and global.bin to test/features/tides/data/fixtures/fes_grid`.

- [ ] **Step 3: Write the failing decoding tests**

Create `test/features/tides/data/fes_grid/fes_grid_decoding_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/tides/data/services/fes_grid/fes_grid_layers.dart';
import 'package:submersion/features/tides/data/services/fes_grid/fes_grid_manifest.dart';

final _root = p.join('test', 'features', 'tides', 'data', 'fixtures', 'fes_grid');

ByteData _bytes(String relative) {
  final list = File(p.join(_root, relative)).readAsBytesSync();
  return ByteData.sublistView(list);
}

void main() {
  late FesGridManifest manifest;

  setUpAll(() {
    manifest = FesGridManifest.parse(
      File(p.join(_root, FesGridManifest.manifestPath)).readAsStringSync(),
    );
  });

  test('manifest describes both layers and the written tiles', () {
    expect(manifest.constituents, ['M2', 'K1']);
    expect(manifest.coastal.resolution, 0.5);
    expect(manifest.coastal.cols, 720);
    expect(manifest.tileSize, 4);
    expect(manifest.coastalTiles, {(0, 0), (1, 0), (0, 179), (1, 179)});
    expect(manifest.global.rows, 5);
    expect(manifest.global.resolutionKm, closeTo(555.975, 0.01));
  });

  test('a manifest of another format is rejected', () {
    expect(
      () => FesGridManifest.parse('{"format":"other","version":1}'),
      throwsFormatException,
    );
    expect(() => FesGridManifest.parse('not json'), throwsFormatException);
  });

  group('FesTile', () {
    late FesTile tile;

    setUp(() {
      tile = FesTile.parse(
        _bytes(FesGridManifest.tilePath(0, 0)),
        expectedConstituents: 2,
      );
    });

    test('reads present cells and their values', () {
      final cell = tile.cellAt(1, 2)!;
      expect(cell.amplitudeMeters(0), closeTo(1.102, 1e-9));
      expect(cell.phaseDegrees(0), closeTo((37 + 22) % 360, 1e-9));
      expect(cell.amplitudeMeters(1), closeTo(0.1, 1e-9));
      expect(cell.phaseDegrees(1), closeTo(350, 1e-9));
    });

    test('absent cells, an empty row and out-of-range cells are null', () {
      expect(tile.cellAt(0, 2), isNull);
      expect(tile.cellAt(1, 0), isNull);
      for (var col = 0; col < 4; col++) {
        expect(tile.cellAt(2, col), isNull);
      }
      expect(tile.cellAt(4, 0), isNull);
      expect(tile.cellAt(-1, 0), isNull);
    });

    test('a constituent can be missing in a present cell', () {
      final cell = tile.cellAt(3, 3)!;
      expect(cell.amplitudeMeters(0), closeTo(1.303, 1e-9));
      expect(cell.amplitudeMeters(1), isNull);
    });

    test('the last cell of a partial edge tile is readable', () {
      final edge = FesTile.parse(
        _bytes(FesGridManifest.tilePath(1, 179)),
        expectedConstituents: 2,
      );
      expect(edge.rows, 1);
      expect(edge.cols, 4);
      expect(edge.cellAt(0, 3)!.amplitudeMeters(0), closeTo(1.4 + 0.719, 1e-9));
    });

    test('malformed bytes are rejected', () {
      expect(
        () => FesTile.parse(ByteData(8), expectedConstituents: 2),
        throwsFormatException,
      );
      final truncated = _bytes(FesGridManifest.tilePath(0, 0));
      expect(
        () => FesTile.parse(
          ByteData.sublistView(truncated, 0, truncated.lengthInBytes - 1),
          expectedConstituents: 2,
        ),
        throwsFormatException,
      );
      expect(
        () => FesTile.parse(
          _bytes(FesGridManifest.tilePath(0, 0)),
          expectedConstituents: 3,
        ),
        throwsFormatException,
      );
    });
  });

  group('FesGlobalLayer', () {
    late FesGlobalLayer layer;

    setUp(() {
      layer = FesGlobalLayer.parse(
        _bytes(FesGridManifest.globalPath),
        expectedConstituents: 2,
      );
    });

    test('reads cells and treats a no-data cell as absent', () {
      expect(layer.cellAt(2, 3)!.amplitudeMeters(0), closeTo(2.023, 1e-9));
      expect(layer.cellAt(2, 3)!.phaseDegrees(0), closeTo(90, 1e-9));
      expect(layer.cellAt(0, 0), isNull);
      expect(layer.cellAt(5, 0), isNull);
    });

    test('malformed bytes are rejected', () {
      expect(
        () => FesGlobalLayer.parse(ByteData(12), expectedConstituents: 2),
        throwsFormatException,
      );
    });
  });
}
```

- [ ] **Step 4: Run the tests to verify they fail**

Run: `flutter test test/features/tides/data/fes_grid/fes_grid_decoding_test.dart`
Expected: FAIL to compile: `fes_grid_layers.dart` and `fes_grid_manifest.dart` not found.

- [ ] **Step 5: Implement the manifest**

Create `lib/features/tides/data/services/fes_grid/fes_grid_manifest.dart`:

```dart
import 'dart:convert';

/// Kilometres per degree of latitude (mean Earth radius 6371 km).
const double kmPerDegree = 111.195;

/// Geometry of one layer of the bundled FES2022 grid. Cell (row, col) is
/// centred on (latMin + row * resolution, lonMin + col * resolution);
/// columns wrap in longitude.
class FesLayerGeometry {
  final double latMin;
  final double lonMin;
  final double resolution;
  final int rows;
  final int cols;

  const FesLayerGeometry({
    required this.latMin,
    required this.lonMin,
    required this.resolution,
    required this.rows,
    required this.cols,
  });

  factory FesLayerGeometry.fromJson(Map<String, dynamic> json) {
    return FesLayerGeometry(
      latMin: (json['latMin'] as num).toDouble(),
      lonMin: (json['lonMin'] as num).toDouble(),
      resolution: (json['resolution'] as num).toDouble(),
      rows: json['rows'] as int,
      cols: json['cols'] as int,
    );
  }

  double get resolutionKm => resolution * kmPerDegree;
}

/// The grid's `manifest.json`, written by `scripts/tide/extract_fes_grid.py`.
class FesGridManifest {
  static const formatName = 'submersion-fes-grid';
  static const supportedVersion = 1;
  static const manifestPath = 'manifest.json';
  static const globalPath = 'global.bin';

  static String tilePath(int tileRow, int tileCol) =>
      'coastal/tile_${tileRow}_$tileCol.bin';

  final String model;
  final String extractionDate;
  final double bandKm;
  final List<String> constituents;
  final FesLayerGeometry coastal;
  final int tileSize;
  final Set<(int, int)> coastalTiles;
  final FesLayerGeometry global;

  const FesGridManifest({
    required this.model,
    required this.extractionDate,
    required this.bandKm,
    required this.constituents,
    required this.coastal,
    required this.tileSize,
    required this.coastalTiles,
    required this.global,
  });

  /// Parses [source]. Throws [FormatException] for anything that is not a
  /// supported manifest, including JSON of the wrong shape.
  static FesGridManifest parse(String source) {
    try {
      final json = jsonDecode(source);
      if (json is! Map<String, dynamic> ||
          json['format'] != formatName ||
          json['version'] != supportedVersion) {
        throw const FormatException('Unsupported FES grid manifest');
      }
      final coastal = json['coastal'] as Map<String, dynamic>;
      return FesGridManifest(
        model: json['model'] as String,
        extractionDate: json['extractionDate'] as String,
        bandKm: (json['bandKm'] as num).toDouble(),
        constituents: (json['constituents'] as List).cast<String>(),
        coastal: FesLayerGeometry.fromJson(coastal),
        tileSize: coastal['tileSize'] as int,
        coastalTiles: {
          for (final tile in (coastal['tiles'] as List).cast<List>())
            (tile[0] as int, tile[1] as int),
        },
        global: FesLayerGeometry.fromJson(
          json['global'] as Map<String, dynamic>,
        ),
      );
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Malformed FES grid manifest: $e');
    }
  }
}
```

- [ ] **Step 6: Implement the layers**

Create `lib/features/tides/data/services/fes_grid/fes_grid_layers.dart`:

```dart
import 'dart:typed_data';

/// Bytes per constituent in a cell: int16 amplitude (mm) and uint16 phase
/// (hundredths of a degree), little-endian.
const int fesBytesPerConstituent = 4;

/// Amplitude marker for a constituent with no data in a cell.
const int fesNoData = -1;

/// A read-only view of one cell's constituent values.
class FesCell {
  final ByteData _data;
  final int _offset;

  const FesCell(this._data, this._offset);

  /// Amplitude in metres, or null when this constituent has no data here.
  double? amplitudeMeters(int index) {
    final mm = _data.getInt16(
      _offset + index * fesBytesPerConstituent,
      Endian.little,
    );
    return mm == fesNoData ? null : mm / 1000.0;
  }

  /// Greenwich phase lag in degrees.
  double phaseDegrees(int index) =>
      _data.getUint16(
        _offset + index * fesBytesPerConstituent + 2,
        Endian.little,
      ) /
      100.0;
}

bool _hasMagic(ByteData data, String magic) {
  if (data.lengthInBytes < magic.length) return false;
  for (var i = 0; i < magic.length; i++) {
    if (data.getUint8(i) != magic.codeUnitAt(i)) return false;
  }
  return true;
}

/// One coastal tile: an occupancy bitmap, per-row counts and packed cells.
class FesTile {
  static const _magic = 'SFT1';
  static const _headerBytes = 16;

  final int tileRow;
  final int tileCol;
  final int rows;
  final int cols;
  final int _constituents;
  final ByteData _data;
  final int _rowCountsOffset;
  final int _cellsOffset;

  FesTile._(
    this._data, {
    required this.tileRow,
    required this.tileCol,
    required this.rows,
    required this.cols,
    required int constituents,
  }) : _constituents = constituents,
       _rowCountsOffset = _headerBytes + (rows * cols + 7) ~/ 8,
       _cellsOffset = _headerBytes + (rows * cols + 7) ~/ 8 + rows * 4;

  /// Parses a tile. Throws [FormatException] for a wrong magic, version,
  /// constituent count or length.
  static FesTile parse(ByteData data, {required int expectedConstituents}) {
    if (data.lengthInBytes < _headerBytes || !_hasMagic(data, _magic)) {
      throw const FormatException('Not an FES grid tile');
    }
    final version = data.getUint16(4, Endian.little);
    if (version != 1) {
      throw FormatException('Unsupported FES tile version $version');
    }
    final count = data.getUint16(14, Endian.little);
    if (count != expectedConstituents) {
      throw FormatException(
        'FES tile has $count constituents, expected $expectedConstituents',
      );
    }
    final tile = FesTile._(
      data,
      tileRow: data.getInt16(6, Endian.little),
      tileCol: data.getInt16(8, Endian.little),
      rows: data.getUint16(10, Endian.little),
      cols: data.getUint16(12, Endian.little),
      constituents: count,
    );
    if (data.lengthInBytes < tile._cellsOffset) {
      throw const FormatException('FES tile is truncated');
    }
    final expectedLength =
        tile._cellsOffset +
        tile._populatedCount() * count * fesBytesPerConstituent;
    if (data.lengthInBytes != expectedLength) {
      throw const FormatException('FES tile length does not match its bitmap');
    }
    return tile;
  }

  bool _isSet(int bit) =>
      ((_data.getUint8(_headerBytes + (bit >> 3)) >> (bit & 7)) & 1) == 1;

  int _populatedCount() {
    if (rows == 0) return 0;
    var count = _data.getUint32(_rowCountsOffset + (rows - 1) * 4, Endian.little);
    for (var bit = (rows - 1) * cols; bit < rows * cols; bit++) {
      if (_isSet(bit)) count++;
    }
    return count;
  }

  /// The cell at tile-local ([row], [col]), or null when absent.
  FesCell? cellAt(int row, int col) {
    if (row < 0 || row >= rows || col < 0 || col >= cols) return null;
    final bit = row * cols + col;
    if (!_isSet(bit)) return null;
    var index = _data.getUint32(_rowCountsOffset + row * 4, Endian.little);
    for (var b = row * cols; b < bit; b++) {
      if (_isSet(b)) index++;
    }
    return FesCell(
      _data,
      _cellsOffset + index * _constituents * fesBytesPerConstituent,
    );
  }
}

/// The dense 1-degree global layer.
class FesGlobalLayer {
  static const _magic = 'SFG1';
  static const _headerBytes = 12;

  final int rows;
  final int cols;
  final int _constituents;
  final ByteData _data;

  FesGlobalLayer._(this._data, this.rows, this.cols, this._constituents);

  /// Parses the global layer. Throws [FormatException] when malformed.
  static FesGlobalLayer parse(
    ByteData data, {
    required int expectedConstituents,
  }) {
    if (data.lengthInBytes < _headerBytes || !_hasMagic(data, _magic)) {
      throw const FormatException('Not an FES global layer');
    }
    final version = data.getUint16(4, Endian.little);
    final rows = data.getUint16(6, Endian.little);
    final cols = data.getUint16(8, Endian.little);
    final count = data.getUint16(10, Endian.little);
    if (version != 1 || count != expectedConstituents) {
      throw const FormatException('Unsupported FES global layer');
    }
    if (data.lengthInBytes !=
        _headerBytes + rows * cols * count * fesBytesPerConstituent) {
      throw const FormatException('FES global layer length mismatch');
    }
    return FesGlobalLayer._(data, rows, cols, count);
  }

  /// The cell at ([row], [col]), or null when out of range or without data
  /// (a cell's validity is its first constituent's, M2 in the real grid).
  FesCell? cellAt(int row, int col) {
    if (row < 0 || row >= rows || col < 0 || col >= cols) return null;
    final cell = FesCell(
      _data,
      _headerBytes +
          (row * cols + col) * _constituents * fesBytesPerConstituent,
    );
    return cell.amplitudeMeters(0) == null ? null : cell;
  }
}
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/features/tides/data/fes_grid/fes_grid_decoding_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format lib/features/tides/data/services/fes_grid test/features/tides/data/fes_grid
flutter analyze lib/features/tides/data/services/fes_grid test/features/tides/data/fes_grid
git add scripts/tide/fes_grid_format.py scripts/tide/write_fes_grid_test_fixtures.py test/features/tides/data/fixtures/fes_grid lib/features/tides/data/services/fes_grid/fes_grid_manifest.dart lib/features/tides/data/services/fes_grid/fes_grid_layers.dart test/features/tides/data/fes_grid/fes_grid_decoding_test.dart
git commit -m "Add the binary FES grid format with a shared Python encoder and Dart decoder"
```

---

### Task 7: FES grid reader and interpolation

**Files:**
- Create: `lib/features/tides/data/services/fes_grid/fes_grid_reader.dart`
- Create: `test/features/tides/data/fes_grid/fes_grid_reader_test.dart`

**Interfaces:**
- Consumes: `FesGridManifest`, `FesTile`, `FesGlobalLayer`, `FesCell`, `FesLayerGeometry` (Task 6).
- Produces:
  - `class FesGridSample { final Map<String, TideConstituent> constituents; final double resolutionKm; }`
  - `class FesGridReader { FesGridReader({required Future<ByteData> Function(String relativePath) load}); factory FesGridReader.bundled(); static const bundledRoot = 'assets/data/tide/fes'; Future<FesGridManifest?> manifest(); Future<FesGridSample?> sampleAt(double latitude, double longitude); }`

- [ ] **Step 1: Write the failing tests**

Create `test/features/tides/data/fes_grid/fes_grid_reader_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/tides/data/services/fes_grid/fes_grid_reader.dart';

final _root = p.join('test', 'features', 'tides', 'data', 'fixtures', 'fes_grid');

Future<ByteData> _fileLoader(String relative) async =>
    ByteData.sublistView(File(p.join(_root, relative)).readAsBytesSync());

FesGridReader _reader({Map<String, ByteData Function()> replace = const {}}) {
  return FesGridReader(
    load: (relative) async {
      final replacement = replace[relative];
      if (replacement != null) return replacement();
      return _fileLoader(relative);
    },
  );
}

void main() {
  test('a grid node returns that cell (coastal resolution)', () async {
    final sample = await _reader().sampleAt(10.0, -180.0);
    expect(sample!.resolutionKm, closeTo(55.6, 0.1));
    expect(sample.constituents['M2']!.amplitude, closeTo(1.0, 1e-6));
    expect(sample.constituents['M2']!.phase, closeTo(0.0, 1e-6));
  });

  test('phases interpolate across the 0/360 wrap', () async {
    // Halfway between (0,0) K1 350 deg and (0,1) K1 10 deg.
    final k1 = (await _reader().sampleAt(10.0, -179.75))!.constituents['K1']!;
    expect(k1.phase % 360, anyOf(closeTo(0, 0.01), closeTo(360, 0.01)));
    expect(k1.amplitude, closeTo(0.1 * 0.98481, 1e-4));
  });

  test('opposed phases cancel in the complex plane', () async {
    // Row 3: col 0 at 0 deg and col 1 at 180 deg, amplitudes 1.300/1.301 m.
    final m2 = (await _reader().sampleAt(11.5, -179.75))!.constituents['M2']!;
    expect(m2.amplitude, lessThan(0.001));
  });

  test('missing corners are dropped and weights renormalized', () async {
    // Cell (1,0) is absent; the three present corners average equally.
    final sample = await _reader().sampleAt(10.25, -179.75);
    expect(sample!.resolutionKm, closeTo(55.6, 0.1));
    expect(sample.constituents['M2'], isNotNull);
  });

  test('a node without data resolves from its present neighbours', () async {
    // (1,0) is absent; its neighbour (1,1) is present with a tiny weight.
    final sample = await _reader().sampleAt(10.5, -180.0);
    expect(sample, isNotNull);
    expect(sample!.resolutionKm, closeTo(55.6, 0.1));
  });

  test('a constituent missing at the only weighted corner is omitted', () async {
    final sample = await _reader().sampleAt(11.5, -178.5);
    expect(sample!.constituents.containsKey('M2'), isTrue);
    expect(sample.constituents.containsKey('K1'), isFalse);
  });

  test('columns wrap across the antimeridian', () async {
    final sample = await _reader().sampleAt(10.0, 179.9);
    expect(sample!.resolutionKm, closeTo(55.6, 0.1));
  });

  test('outside the coastal band the global layer answers', () async {
    final sample = await _reader().sampleAt(10.25, -170.0);
    expect(sample!.resolutionKm, closeTo(555.975, 0.01));
    expect(sample.constituents['M2']!.phase, closeTo(90, 1e-6));
  });

  test('an unreadable or malformed tile falls back to the global layer', () async {
    final missing = await _reader(
      replace: {'coastal/tile_0_0.bin': () => throw const FileSystemException('gone')},
    ).sampleAt(10.0, -180.0);
    expect(missing!.resolutionKm, closeTo(555.975, 0.01));

    final garbage = await _reader(
      replace: {'coastal/tile_0_0.bin': () => ByteData(20)},
    ).sampleAt(10.0, -180.0);
    expect(garbage!.resolutionKm, closeTo(555.975, 0.01));
  });

  test('a malformed manifest yields no data', () async {
    final reader = _reader(
      replace: {
        'manifest.json': () => ByteData.sublistView(
          Uint8List.fromList('{"format":"x"}'.codeUnits),
        ),
      },
    );
    expect(await reader.manifest(), isNull);
    expect(await reader.sampleAt(10.0, -180.0), isNull);
  });

  test('beyond both layers there is no data', () async {
    expect(await _reader().sampleAt(60.0, 0.0), isNull);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/tides/data/fes_grid/fes_grid_reader_test.dart`
Expected: FAIL to compile: `fes_grid_reader.dart` not found.

- [ ] **Step 3: Implement the reader**

Create `lib/features/tides/data/services/fes_grid/fes_grid_reader.dart`:

```dart
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'package:submersion/core/tide/entities/tide_constituent.dart';
import 'package:submersion/features/tides/data/services/fes_grid/fes_grid_layers.dart';
import 'package:submersion/features/tides/data/services/fes_grid/fes_grid_manifest.dart';

/// Constituents interpolated at a point, and the grid spacing behind them.
class FesGridSample {
  final Map<String, TideConstituent> constituents;
  final double resolutionKm;

  const FesGridSample({required this.constituents, required this.resolutionKm});
}

/// Reads the bundled FES2022 grid: the 0.1-degree coastal tiles first, the
/// 1-degree global layer when no coastal corner has data, else nothing.
/// Tiles load on demand and stay cached for the reader's lifetime. Every
/// failure (missing or malformed file) degrades to the next layer and is
/// logged; nothing throws to the caller.
class FesGridReader {
  static const bundledRoot = 'assets/data/tide/fes';

  final Future<ByteData> Function(String relativePath) _load;
  Future<FesGridManifest?>? _manifest;
  Future<FesGlobalLayer?>? _global;
  final Map<(int, int), Future<FesTile?>> _tiles = {};

  FesGridReader({required Future<ByteData> Function(String relativePath) load})
    : _load = load;

  factory FesGridReader.bundled() =>
      FesGridReader(load: (relative) => rootBundle.load('$bundledRoot/$relative'));

  Future<FesGridManifest?> manifest() => _manifest ??= _loadManifest();

  Future<FesGridSample?> sampleAt(double latitude, double longitude) async {
    final m = await manifest();
    if (m == null) return null;

    final coastal = await _coastalCorners(m, latitude, longitude);
    final fromCoastal = _interpolate(m.constituents, coastal);
    if (fromCoastal != null) {
      return FesGridSample(
        constituents: fromCoastal,
        resolutionKm: m.coastal.resolutionKm,
      );
    }

    final global = await _globalCorners(m, latitude, longitude);
    final fromGlobal = _interpolate(m.constituents, global);
    if (fromGlobal != null) {
      return FesGridSample(
        constituents: fromGlobal,
        resolutionKm: m.global.resolutionKm,
      );
    }
    return null;
  }

  Future<FesGridManifest?> _loadManifest() async {
    try {
      final data = await _load(FesGridManifest.manifestPath);
      return FesGridManifest.parse(
        utf8.decode(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        ),
      );
    } catch (e) {
      developer.log('FES grid manifest unreadable: $e', name: 'FesGridReader');
      return null;
    }
  }

  Future<FesTile?> _tile(FesGridManifest m, int tileRow, int tileCol) {
    return _tiles[(tileRow, tileCol)] ??= () async {
      try {
        final data = await _load(FesGridManifest.tilePath(tileRow, tileCol));
        return FesTile.parse(
          data,
          expectedConstituents: m.constituents.length,
        );
      } catch (e) {
        developer.log(
          'FES tile $tileRow,$tileCol unreadable: $e',
          name: 'FesGridReader',
        );
        return null;
      }
    }();
  }

  Future<FesGlobalLayer?> _globalLayer(FesGridManifest m) {
    return _global ??= () async {
      try {
        final layer = FesGlobalLayer.parse(
          await _load(FesGridManifest.globalPath),
          expectedConstituents: m.constituents.length,
        );
        if (layer.rows != m.global.rows || layer.cols != m.global.cols) {
          throw const FormatException('Global layer disagrees with manifest');
        }
        return layer;
      } catch (e) {
        developer.log('FES global layer unreadable: $e', name: 'FesGridReader');
        return null;
      }
    }();
  }

  Future<List<(FesCell, double)>> _coastalCorners(
    FesGridManifest m,
    double latitude,
    double longitude,
  ) async {
    final corners = <(FesCell, double)>[];
    for (final (row, col, weight) in _cornersFor(m.coastal, latitude, longitude)) {
      if (row < 0 || row >= m.coastal.rows) continue;
      final tileRow = row ~/ m.tileSize;
      final tileCol = col ~/ m.tileSize;
      if (!m.coastalTiles.contains((tileRow, tileCol))) continue;
      final tile = await _tile(m, tileRow, tileCol);
      final cell = tile?.cellAt(
        row - tileRow * m.tileSize,
        col - tileCol * m.tileSize,
      );
      if (cell != null) corners.add((cell, weight));
    }
    return corners;
  }

  Future<List<(FesCell, double)>> _globalCorners(
    FesGridManifest m,
    double latitude,
    double longitude,
  ) async {
    final layer = await _globalLayer(m);
    if (layer == null) return const [];
    final corners = <(FesCell, double)>[];
    for (final (row, col, weight) in _cornersFor(m.global, latitude, longitude)) {
      final cell = layer.cellAt(row, col);
      if (cell != null) corners.add((cell, weight));
    }
    return corners;
  }

  /// The four cells around a point with bilinear weights. Columns wrap; rows
  /// may fall outside the layer and are filtered by the caller. Weights are
  /// floored at 1e-9 so a point exactly on a missing node still resolves
  /// from its present neighbours.
  static List<(int, int, double)> _cornersFor(
    FesLayerGeometry g,
    double latitude,
    double longitude,
  ) {
    final y = (latitude - g.latMin) / g.resolution;
    final x = ((longitude - g.lonMin) % 360.0) / g.resolution;
    final r0 = y.floor();
    final c0 = x.floor();
    final fy = y - r0;
    final fx = x - c0;
    double floor(double w) => math.max(w, 1e-9);
    return [
      (r0, c0 % g.cols, floor((1 - fy) * (1 - fx))),
      (r0, (c0 + 1) % g.cols, floor((1 - fy) * fx)),
      (r0 + 1, c0 % g.cols, floor(fy * (1 - fx))),
      (r0 + 1, (c0 + 1) % g.cols, floor(fy * fx)),
    ];
  }

  /// Weighted average of each constituent as a complex number
  /// amplitude * e^(i * phase), renormalized over the corners that have it.
  static Map<String, TideConstituent>? _interpolate(
    List<String> names,
    List<(FesCell, double)> corners,
  ) {
    if (corners.isEmpty) return null;
    final result = <String, TideConstituent>{};
    for (var k = 0; k < names.length; k++) {
      var re = 0.0;
      var im = 0.0;
      var weightSum = 0.0;
      for (final (cell, weight) in corners) {
        final amplitude = cell.amplitudeMeters(k);
        if (amplitude == null) continue;
        final phase = cell.phaseDegrees(k) * math.pi / 180;
        re += weight * amplitude * math.cos(phase);
        im += weight * amplitude * math.sin(phase);
        weightSum += weight;
      }
      if (weightSum <= 0) continue;
      var phase = math.atan2(im, re) * 180 / math.pi;
      if (phase < 0) phase += 360;
      result[names[k]] = TideConstituent(
        name: names[k],
        amplitude: math.sqrt(re * re + im * im) / weightSum,
        phase: phase,
      );
    }
    return result.isEmpty ? null : result;
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/tides/data/fes_grid`
Expected: PASS (all reader and decoding tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/tides/data/services/fes_grid test/features/tides/data/fes_grid
flutter analyze lib/features/tides/data/services/fes_grid test/features/tides/data/fes_grid
git add lib/features/tides/data/services/fes_grid/fes_grid_reader.dart test/features/tides/data/fes_grid/fes_grid_reader_test.dart
git commit -m "Read the FES grid with complex-plane interpolation and layer fallback"
```

---

### Task 8: Extract the real grid and prove its accuracy

**Files:**
- Create: `scripts/tide/extract_fes_grid.py`
- Create (generated): `assets/data/tide/fes/manifest.json`, `assets/data/tide/fes/global.bin`, `assets/data/tide/fes/coastal/tile_*.bin` (about 393 files, about 58 MB in total)
- Create (generated): `test/features/tides/data/fixtures/fes_native_vectors.json`
- Modify: `pubspec.yaml` (assets list, around line 222)
- Create: `test/features/tides/data/fes_grid/fes_grid_accuracy_test.dart`

**Interfaces:**
- Consumes: `fes_grid_format.py` (Task 6); `FesGridReader.bundled()` (Task 7); `constituentSpeeds` from `lib/core/tide/constants/harmonic_constituents.dart`.
- Produces: the bundled assets under `assets/data/tide/fes/`.

- [ ] **Step 1: Write the extraction script**

Create `scripts/tide/extract_fes_grid.py`:

```python
#!/usr/bin/env python3
"""Extract Submersion's bundled FES2022 tide grid from FES2022b NetCDF files.

Writes assets/data/tide/fes/ (manifest, 1-degree global layer, 0.1-degree
coastal tiles) and the accuracy fixture
test/features/tides/data/fixtures/fes_native_vectors.json in one pass.

Needs about 3 GB of RAM and a venv with numpy and netCDF4:
    python3.14 -m venv ~/.venvs/submersion-tide
    ~/.venvs/submersion-tide/bin/pip install numpy netCDF4

Usage (from the repo root):
    ~/.venvs/submersion-tide/bin/python scripts/tide/extract_fes_grid.py \\
        --fes-dir ~/repos/fes2022b/ocean_tide_extrapolated
    ~/.venvs/submersion-tide/bin/python scripts/tide/extract_fes_grid.py \\
        --fes-dir ~/repos/fes2022b/ocean_tide_extrapolated --verify
"""

import argparse
import datetime
import json
import math
import random
import shutil
import sys
from pathlib import Path

import netCDF4 as nc
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fes_grid_format as fmt  # noqa: E402

OUT = Path("assets/data/tide/fes")
VECTORS_OUT = Path("test/features/tides/data/fixtures/fes_native_vectors.json")
NATIVE = 30  # native cells per degree
LAT_MIN, LAT_MAX = -80, 80
COASTAL_STEP = 3  # native cells per coastal cell: 0.1 degree
GLOBAL_STEP = 30  # native cells per global cell: 1 degree
BAND_STEPS = 8  # 4-neighbour native steps from non-ocean: about 30 km
TILE = 100

FILE_NAMES = {
    "M2": "m2", "S2": "s2", "N2": "n2", "K2": "k2", "2N2": "2n2",
    "Mu2": "mu2", "Nu2": "nu2", "L2": "l2", "T2": "t2", "Eps2": "eps2",
    "La2": "lambda2", "R2": "r2", "K1": "k1", "O1": "o1", "P1": "p1",
    "Q1": "q1", "J1": "j1", "Mf": "mf", "Mm": "mm", "Ssa": "ssa", "Sa": "sa",
    "Msqm": "msqm", "Mtm": "mtm", "M4": "m4", "MS4": "ms4",
}

# Public dive sites for the accuracy fixture (lat, lon).
VECTOR_SITES = [
    ("Bonaire", 12.10, -68.29), ("Cozumel", 20.35, -87.03),
    ("Escambron", 18.47, -66.09), ("Vieques", 18.10, -65.47),
    ("Koh Tao", 10.10, 99.84), ("Tulamben", -8.27, 115.59),
    ("Komodo", -8.55, 119.55), ("Gili", -8.35, 116.04),
    ("Raja Ampat", -0.55, 130.55), ("Cornwall", 50.07, -5.70),
    ("Nanaimo", 49.17, -123.94), ("Monterey", 36.62, -121.90),
    ("Cairns", -16.75, 145.98), ("Sharm el Sheikh", 27.85, 34.32),
    ("Malta", 36.05, 14.19), ("Roatan", 16.33, -86.53),
    ("Grand Cayman", 19.35, -81.38), ("Tenerife", 28.05, -16.73),
    ("Sipadan", 4.11, 118.63), ("Galapagos", -0.75, -90.30),
    ("Blue Hole", 17.32, -87.53), ("Maldives", 4.18, 73.52),
    ("Fiji Beqa", -18.40, 178.10), ("Lembeh", 1.45, 125.23),
    ("Anilao", 13.76, 120.92), ("Chuuk", 7.42, 151.78),
    ("Scapa Flow", 58.90, -3.20), ("Poor Knights", -35.47, 174.73),
    ("Ningaloo", -22.00, 113.90), ("Palau", 7.13, 134.22),
    ("Hurghada", 27.25, 33.83),
]


def lat_indices(step, count):
    return (LAT_MIN + 90) * NATIVE + np.arange(count) * step


def lon_indices(step, count):
    # Layer column j is centred on -180 + j*step/30 degrees; native starts at 0.
    return (180 * NATIVE + np.arange(count) * step) % (360 * NATIVE)


def load(fes_dir, name):
    ds = nc.Dataset(fes_dir / f"{FILE_NAMES[name]}_fes2022.nc")
    lat, lon = ds["lat"][:], ds["lon"][:]
    if len(lat) != 5401 or len(lon) != 10800 or lat[0] != -90 or lon[0] != 0:
        raise SystemExit(f"{name}: unexpected native grid")
    amp = np.ma.filled(ds["amplitude"][:].astype(np.float32), np.nan) / 100.0
    ph = np.ma.filled(ds["phase"][:].astype(np.float32), np.nan)
    ds.close()
    return amp, ph


def coastal_band(fes_dir):
    mask = np.ma.filled(nc.Dataset(fes_dir / "mask_fes2022B.nc")["mask"][:], 2)
    band = mask != 0  # extrapolated, land and lake cells seed the band
    for _ in range(BAND_STEPS):
        band = (band | np.roll(band, 1, 0) | np.roll(band, -1, 0)
                | np.roll(band, 1, 1) | np.roll(band, -1, 1))
    return band


def native_sample(amp, ph, lat, lon):
    """Complex bilinear interpolation on the native grid (the fixture oracle)."""
    y = (lat + 90) * NATIVE
    x = (lon % 360) * NATIVE
    r0, c0 = int(math.floor(y)), int(math.floor(x))
    fy, fx = y - r0, x - c0
    num, weights = 0j, 0.0
    for r, c, w in ((r0, c0, (1 - fy) * (1 - fx)), (r0, c0 + 1, (1 - fy) * fx),
                    (r0 + 1, c0, fy * (1 - fx)), (r0 + 1, c0 + 1, fy * fx)):
        a, p = amp[r, c % 10800], ph[r, c % 10800]
        if not (np.isfinite(a) and np.isfinite(p)):
            continue
        w = max(w, 1e-9)
        num += w * a * complex(math.cos(math.radians(p)), math.sin(math.radians(p)))
        weights += w
    if weights == 0:
        return None
    z = num / weights
    return {"amplitude": round(abs(z), 6), "phase": round(math.degrees(math.atan2(z.imag, z.real)) % 360, 4)}


def extract(fes_dir):
    rows_c, cols_c = (LAT_MAX - LAT_MIN) * 10 + 1, 3600
    rows_g, cols_g = LAT_MAX - LAT_MIN + 1, 360
    li_c, lo_c = lat_indices(COASTAL_STEP, rows_c), lon_indices(COASTAL_STEP, cols_c)
    li_g, lo_g = lat_indices(GLOBAL_STEP, rows_g), lon_indices(GLOBAL_STEP, cols_g)
    count = len(fmt.CONSTITUENTS)

    amp_c = np.empty((rows_c, cols_c, count), np.float32)
    ph_c = np.empty_like(amp_c)
    amp_g = np.empty((rows_g, cols_g, count), np.float32)
    ph_g = np.empty_like(amp_g)
    vectors = {name: {} for name, _, _ in VECTOR_SITES}

    for k, name in enumerate(fmt.CONSTITUENTS):
        print(f"  {name}")
        amp, ph = load(fes_dir, name)
        amp_c[:, :, k] = amp[np.ix_(li_c, lo_c)]
        ph_c[:, :, k] = ph[np.ix_(li_c, lo_c)]
        amp_g[:, :, k] = amp[np.ix_(li_g, lo_g)]
        ph_g[:, :, k] = ph[np.ix_(li_g, lo_g)]
        for site, lat, lon in VECTOR_SITES:
            value = native_sample(amp, ph, lat, lon)
            if value is not None:
                vectors[site][name] = value
        del amp, ph

    present_c = np.isfinite(amp_c[:, :, 0]) & coastal_band(fes_dir)[np.ix_(li_c, lo_c)]
    amp_g[~np.isfinite(amp_g[:, :, 0])] = np.nan
    return amp_c, ph_c, present_c, amp_g, ph_g, vectors


def write(amp_c, ph_c, present_c, amp_g, ph_g, vectors):
    shutil.rmtree(OUT / "coastal", ignore_errors=True)
    (OUT / "coastal").mkdir(parents=True)
    rows_c, cols_c = present_c.shape
    tiles = []
    for tile_row in range((rows_c + TILE - 1) // TILE):
        for tile_col in range(cols_c // TILE):
            rs = slice(tile_row * TILE, min((tile_row + 1) * TILE, rows_c))
            cs = slice(tile_col * TILE, (tile_col + 1) * TILE)
            if not present_c[rs, cs].any():
                continue
            # Quantize per tile to keep peak memory near the float32 arrays.
            amp_mm, ph_cd = fmt.quantize(amp_c[rs, cs], ph_c[rs, cs])
            data = fmt.encode_tile(tile_row, tile_col, present_c[rs, cs],
                                   amp_mm, ph_cd)
            (OUT / "coastal" / f"tile_{tile_row}_{tile_col}.bin").write_bytes(data)
            tiles.append([tile_row, tile_col])

    g_amp_mm, g_ph_cd = fmt.quantize(amp_g, ph_g)
    (OUT / "global.bin").write_bytes(fmt.encode_global(g_amp_mm, g_ph_cd))
    fmt.write_manifest(
        OUT, model="FES2022b",
        extraction_date=datetime.date.today().isoformat(), band_km=30,
        coastal={"latMin": float(LAT_MIN), "lonMin": -180.0, "resolution": 0.1,
                 "rows": rows_c, "cols": cols_c},
        tile_size=TILE, tiles=tiles,
        global_={"latMin": float(LAT_MIN), "lonMin": -180.0, "resolution": 1.0,
                 "rows": amp_g.shape[0], "cols": amp_g.shape[1]},
    )
    VECTORS_OUT.write_text(json.dumps({
        "source": "FES2022b native 1/30 degree, complex bilinear interpolation",
        "sites": [{"name": name, "lat": lat, "lon": lon, "constituents": vectors[name]}
                  for name, lat, lon in VECTOR_SITES],
    }, indent=1) + "\n")
    size = sum(f.stat().st_size for f in OUT.rglob("*.bin"))
    print(f"Wrote {len(tiles)} tiles, {int(present_c.sum())} coastal cells, "
          f"{size / 1e6:.1f} MB")


def verify(fes_dir):
    manifest = json.loads((OUT / "manifest.json").read_text())
    li_c = lat_indices(COASTAL_STEP, manifest["coastal"]["rows"])
    lo_c = lon_indices(COASTAL_STEP, manifest["coastal"]["cols"])
    rng = random.Random(1)
    picks = []
    for tile_row, tile_col in rng.sample(manifest["coastal"]["tiles"], 40):
        data = (OUT / "coastal" / f"tile_{tile_row}_{tile_col}.bin").read_bytes()
        _, _, present, amp_mm, ph_cd = fmt.decode_tile(data)
        rows, cols = np.nonzero(present)
        for i in rng.sample(range(len(rows)), min(50, len(rows))):
            r, c = int(rows[i]), int(cols[i])
            picks.append((tile_row * TILE + r, tile_col * TILE + c,
                          amp_mm[r, c], ph_cd[r, c]))
    worst_amp, worst_ph = 0.0, 0.0
    for k, name in enumerate(fmt.CONSTITUENTS):
        amp, ph = load(fes_dir, name)
        for row, col, stored_amp, stored_ph in picks:
            a, p = amp[li_c[row], lo_c[col]], ph[li_c[row], lo_c[col]]
            if not np.isfinite(a):
                if stored_amp[k] != fmt.NO_DATA:
                    raise SystemExit(f"{name} {row},{col}: data where source has none")
                continue
            worst_amp = max(worst_amp, abs(stored_amp[k] / 1000.0 - a))
            diff = abs((stored_ph[k] / 100.0 - p + 180) % 360 - 180)
            worst_ph = max(worst_ph, diff)
        del amp, ph
    print(f"Checked {len(picks)} cells: worst amplitude {worst_amp * 1000:.2f} mm, "
          f"worst phase {worst_ph:.4f} deg")
    if worst_amp > 0.001 or worst_ph > 0.01:
        raise SystemExit("verification failed: error above the quantization bound")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fes-dir", type=Path, required=True)
    parser.add_argument("--verify", action="store_true",
                        help="check written tiles against the NetCDF source")
    args = parser.parse_args()
    fes_dir = args.fes_dir.expanduser()
    if args.verify:
        verify(fes_dir)
        return
    print("Loading constituents")
    write(*extract(fes_dir))


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run the extraction and the verification**

Run:
```bash
~/.venvs/submersion-tide/bin/python scripts/tide/extract_fes_grid.py --fes-dir ~/repos/fes2022b/ocean_tide_extrapolated
~/.venvs/submersion-tide/bin/python scripts/tide/extract_fes_grid.py --fes-dir ~/repos/fes2022b/ocean_tide_extrapolated --verify
```
Expected: `Wrote 393 tiles, 516267 coastal cells, 58.1 MB` (the counts measured during design; the MB figure within a few percent), then `Checked ... cells: worst amplitude 0.50 mm, worst phase 0.0050 deg` or smaller, with no `verification failed`.

- [ ] **Step 3: Declare the assets**

In `pubspec.yaml`, under `flutter: assets:`, after `    - assets/data/tide/`, add:

```yaml
    - assets/data/tide/fes/
    - assets/data/tide/fes/coastal/
```

Run: `flutter pub get`

- [ ] **Step 4: Write the accuracy test**

Create `test/features/tides/data/fes_grid/fes_grid_accuracy_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// tide.dart also exports constituentSpeeds.
import 'package:submersion/core/tide/tide.dart';
import 'package:submersion/features/tides/data/services/fes_grid/fes_grid_reader.dart';

/// Documented exceptions to the 12-minute limit. Vieques has a near-flat
/// mixed tide (0.7 cm height error), so its extreme times are poorly
/// defined; the Maldives atolls fall below the mask's resolution and use the
/// 1-degree global layer.
const _timeLimitMinutes = {'Vieques': 40.0, 'Maldives': 15.0};

double _p90(List<double> values) {
  final sorted = [...values]..sort();
  return sorted[((sorted.length - 1) * 0.9).round()];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final reader = FesGridReader.bundled();
  final vectors =
      json.decode(
            File(
              p.join('test', 'features', 'tides', 'data', 'fixtures', 'fes_native_vectors.json'),
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  test('the bundled grid only carries constituents the engine can predict', () async {
    final manifest = await reader.manifest();
    expect(manifest, isNotNull);
    expect(manifest!.constituents, hasLength(25));
    expect(
      manifest.constituents.toSet().difference(constituentSpeeds.keys.toSet()),
      isEmpty,
    );
  });

  test('a salt-water site geocoded deep inland has no model data', () async {
    expect(await reader.sampleAt(23.0, 12.0), isNull); // central Sahara
  });

  for (final site in (vectors['sites'] as List).cast<Map<String, dynamic>>()) {
    final name = site['name'] as String;
    test('$name matches native FES2022 within tolerance', () async {
      final sample = await reader.sampleAt(
        (site['lat'] as num).toDouble(),
        (site['lon'] as num).toDouble(),
      );
      expect(sample, isNotNull, reason: '$name has no grid data');
      final native = TideCalculator(
        constituents: {
          for (final entry
              in (site['constituents'] as Map<String, dynamic>).entries)
            entry.key: TideConstituent(
              name: entry.key,
              amplitude: ((entry.value as Map)['amplitude'] as num).toDouble(),
              phase: ((entry.value as Map)['phase'] as num).toDouble(),
            ),
        },
      );
      final ours = TideCalculator(constituents: sample!.constituents);
      final start = DateTime.utc(2026, 6, 1);
      final end = DateTime.utc(2026, 6, 16);
      final expected = native.findExtremes(start: start, end: end);
      final actual = ours.findExtremes(start: start, end: end);

      final timeErrors = <double>[];
      final heightErrors = <double>[];
      for (final e in expected) {
        TideExtreme? best;
        for (final a in actual) {
          if (a.type != e.type) continue;
          if (best == null ||
              a.time.difference(e.time).abs() <
                  best.time.difference(e.time).abs()) {
            best = a;
          }
        }
        if (best == null ||
            best.time.difference(e.time).abs() > const Duration(hours: 3)) {
          continue;
        }
        timeErrors.add(best.time.difference(e.time).inSeconds.abs() / 60);
        heightErrors.add((best.heightMeters - e.heightMeters).abs());
      }

      expect(timeErrors.length, greaterThanOrEqualTo(expected.length * 0.9));
      expect(_p90(heightErrors), lessThanOrEqualTo(0.05), reason: name);
      expect(
        _p90(timeErrors),
        lessThanOrEqualTo(_timeLimitMinutes[name] ?? 12.0),
        reason: name,
      );
    });
  }
}
```

- [ ] **Step 5: Run the accuracy test**

Run: `flutter test test/features/tides/data/fes_grid/fes_grid_accuracy_test.dart`
Expected: PASS (33 tests). If a site fails, report its measured p90 values and stop; do not loosen a limit without the maintainer's approval.

- [ ] **Step 6: Commit**

```bash
dart format test/features/tides/data/fes_grid
git add scripts/tide/extract_fes_grid.py assets/data/tide/fes pubspec.yaml test/features/tides/data/fixtures/fes_native_vectors.json test/features/tides/data/fes_grid/fes_grid_accuracy_test.dart
git commit -m "Bundle an 11 km coastal FES2022 grid and verify it against native resolution"
```

---

### Task 9: Switch the model tier to the new grid and remove the old one

**Files:**
- Modify: `lib/features/tides/data/services/tide_data_service.dart` (rewrite)
- Modify: `lib/features/tides/data/services/tide_constituent_resolver.dart` (`TideDataSource`, `resolve`)
- Modify: `test/features/tides/data/tide_constituent_resolver_test.dart` (`_FakeFesService`, one new test)
- Delete: `assets/data/tide/constituents_grid.json`, `assets/data/tide/metadata.json`
- Delete: `scripts/tide/extract_fes_constituents.py`, `scripts/tide/generate_fes_config.py`, `scripts/tide/export_dive_sites.dart`, `scripts/tide/requirements.txt`
- Modify: `scripts/tide/README.md` (rewrite), `docs/README.md` (the FES extraction block, around lines 150-190)

**Interfaces:**
- Consumes: `FesGridReader`, `FesGridSample` (Task 7).
- Produces:
  - `class FesModelData { final TideCalculator calculator; final double resolutionKm; }` in `tide_data_service.dart`
  - `TideDataService({FesGridReader? reader})`, `Future<FesModelData?> getModelForLocation(double latitude, double longitude)`; `getCalculatorForLocation`, `hasTideData`, `getMetadata` keep their signatures.
  - `TideDataSource.fesModel({this.resolutionKm})` and a `final double? resolutionKm` field (null on the station tier).

- [ ] **Step 1: Write the failing resolver test**

In `test/features/tides/data/tide_constituent_resolver_test.dart`, replace `_FakeFesService` with:

```dart
/// FES stand-in returning a fixed calculator for any location.
class _FakeFesService extends TideDataService {
  final TideCalculator? calculator;
  _FakeFesService(this.calculator);

  @override
  Future<FesModelData?> getModelForLocation(
    double latitude,
    double longitude,
  ) async => calculator == null
      ? null
      : FesModelData(calculator: calculator!, resolutionKm: 11.1);
}
```

and add, inside `main()` after the existing FES-tier tests:

```dart
  test('the model tier reports its grid resolution', () async {
    final client = MockClient((request) async => http.Response('x', 500));
    final r = resolver(client: client, fes: fesCalculator);

    final resolved = await r.resolve(-17.5, 177.5); // no station index
    expect(resolved!.source.kind, TideDataSourceKind.fesModel);
    expect(resolved.source.resolutionKm, 11.1);
  });
```

(`resolver(...)` is the file's existing helper; without `idx` there is no station tier.)

- [ ] **Step 2: Run the resolver test to verify it fails**

Run: `flutter test test/features/tides/data/tide_constituent_resolver_test.dart`
Expected: FAIL to compile: `FesModelData` and `resolutionKm` are not defined.

- [ ] **Step 3: Rewrite `TideDataService`**

Replace the whole of `lib/features/tides/data/services/tide_data_service.dart` with:

```dart
import 'package:submersion/core/tide/tide_calculator.dart';
import 'package:submersion/features/tides/data/services/fes_grid/fes_grid_reader.dart';

/// A model-tier calculator and the grid spacing behind it.
class FesModelData {
  final TideCalculator calculator;
  final double resolutionKm;

  const FesModelData({required this.calculator, required this.resolutionKm});
}

/// Offline FES2022 tide model: harmonic constituents interpolated from the
/// bundled grid (see `FesGridReader`). Heights are relative to mean sea
/// level.
class TideDataService {
  final FesGridReader _reader;

  TideDataService({FesGridReader? reader})
    : _reader = reader ?? FesGridReader.bundled();

  /// Calculator and grid resolution at a location, or null without data.
  Future<FesModelData?> getModelForLocation(
    double latitude,
    double longitude,
  ) async {
    final sample = await _reader.sampleAt(latitude, longitude);
    if (sample == null) return null;
    return FesModelData(
      calculator: TideCalculator(constituents: sample.constituents),
      resolutionKm: sample.resolutionKm,
    );
  }

  /// A [TideCalculator] for a location, or null without data.
  Future<TideCalculator?> getCalculatorForLocation(
    double latitude,
    double longitude,
  ) async => (await getModelForLocation(latitude, longitude))?.calculator;

  /// Whether the model has data for a location.
  Future<bool> hasTideData(double latitude, double longitude) async =>
      await getModelForLocation(latitude, longitude) != null;

  /// Metadata about the bundled grid, or null when it cannot be read.
  Future<TideDataMetadata?> getMetadata() async {
    final manifest = await _reader.manifest();
    if (manifest == null) return null;
    return TideDataMetadata(
      version: '1',
      model: manifest.model,
      datum: 'MSL',
      extractionDate: manifest.extractionDate,
    );
  }
}

/// Metadata about the tide data source.
class TideDataMetadata {
  final String version;
  final String model;
  final String datum;
  final String? extractionDate;

  const TideDataMetadata({
    required this.version,
    required this.model,
    required this.datum,
    this.extractionDate,
  });

  @override
  String toString() => 'TideDataMetadata($model $version, datum: $datum)';
}
```

- [ ] **Step 4: Carry the resolution through the resolver**

In `lib/features/tides/data/services/tide_constituent_resolver.dart`:

Add the field and update both constructors of `TideDataSource`:

```dart
  /// Grid spacing of the model tier in kilometres; null for stations.
  final double? resolutionKm;

  const TideDataSource.fesModel({this.resolutionKm})
    : kind = TideDataSourceKind.fesModel,
      stationId = null,
      stationName = null,
      distanceKm = null,
      mllwDatum = false;

  const TideDataSource.noaaStation({
    required this.stationId,
    required this.stationName,
    required this.distanceKm,
    required this.mllwDatum,
  }) : kind = TideDataSourceKind.noaaStation,
       resolutionKm = null;
```

In `resolve`, replace the FES block with:

```dart
    final model = await _fesService.getModelForLocation(latitude, longitude);
    if (model != null) {
      return ResolvedTideData(
        calculator: model.calculator,
        source: TideDataSource.fesModel(resolutionKm: model.resolutionKm),
      );
    }
    return null;
```

- [ ] **Step 5: Run the tide tests to verify they pass**

Run: `flutter test test/features/tides test/core/tide`
Expected: PASS.

- [ ] **Step 6: Remove the old grid, scripts and docs**

Run:
```bash
git rm assets/data/tide/constituents_grid.json assets/data/tide/metadata.json scripts/tide/extract_fes_constituents.py scripts/tide/generate_fes_config.py scripts/tide/export_dive_sites.dart scripts/tide/requirements.txt
grep -rn -E "constituents_grid|metadata\.json|extract_fes_constituents|generate_fes_config|export_dive_sites|pyfes|PyFES" lib test scripts docs README.md pubspec.yaml --include='*' | grep -v "docs/superpowers/"
```
Expected: the grep prints only lines in `scripts/tide/README.md` and `docs/README.md`, which the next step rewrites. Any other hit must be fixed in this task.

Replace `scripts/tide/README.md` with:

```markdown
# Tide data scripts

Submersion predicts tides offline from harmonic constituents. Two sources:
NOAA CO-OPS stations (fetched at runtime) and a bundled FES2022 ocean-model
grid, generated by the scripts here.

## FES2022 grid

`extract_fes_grid.py` reads the FES2022b `ocean_tide_extrapolated` NetCDF
files (free registration at AVISO) and writes `assets/data/tide/fes/`: a
manifest, a 1-degree global layer and 0.1-degree coastal tiles within about
30 km of any non-ocean cell. The binary format is documented in
`fes_grid_format.py`. It also writes the accuracy fixture used by
`test/features/tides/data/fes_grid/fes_grid_accuracy_test.dart`.

    python3.14 -m venv ~/.venvs/submersion-tide
    ~/.venvs/submersion-tide/bin/pip install numpy netCDF4
    ~/.venvs/submersion-tide/bin/python scripts/tide/extract_fes_grid.py \
        --fes-dir ~/repos/fes2022b/ocean_tide_extrapolated
    ~/.venvs/submersion-tide/bin/python scripts/tide/extract_fes_grid.py \
        --fes-dir ~/repos/fes2022b/ocean_tide_extrapolated --verify

It needs about 3 GB of RAM. `write_fes_grid_test_fixtures.py` regenerates
the small synthetic grid the decoding tests use.

## NOAA stations

`generate_noaa_station_index.py` refreshes the bundled station index.
`fetch_noaa_local_time_fixtures.py` refreshes the local-time golden fixtures.

## Time zones

`generate_tz_lookup_data.py` regenerates `lib/core/util/tz_lookup_data.dart`
from photostructure/tz-lookup (CC0-1.0) at a pinned commit, and
`generate_tz_lookup_fixture.js` (node) regenerates the parity fixture from
the same commit.
```

In `docs/README.md`, replace the fenced block and trailing sentence about PyFES extraction (the block that starts with the conda commands and ends with "The current sample data is placeholder/development data...") with:

```markdown
The bundled grid is generated from FES2022b by
`scripts/tide/extract_fes_grid.py`; see `scripts/tide/README.md`.
```

Read the surrounding lines of `docs/README.md` first and keep the enclosing `<details>` structure intact.

- [ ] **Step 7: Run the tide tests and the architecture guards**

Run: `flutter test test/features/tides test/core/tide test/architecture`
Expected: PASS.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format lib/features/tides test/features/tides
flutter analyze lib/features/tides test/features/tides
git add lib/features/tides/data/services/tide_data_service.dart lib/features/tides/data/services/tide_constituent_resolver.dart test/features/tides/data/tide_constituent_resolver_test.dart scripts/tide/README.md docs/README.md
git commit -m "Serve the model tier from the new grid and remove the 1-degree JSON"
```

---

### Task 10: Source sheet wording and localization

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`
- Modify (generated): `lib/l10n/arb/app_localizations*.dart`
- Modify: `lib/features/tides/presentation/widgets/tide_source_badge.dart` (`build` and `_showDetails`)
- Modify: `test/features/tides/presentation/widgets/tide_source_badge_test.dart`

**Interfaces:**
- Consumes: `TideDataSource.resolutionKm` (Task 9).
- Produces: l10n getters `tides_source_siteLocalTime` (String) and `tides_source_modelResolution(String distance)`.

- [ ] **Step 1: Write the failing widget tests**

In `test/features/tides/presentation/widgets/tide_source_badge_test.dart`, append inside `main()`:

```dart
  testWidgets('the sheet says times are in site time, on both tiers', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _host(
        const TideDataSource.noaaStation(
          stationId: '9414290',
          stationName: 'San Francisco',
          distanceKm: 5.2,
          mllwDatum: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('NOAA station'));
    await tester.pumpAndSettle();
    expect(
      find.text("Times are shown in the dive site's local time."),
      findsOneWidget,
    );
    expect(find.textContaining('ocean-model grid'), findsNothing);
  });

  testWidgets('the model tier sheet shows the grid resolution', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _host(const TideDataSource.fesModel(resolutionKm: 11.1)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocean-model estimate'));
    await tester.pumpAndSettle();
    expect(
      find.text("Times are shown in the dive site's local time."),
      findsOneWidget,
    );
    // Default settings are metric: formatGeoDistance renders kilometres.
    expect(find.textContaining('ocean-model grid'), findsOneWidget);
    expect(find.textContaining('km'), findsWidgets);
  });

  testWidgets('a model source without a resolution omits the grid line', (
    tester,
  ) async {
    await tester.pumpWidget(await _host(const TideDataSource.fesModel()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocean-model estimate'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ocean-model grid'), findsNothing);
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/tides/presentation/widgets/tide_source_badge_test.dart`
Expected: the three new tests FAIL (text not found); the existing three PASS.

- [ ] **Step 3: Add the ARB keys to all 11 locales**

Run this from the repo root:

```bash
python3.14 - <<'EOF'
import json
from pathlib import Path

NEW = {
    "en": ("Times are shown in the dive site's local time.", "{distance} ocean-model grid"),
    "ar": ("تُعرض الأوقات بالتوقيت المحلي لموقع الغوص.", "شبكة نموذج المحيط بدقة {distance}"),
    "de": ("Zeiten werden in der Ortszeit des Tauchplatzes angezeigt.", "Ozeanmodell-Raster mit {distance}"),
    "es": ("Las horas se muestran en la hora local del punto de buceo.", "Cuadrícula del modelo oceánico de {distance}"),
    "fr": ("Les heures sont affichées à l'heure locale du site de plongée.", "Grille du modèle océanique de {distance}"),
    "he": ("השעות מוצגות לפי השעה המקומית של אתר הצלילה.", "רשת מודל אוקיינוס של {distance}"),
    "hu": ("Az időpontok a merülőhely helyi idejében jelennek meg.", "{distance} felbontású óceánmodell-rács"),
    "it": ("Gli orari sono mostrati nell'ora locale del sito di immersione.", "Griglia del modello oceanico di {distance}"),
    "nl": ("Tijden worden weergegeven in de lokale tijd van de duikstek.", "Oceaanmodelraster van {distance}"),
    "pt": ("Os horários são mostrados na hora local do local de mergulho.", "Grade do modelo oceânico de {distance}"),
    "zh": ("时间以潜水点当地时间显示。", "{distance} 海洋模型网格"),
}

for locale, (site_time, resolution) in NEW.items():
    path = Path(f"lib/l10n/arb/app_{locale}.arb")
    lines = path.read_text(encoding="utf-8").split("\n")
    idx = next(i for i, line in enumerate(lines)
               if line.lstrip().startswith('"tides_source_datumMsl"'))
    was_last = not lines[idx].rstrip().endswith(",")
    if was_last:
        lines[idx] = lines[idx].rstrip() + ","
    new = [
        f'  "tides_source_siteLocalTime": {json.dumps(site_time, ensure_ascii=False)},',
        f'  "tides_source_modelResolution": {json.dumps(resolution, ensure_ascii=False)}',
    ]
    if locale == "en":
        new[-1] += ","
        new += [
            '  "@tides_source_modelResolution": {',
            '    "placeholders": {',
            '      "distance": {',
            '        "type": "String"',
            "      }",
            "    }",
            "  }",
        ]
    if not was_last:
        new[-1] += ","
    lines[idx + 1 : idx + 1] = new
    path.write_text("\n".join(lines), encoding="utf-8")
    json.loads(path.read_text(encoding="utf-8"))  # still valid JSON
    print(f"updated {path}")
EOF
flutter gen-l10n
```

Expected: eleven `updated` lines and no gen-l10n errors.

- [ ] **Step 4: Show the new lines in the sheet**

In `lib/features/tides/presentation/widgets/tide_source_badge.dart`, change the `onTap` to pass the formatter:

```dart
      onTap: () => _showDetails(context, source, units),
```

Change `_showDetails`'s signature to:

```dart
  void _showDetails(
    BuildContext context,
    TideDataSource source,
    UnitFormatter units,
  ) {
```

In its `Column`, replace the `if (isStation) ...[ ... ] else ...[ ... ],` block with:

```dart
                if (isStation) ...[
                  Text(source.stationName ?? source.stationId ?? ''),
                  const SizedBox(height: 8),
                  Text(
                    source.mllwDatum
                        ? context.l10n.tides_source_datumMllw
                        : context.l10n.tides_source_datumMsl,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else ...[
                  Text(context.l10n.tides_source_modelCaveat),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.tides_source_datumMsl,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (source.resolutionKm != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.tides_source_modelResolution(
                        units.formatGeoDistance(source.resolutionKm! * 1000),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
                const SizedBox(height: 4),
                Text(
                  context.l10n.tides_source_siteLocalTime,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
```

- [ ] **Step 5: Run the badge tests to verify they pass**

Run: `flutter test test/features/tides/presentation/widgets/tide_source_badge_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/features/tides lib/l10n test/features/tides
flutter analyze lib/features/tides lib/l10n test/features/tides
git add lib/l10n/arb lib/features/tides/presentation/widgets/tide_source_badge.dart test/features/tides/presentation/widgets/tide_source_badge_test.dart
git commit -m "Tell divers tide times are site-local and show the model grid resolution"
```

---

### Task 11: Whole-project verification

**Files:** none, unless a gate fails.

- [ ] **Step 1: Format and analyze the whole project**

Run:
```bash
dart format .
git status --short
flutter analyze
```
Expected: `dart format` changes nothing (`git status` shows no modified files), and `flutter analyze` reports `No issues found!`. Infos count as failures in CI.

- [ ] **Step 2: Architecture guards**

Run: `flutter test test/architecture`
Expected: PASS.

- [ ] **Step 3: One full suite run**

Check the test temp volume first, then run the suite once:
```bash
df -h /Volumes/fltmp
flutter test
```
Expected: all pass. If a failure is in a file this branch never touched, check whether `origin/main` has the same failure before changing anything.

- [ ] **Step 4: Scan the branch for forbidden characters and attribution**

Run:
```bash
git diff origin/main...HEAD | python3.14 -c "import sys; t = sys.stdin.read(); print('DASHES FOUND' if chr(0x2014) in t or chr(0x2013) in t else 'no dashes')"
git log origin/main..HEAD --format=%B | grep -i -E "claude|anthropic|co-authored" || echo "no attribution"
```
Expected: `no dashes` and `no attribution`.

- [ ] **Step 5: Hand off for the issue and PR**

Do not open an issue or PR without the maintainer's go-ahead. Report to the maintainer: the commit list, the asset size added, the accuracy-test p90 values for the three largest-error sites, and a draft issue body (both causes, with the measurement table from the spec). Once approved, open the issue, then the PR with `Closes #<issue>` in its body.
