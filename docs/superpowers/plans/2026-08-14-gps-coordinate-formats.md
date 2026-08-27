# GPS Coordinate Formats Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver choose how GPS coordinates are displayed and entered — decimal degrees, degrees decimal minutes, degrees minutes seconds, UTM, or MGRS — across every coordinate in the app.

**Architecture:** A new pure-Dart module `lib/core/utils/coordinates/` owns formatting, parsing, and the WGS84 transverse-Mercator projection. Storage never changes: coordinates remain two `double` columns in decimal degrees, and every new module converts to and from DD at its boundary. A `coordinateFormat` enum setting joins the existing diver-settings plumbing (schema v150), `UnitFormatter` gains `formatCoordinates`, and one adaptive `CoordinateInput` widget replaces the latitude/longitude field pairs in the two edit forms.

**Tech Stack:** Flutter, Drift ORM, Riverpod (`StateNotifierProvider`), `flutter_test`. No new package dependencies.

**Spec:** `docs/superpowers/specs/2026-08-14-gps-coordinate-formats-design.md`

## Global Constraints

- **No new dependencies.** The projection math is implemented directly; `pubspec.yaml` is not modified.
- **Storage is decimal degrees, always.** No table stores a formatted string, a zone, or a band.
- **DD is the default** (`CoordinateFormat.decimalDegrees`) in the enum, the `AppSettings` constructor, the Drift column default, and every parser fallback.
- **DD renders with degree symbol and hemisphere:** `20.361944° N, 87.029722° W`. This is a deliberate change from today's signed `20.361944, -87.029722`, approved during design.
- **Exports do not change.** CSV, Excel, UDDF, and GPX keep decimal degrees. Cache and dedup keys (reef, bathymetry, weather, dashboard) keep their current fixed precision. Log statements are untouched.
- **UTM/MGRS are valid for −80° ≤ lat ≤ 84° only.** Outside that band every entry point falls back to decimal degrees. UPS is not implemented.
- **Schema version:** this plan targets **v150**. `AppDatabase.currentSchemaVersion` was 149 at `lib/core/database/database.dart:2956` when this plan was written. Two prior steps (v145, v147) were renumbered because parallel branches raced for a version — **re-verify against `origin/main` before opening the PR.**
- **All 11 locales.** New ARB keys go into every file in `lib/l10n/arb/`: `app_ar`, `app_de`, `app_en`, `app_es`, `app_fr`, `app_he`, `app_hu`, `app_it`, `app_nl`, `app_pt`, `app_zh`.
- **No emojis** in code, comments, or docs. Run `dart format .` before every commit; `flutter analyze` must be clean.
- **Test vectors in this plan are authoritative.** They were generated from the NGA GEOTRANS library (via the `mgrs` Python package) and an independent transverse-Mercator implementation, then verified against a Dart prototype. Do not "correct" a vector to match an implementation — the vector is right.

## Reference Test Vectors

Every value below is independently generated. UTM eastings/northings are rounded to the metre; MGRS digits are truncated (see Task 4).

| Site | lat, lon | DD | DDM | DMS |
| --- | --- | --- | --- | --- |
| Cozumel Palancar | `20.361944, -87.029722` | `20.361944° N, 87.029722° W` | `20° 21.717' N, 87° 01.783' W` | `20° 21' 43.0" N, 87° 01' 47.0" W` |
| Blue Hole, Belize | `17.315833, -87.535` | `17.315833° N, 87.535000° W` | `17° 18.950' N, 87° 32.100' W` | `17° 18' 57.0" N, 87° 32' 06.0" W` |
| SS Yongala, AU | `-19.305278, 147.6225` | `19.305278° S, 147.622500° E` | `19° 18.317' S, 147° 37.350' E` | `19° 18' 19.0" S, 147° 37' 21.0" E` |
| Silfra, Iceland | `64.255833, -21.123889` | `64.255833° N, 21.123889° W` | `64° 15.350' N, 21° 07.433' W` | `64° 15' 21.0" N, 21° 07' 26.0" W` |
| Blue Corner, Palau | `7.14, 134.221667` | `7.140000° N, 134.221667° E` | `7° 08.400' N, 134° 13.300' E` | `7° 08' 24.0" N, 134° 13' 18.0" E` |
| Null Island | `0.0, 0.0` | `0.000000° N, 0.000000° E` | `0° 00.000' N, 0° 00.000' E` | `0° 00' 00.0" N, 0° 00' 00.0" E` |
| Norway zone exception | `60.0, 5.0` | `60.000000° N, 5.000000° E` | `60° 00.000' N, 5° 00.000' E` | `60° 00' 00.0" N, 5° 00' 00.0" E` |
| Svalbard zone exception | `78.0, 20.0` | `78.000000° N, 20.000000° E` | `78° 00.000' N, 20° 00.000' E` | `78° 00' 00.0" N, 20° 00' 00.0" E` |
| Otago, NZ | `-45.5, 170.5` | `45.500000° S, 170.500000° E` | `45° 30.000' S, 170° 30.000' E` | `45° 30' 00.0" S, 170° 30' 00.0" E` |

| Site | UTM | MGRS |
| --- | --- | --- |
| Cozumel Palancar | `16Q 496898E 2251535N` | `16Q DH 96898 51535` |
| Blue Hole, Belize | `16Q 443148E 1914574N` | `16Q DE 43148 14573` |
| SS Yongala, AU | `55K 565399E 7865276N` | `55K EU 65398 65276` |
| Silfra, Iceland | `27W 493996E 7125529N` | `27W VM 93995 25528` |
| Blue Corner, Palau | `53N 414056E 789298N` | `53N MH 14055 89297` |
| Null Island | `31N 166021E 0N` | `31N AA 66021 00000` |
| Norway zone exception | `32V 276980E 6658157N` | `32V KM 76979 58157` |
| Svalbard zone exception | `33X 615915E 8663320N` | `33X XG 15914 63320` |
| Otago, NZ | `59G 460937E 4961382N` | `59G MK 60936 61381` |

## File Structure

**Create:**

| File | Responsibility |
| --- | --- |
| `lib/core/utils/coordinates/coordinate_format.dart` | The `CoordinateFormat` enum |
| `lib/core/utils/coordinates/utm_converter.dart` | WGS84 transverse Mercator, zone/band, forward and inverse |
| `lib/core/utils/coordinates/mgrs_converter.dart` | 100 km square lettering over UTM |
| `lib/core/utils/coordinates/coordinate_formatter.dart` | `formatCoordinates(lat, lng, format)` for all five formats |
| `lib/core/utils/coordinates/coordinate_parser.dart` | Tolerant parse of any of the five formats |
| `lib/shared/widgets/forms/coordinate_input.dart` | Adaptive lat/lng entry widget |
| `lib/features/settings/presentation/widgets/coordinate_format_picker.dart` | Settings picker dialog and label helper |

**Modify:** `lib/core/database/database.dart`, `lib/features/settings/presentation/providers/settings_providers.dart`, `lib/features/settings/data/repositories/diver_settings_repository.dart`, `lib/features/settings/presentation/pages/settings_page.dart`, `lib/core/utils/unit_formatter.dart`, `lib/core/services/sync/sync_data_serializer.dart`, `lib/features/dive_sites/presentation/widgets/edit_sections/location_section.dart`, `lib/features/dive_sites/presentation/pages/site_edit_page.dart`, `lib/features/dive_centers/presentation/pages/dive_center_edit_page.dart`, the display sites listed in Task 8, and all 11 ARB files.

---

### Task 1: `CoordinateFormat` enum

**Files:**
- Create: `lib/core/utils/coordinates/coordinate_format.dart`
- Test: `test/core/utils/coordinates/coordinate_format_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `enum CoordinateFormat { decimalDegrees, degreesDecimalMinutes, degreesMinutesSeconds, utm, mgrs }` with `bool get isGridFormat` (true for `utm` and `mgrs`).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';

void main() {
  test('decimalDegrees is the first value so it is the natural default', () {
    expect(CoordinateFormat.values.first, CoordinateFormat.decimalDegrees);
  });

  test('names are stable, since they are persisted verbatim', () {
    expect(CoordinateFormat.values.map((f) => f.name).toList(), [
      'decimalDegrees',
      'degreesDecimalMinutes',
      'degreesMinutesSeconds',
      'utm',
      'mgrs',
    ]);
  });

  test('grid formats are the ones that cannot split into two axes', () {
    expect(CoordinateFormat.utm.isGridFormat, isTrue);
    expect(CoordinateFormat.mgrs.isGridFormat, isTrue);
    expect(CoordinateFormat.decimalDegrees.isGridFormat, isFalse);
    expect(CoordinateFormat.degreesMinutesSeconds.isGridFormat, isFalse);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/utils/coordinates/coordinate_format_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

```dart
/// How GPS coordinates are rendered and entered.
///
/// Presentational only. A coordinate is always stored as two decimal-degree
/// doubles, so changing this re-renders every site without altering a single
/// stored value -- the same contract [VisibilityScalePreset] has for measured
/// visibility.
///
/// Enum names are persisted verbatim in `diver_settings.coordinate_format`.
/// Renaming a value silently resets that diver to the default.
enum CoordinateFormat {
  /// 20.361944 degrees N, 87.029722 degrees W. The default, and what every
  /// map service and API speaks.
  decimalDegrees,

  /// 20 degrees 21.717 minutes N. What marine GPS units and chartplotters
  /// display, so this is the form most dive-boat coordinates arrive in.
  degreesDecimalMinutes,

  /// 20 degrees 21 minutes 43.0 seconds N. The cartographic convention.
  degreesMinutesSeconds,

  /// Universal Transverse Mercator: 16Q 496898E 2251535N.
  utm,

  /// Military Grid Reference System: 16Q DH 96898 51535.
  mgrs;

  /// Whether this format fuses both axes into a single grid reference.
  ///
  /// UTM shares a zone between the axes and MGRS encodes both in one token,
  /// so neither can be typed into independent latitude and longitude fields.
  /// The input widget uses this to choose its layout.
  bool get isGridFormat =>
      this == CoordinateFormat.utm || this == CoordinateFormat.mgrs;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/utils/coordinates/coordinate_format_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/utils/coordinates/coordinate_format.dart test/core/utils/coordinates/coordinate_format_test.dart
git commit -m "feat(coordinates): add CoordinateFormat enum"
```

---

### Task 2: UTM converter

**Files:**
- Create: `lib/core/utils/coordinates/utm_converter.dart`
- Test: `test/core/utils/coordinates/utm_converter_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class UtmCoordinate { final int zone; final String band; final double easting; final double northing; const UtmCoordinate({required this.zone, required this.band, required this.easting, required this.northing}); bool get isNorthern; }`
  - `UtmCoordinate? latLngToUtm(double latitude, double longitude)` — null outside −80..84.
  - `({double latitude, double longitude}) utmToLatLng(int zone, String band, double easting, double northing)`
  - `String? utmBandFor(double latitude)`, `int utmZoneFor(double latitude, double longitude)`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/coordinates/utm_converter.dart';

void main() {
  // Vectors generated from NGA GEOTRANS. Do not adjust to match code.
  const cases = <({String name, double lat, double lng, int zone, String band,
      int easting, int northing})>[
    (name: 'Cozumel Palancar', lat: 20.361944, lng: -87.029722, zone: 16, band: 'Q', easting: 496898, northing: 2251535),
    (name: 'Blue Hole Belize', lat: 17.315833, lng: -87.535, zone: 16, band: 'Q', easting: 443148, northing: 1914574),
    (name: 'SS Yongala', lat: -19.305278, lng: 147.6225, zone: 55, band: 'K', easting: 565399, northing: 7865276),
    (name: 'Silfra', lat: 64.255833, lng: -21.123889, zone: 27, band: 'W', easting: 493996, northing: 7125529),
    (name: 'Blue Corner Palau', lat: 7.14, lng: 134.221667, zone: 53, band: 'N', easting: 414056, northing: 789298),
    (name: 'Null Island', lat: 0.0, lng: 0.0, zone: 31, band: 'N', easting: 166021, northing: 0),
    (name: 'Norway exception', lat: 60.0, lng: 5.0, zone: 32, band: 'V', easting: 276980, northing: 6658157),
    (name: 'Svalbard exception', lat: 78.0, lng: 20.0, zone: 33, band: 'X', easting: 615915, northing: 8663320),
    (name: 'Otago NZ', lat: -45.5, lng: 170.5, zone: 59, band: 'G', easting: 460937, northing: 4961382),
  ];

  group('latLngToUtm', () {
    for (final c in cases) {
      test('${c.name} projects to the reference easting and northing', () {
        final utm = latLngToUtm(c.lat, c.lng)!;
        expect(utm.zone, c.zone);
        expect(utm.band, c.band);
        expect(utm.easting.round(), c.easting);
        expect(utm.northing.round(), c.northing);
      });
    }

    test('southern latitudes carry the 10 000 km false northing', () {
      expect(latLngToUtm(-19.305278, 147.6225)!.northing, greaterThan(7000000));
    });

    test('returns null above the UTM band, where UPS takes over', () {
      expect(latLngToUtm(85.0, 10.0), isNull);
      expect(latLngToUtm(-81.0, 10.0), isNull);
    });
  });

  group('utmToLatLng', () {
    for (final c in cases) {
      test('${c.name} round-trips to within a centimetre', () {
        final utm = latLngToUtm(c.lat, c.lng)!;
        final back = utmToLatLng(utm.zone, utm.band, utm.easting, utm.northing);
        // 1e-7 degrees is roughly 1 cm of latitude.
        expect(back.latitude, closeTo(c.lat, 1e-7));
        expect(back.longitude, closeTo(c.lng, 1e-7));
      });
    }
  });

  group('zone exceptions', () {
    test('southern Norway widens zone 32 westward', () {
      expect(utmZoneFor(60.0, 5.0), 32);
      // Just outside the exception box the ordinary rule applies.
      expect(utmZoneFor(55.0, 5.0), 31);
    });

    test('Svalbard reassigns four zones, not one', () {
      expect(utmZoneFor(78.0, 5.0), 31);
      expect(utmZoneFor(78.0, 20.0), 33);
      expect(utmZoneFor(78.0, 25.0), 35);
      expect(utmZoneFor(78.0, 35.0), 37);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/utils/coordinates/utm_converter_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

This code was validated against every vector above before being written into this plan. Transcribe it exactly; the series coefficients are unforgiving.

```dart
import 'dart:math' as math;

/// WGS84 ellipsoid and UTM projection constants.
const double _a = 6378137.0; // semi-major axis, metres
const double _f = 1 / 298.257223563; // flattening
final double _e2 = _f * (2 - _f); // first eccentricity squared
final double _ep2 = _e2 / (1 - _e2); // second eccentricity squared
const double _k0 = 0.9996; // scale factor on the central meridian

/// Meridional arc series coefficients.
final double _m1 = 1 - _e2 / 4 - 3 * _e2 * _e2 / 64 - 5 * _e2 * _e2 * _e2 / 256;
final double _m2 =
    3 * _e2 / 8 + 3 * _e2 * _e2 / 32 + 45 * _e2 * _e2 * _e2 / 1024;
final double _m3 = 15 * _e2 * _e2 / 256 + 45 * _e2 * _e2 * _e2 / 1024;
final double _m4 = 35 * _e2 * _e2 * _e2 / 3072;

/// Footpoint-latitude series coefficients, used by the inverse projection.
final double _sqrtE = math.sqrt(1 - _e2);
final double _ee = (1 - _sqrtE) / (1 + _sqrtE);
final double _p2 = 3 / 2 * _ee - 27 / 32 * math.pow(_ee, 3);
final double _p3 = 21 / 16 * math.pow(_ee, 2) - 55 / 32 * math.pow(_ee, 4);
final double _p4 = 151 / 96 * math.pow(_ee, 3);
final double _p5 = 1097 / 512 * math.pow(_ee, 4);

/// Latitude band letters from 80S to 84N in 8-degree steps. I and O are
/// omitted because they are too easily confused with 1 and 0, and X spans
/// 12 degrees rather than 8 so the grid reaches 84N.
const String _bandLetters = 'CDEFGHJKLMNPQRSTUVWXX';

/// The northernmost and southernmost latitudes UTM is defined for. Beyond
/// these the standard switches to the Universal Polar Stereographic
/// projection, which this app does not implement.
const double utmMaxLatitude = 84.0;
const double utmMinLatitude = -80.0;

/// A point projected into a UTM zone.
class UtmCoordinate {
  final int zone;
  final String band;
  final double easting;
  final double northing;

  const UtmCoordinate({
    required this.zone,
    required this.band,
    required this.easting,
    required this.northing,
  });

  /// Bands N and later are north of the equator. The letter, not the sign of
  /// the northing, decides: southern northings carry a false offset that
  /// makes them positive too.
  bool get isNorthern => band.codeUnitAt(0) >= 'N'.codeUnitAt(0);
}

/// The latitude band letter, or null outside the UTM band.
String? utmBandFor(double latitude) {
  if (latitude < utmMinLatitude || latitude > utmMaxLatitude) return null;
  return _bandLetters[((latitude + 80) ~/ 8).clamp(0, 20)];
}

/// The UTM zone number, including the two regional exceptions.
int utmZoneFor(double latitude, double longitude) {
  // Southern Norway: zone 32 is widened westward so Bergen and Stavanger
  // share a zone with the rest of the coast.
  if (latitude >= 56 && latitude < 64 && longitude >= 3 && longitude < 12) {
    return 32;
  }
  // Svalbard: zones 32, 34, and 36 are absorbed by their neighbours, so four
  // zones are reassigned rather than one widened.
  if (latitude >= 72 && latitude < 84) {
    if (longitude >= 0 && longitude < 9) return 31;
    if (longitude >= 9 && longitude < 21) return 33;
    if (longitude >= 21 && longitude < 33) return 35;
    if (longitude >= 33 && longitude < 42) return 37;
  }
  return ((longitude + 180) ~/ 6) + 1;
}

/// Projects a WGS84 latitude/longitude into UTM.
///
/// Returns null outside the UTM latitude band rather than extrapolating the
/// series, which diverges badly near the poles.
UtmCoordinate? latLngToUtm(double latitude, double longitude) {
  final band = utmBandFor(latitude);
  if (band == null) return null;
  final zone = utmZoneFor(latitude, longitude);
  final centralLongitude = zone * 6 - 183;

  final latRad = latitude * math.pi / 180;
  final latSin = math.sin(latRad);
  final latCos = math.cos(latRad);
  final latTan = latSin / latCos;
  final latTan2 = latTan * latTan;
  final latTan4 = latTan2 * latTan2;

  final n = _a / math.sqrt(1 - _e2 * latSin * latSin);
  final c = _ep2 * latCos * latCos;
  final deltaLon = (longitude - centralLongitude) * math.pi / 180;
  final t = latCos * deltaLon;
  final t2 = t * t;
  final t3 = t2 * t;
  final t4 = t3 * t;
  final t5 = t4 * t;
  final t6 = t5 * t;

  final m = _a *
      (_m1 * latRad -
          _m2 * math.sin(2 * latRad) +
          _m3 * math.sin(4 * latRad) -
          _m4 * math.sin(6 * latRad));

  final easting = _k0 *
          n *
          (t +
              t3 / 6 * (1 - latTan2 + c) +
              t5 / 120 * (5 - 18 * latTan2 + latTan4 + 72 * c - 58 * _ep2)) +
      500000.0;

  var northing = _k0 *
      (m +
          n *
              latTan *
              (t2 / 2 +
                  t4 / 24 * (5 - latTan2 + 9 * c + 4 * c * c) +
                  t6 /
                      720 *
                      (61 -
                          58 * latTan2 +
                          latTan4 +
                          600 * c -
                          330 * _ep2)));
  // The southern hemisphere carries a false northing so values stay positive.
  if (latitude < 0) northing += 10000000.0;

  return UtmCoordinate(
    zone: zone,
    band: band,
    easting: easting,
    northing: northing,
  );
}

/// Inverse projection back to WGS84 degrees.
({double latitude, double longitude}) utmToLatLng(
  int zone,
  String band,
  double easting,
  double northing,
) {
  final northern = band.codeUnitAt(0) >= 'N'.codeUnitAt(0);
  final x = easting - 500000.0;
  final y = northern ? northing : northing - 10000000.0;

  final m = y / _k0;
  final mu = m / (_a * _m1);
  final footprint = mu +
      _p2 * math.sin(2 * mu) +
      _p3 * math.sin(4 * mu) +
      _p4 * math.sin(6 * mu) +
      _p5 * math.sin(8 * mu);

  final pSin = math.sin(footprint);
  final pCos = math.cos(footprint);
  final pTan = pSin / pCos;
  final pTan2 = pTan * pTan;
  final pTan4 = pTan2 * pTan2;

  final epSin = 1 - _e2 * pSin * pSin;
  final n = _a / math.sqrt(epSin);
  final r = (1 - _e2) / epSin;
  final c = _ep2 * pCos * pCos;
  final c2 = c * c;

  final d = x / (n * _k0);
  final d2 = d * d;
  final d3 = d2 * d;
  final d4 = d3 * d;
  final d5 = d4 * d;
  final d6 = d5 * d;

  final latitude = footprint -
      (pTan / r) *
          (d2 / 2 -
              d4 / 24 * (5 + 3 * pTan2 + 10 * c - 4 * c2 - 9 * _ep2) +
              d6 /
                  720 *
                  (61 +
                      90 * pTan2 +
                      298 * c +
                      45 * pTan4 -
                      252 * _ep2 -
                      3 * c2));
  final longitude = (d -
          d3 / 6 * (1 + 2 * pTan2 + c) +
          d5 /
              120 *
              (5 - 2 * c + 28 * pTan2 - 3 * c2 + 8 * _ep2 + 24 * pTan4)) /
      pCos;

  return (
    latitude: latitude * 180 / math.pi,
    longitude: longitude * 180 / math.pi + (zone * 6 - 183),
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/utils/coordinates/utm_converter_test.dart`
Expected: PASS, 22 tests.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/utils/coordinates/utm_converter.dart test/core/utils/coordinates/utm_converter_test.dart
git commit -m "feat(coordinates): add WGS84 UTM converter"
```

---

### Task 3: MGRS converter

**Files:**
- Create: `lib/core/utils/coordinates/mgrs_converter.dart`
- Test: `test/core/utils/coordinates/mgrs_converter_test.dart`

**Interfaces:**
- Consumes: `latLngToUtm`, `utmToLatLng`, `UtmCoordinate` from Task 2.
- Produces:
  - `String? latLngToMgrs(double latitude, double longitude)` — grouped form `16Q DH 96898 51535`, null outside the UTM band.
  - `({double latitude, double longitude})? mgrsToLatLng(String reference)` — accepts grouped or run-together input.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/coordinates/mgrs_converter.dart';

void main() {
  // Vectors from NGA GEOTRANS. Do not adjust to match code.
  const cases = <({String name, double lat, double lng, String mgrs})>[
    (name: 'Cozumel Palancar', lat: 20.361944, lng: -87.029722, mgrs: '16Q DH 96898 51535'),
    (name: 'Blue Hole Belize', lat: 17.315833, lng: -87.535, mgrs: '16Q DE 43148 14573'),
    (name: 'SS Yongala', lat: -19.305278, lng: 147.6225, mgrs: '55K EU 65398 65276'),
    (name: 'Silfra', lat: 64.255833, lng: -21.123889, mgrs: '27W VM 93995 25528'),
    (name: 'Blue Corner Palau', lat: 7.14, lng: 134.221667, mgrs: '53N MH 14055 89297'),
    (name: 'Null Island', lat: 0.0, lng: 0.0, mgrs: '31N AA 66021 00000'),
    (name: 'Norway exception', lat: 60.0, lng: 5.0, mgrs: '32V KM 76979 58157'),
    (name: 'Svalbard exception', lat: 78.0, lng: 20.0, mgrs: '33X XG 15914 63320'),
    (name: 'Otago NZ', lat: -45.5, lng: 170.5, mgrs: '59G MK 60936 61381'),
  ];

  group('latLngToMgrs', () {
    for (final c in cases) {
      test('${c.name} matches the reference grid reference', () {
        expect(latLngToMgrs(c.lat, c.lng), c.mgrs);
      });
    }

    test('truncates rather than rounds, because a reference names a square', () {
      // Blue Hole's true UTM northing is 1914573.6. Rounding would give
      // ...14574; the south-west corner convention requires ...14573.
      expect(latLngToMgrs(17.315833, -87.535), endsWith('14573'));
    });

    test('returns null outside the UTM band', () {
      expect(latLngToMgrs(85.0, 10.0), isNull);
    });
  });

  group('mgrsToLatLng', () {
    for (final c in cases) {
      test('${c.name} round-trips to within two metres', () {
        final back = mgrsToLatLng(c.mgrs)!;
        // Truncation to the square's south-west corner costs up to 1 m per
        // axis, so 2e-5 degrees (about 2 m) is the honest bound.
        expect(back.latitude, closeTo(c.lat, 2e-5));
        expect(back.longitude, closeTo(c.lng, 2e-5));
      });
    }

    test('accepts a run-together reference, as printed on maps', () {
      final back = mgrsToLatLng('16QDH9689851535')!;
      expect(back.latitude, closeTo(20.361944, 2e-5));
      expect(back.longitude, closeTo(-87.029722, 2e-5));
    });

    test('accepts lowercase', () {
      expect(mgrsToLatLng('16qdh9689851535'), isNotNull);
    });

    test('rejects malformed references', () {
      expect(mgrsToLatLng('not a grid reference'), isNull);
      expect(mgrsToLatLng('16Q DH 96898'), isNull); // odd digit count
      expect(mgrsToLatLng('16I DH 96898 51535'), isNull); // I is not a band
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/utils/coordinates/mgrs_converter_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:submersion/core/utils/coordinates/utm_converter.dart';

/// Column letters for the 100 km squares, cycling every three zones. I and O
/// are omitted throughout MGRS to avoid confusion with 1 and 0.
const String _columnLetters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';

/// Row letters, cycling every 2000 km of northing.
const String _rowLetters = 'ABCDEFGHJKLMNPQRSTUV';

/// Valid latitude band letters.
const String _bandLetters = 'CDEFGHJKLMNPQRSTUVWX';

/// Formats a coordinate as an MGRS grid reference at 1 m precision.
///
/// Returns the grouped form (`16Q DH 96898 51535`), which is how a reference
/// is read aloud. Null outside the UTM latitude band.
String? latLngToMgrs(double latitude, double longitude) {
  final utm = latLngToUtm(latitude, longitude);
  if (utm == null) return null;

  final columnIndex = ((utm.zone - 1) % 3) * 8 + (utm.easting ~/ 100000) - 1;
  final column = _columnLetters[columnIndex];

  var rowIndex = (utm.northing ~/ 100000) % 20;
  // Even-numbered zones start their row lettering half an alphabet along, so
  // adjacent zones never present the same letter pair at the same latitude.
  if (utm.zone.isEven) rowIndex = (rowIndex + 5) % 20;
  final row = _rowLetters[rowIndex];

  // A grid reference names a square and is identified by its south-west
  // corner, so the residual metres truncate. Rounding would name the wrong
  // square for any coordinate in the upper half of one.
  final eastingDigits =
      (utm.easting % 100000).floor().toString().padLeft(5, '0');
  final northingDigits =
      (utm.northing % 100000).floor().toString().padLeft(5, '0');

  return '${utm.zone}${utm.band} $column$row '
      '$eastingDigits $northingDigits';
}

final RegExp _mgrsPattern = RegExp(
  r'^(\d{1,2})([C-HJ-NP-X])\s*([A-HJ-NP-Z])([A-HJ-NP-V])\s*(\d+)$',
  caseSensitive: false,
);

/// Parses an MGRS grid reference back to WGS84 degrees.
///
/// Accepts grouped or run-together input in any case. Returns the square's
/// south-west corner rather than its centre, matching the reference's own
/// definition, so a format-then-parse round trip lands within one square of
/// the original.
({double latitude, double longitude})? mgrsToLatLng(String reference) {
  final cleaned = reference.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  final match = _mgrsPattern.firstMatch(cleaned);
  if (match == null) return null;

  final zone = int.parse(match.group(1)!);
  if (zone < 1 || zone > 60) return null;
  final band = match.group(2)!;
  if (!_bandLetters.contains(band)) return null;
  final column = match.group(3)!;
  final row = match.group(4)!;
  final digits = match.group(5)!;
  // A reference carries the same number of easting and northing digits.
  if (digits.isEmpty || digits.length.isOdd || digits.length > 10) return null;

  final half = digits.length ~/ 2;
  final precision = 100000 ~/ _pow10(half);
  final eastingRemainder = int.parse(digits.substring(0, half)) * precision;
  final northingRemainder = int.parse(digits.substring(half)) * precision;

  final columnIndex = _columnLetters.indexOf(column);
  if (columnIndex < 0) return null;
  var rowIndex = _rowLetters.indexOf(row);
  if (rowIndex < 0) return null;
  if (zone.isEven) rowIndex = (rowIndex - 5) % 20;
  if (rowIndex < 0) rowIndex += 20;

  final easting =
      ((columnIndex - ((zone - 1) % 3) * 8 + 1) * 100000).toDouble() +
          eastingRemainder;

  // The row letters repeat every 2000 km, so the band's own latitude range
  // decides which repetition is meant.
  final bandMinNorthing = _minimumNorthingForBand(band);
  var northing = rowIndex * 100000.0 + northingRemainder;
  while (northing < bandMinNorthing) {
    northing += 2000000.0;
  }

  return utmToLatLng(zone, band, easting, northing);
}

int _pow10(int exponent) {
  var value = 1;
  for (var i = 0; i < exponent; i++) {
    value *= 10;
  }
  return value;
}

/// The smallest northing that can occur in a latitude band, used to resolve
/// which 2000 km repetition of the row letters a reference means.
double _minimumNorthingForBand(String band) {
  final index = _bandLetters.indexOf(band);
  // Bands are 8 degrees tall starting at 80S; X is 12 degrees but its lower
  // edge follows the same rule.
  final southEdge = -80.0 + index * 8.0;
  final utm = latLngToUtm(southEdge, 0);
  if (utm == null) return 0;
  // Round down to a whole 100 km square so the comparison is conservative.
  return (utm.northing / 100000).floor() * 100000.0;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/utils/coordinates/mgrs_converter_test.dart`
Expected: PASS, 24 tests.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/utils/coordinates/mgrs_converter.dart test/core/utils/coordinates/mgrs_converter_test.dart
git commit -m "feat(coordinates): add MGRS converter"
```

---

### Task 4: Coordinate formatter

**Files:**
- Create: `lib/core/utils/coordinates/coordinate_formatter.dart`
- Test: `test/core/utils/coordinates/coordinate_formatter_test.dart`

**Interfaces:**
- Consumes: `CoordinateFormat` (Task 1), `latLngToUtm` (Task 2), `latLngToMgrs` (Task 3).
- Produces: `String formatCoordinates(double latitude, double longitude, CoordinateFormat format)`, `String formatLatitude(double latitude, CoordinateFormat format)`, `String formatLongitude(double longitude, CoordinateFormat format)`.

Single-axis variants fall back to DD-family rendering when asked for a grid format, because one axis of a grid reference is meaningless on its own.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/core/utils/coordinates/coordinate_formatter.dart';

void main() {
  // Pin the locale so decimal separators do not vary by host, following the
  // convention in the other unit-formatter tests.
  setUp(() => Intl.defaultLocale = 'en_US');

  const cases = <({String name, double lat, double lng, String dd, String ddm,
      String dms, String utm, String mgrs})>[
    (
      name: 'Cozumel Palancar',
      lat: 20.361944,
      lng: -87.029722,
      dd: '20.361944° N, 87.029722° W',
      ddm: "20° 21.717' N, 87° 01.783' W",
      dms: '20° 21\' 43.0" N, 87° 01\' 47.0" W',
      utm: '16Q 496898E 2251535N',
      mgrs: '16Q DH 96898 51535',
    ),
    (
      name: 'SS Yongala',
      lat: -19.305278,
      lng: 147.6225,
      dd: '19.305278° S, 147.622500° E',
      ddm: "19° 18.317' S, 147° 37.350' E",
      dms: '19° 18\' 19.0" S, 147° 37\' 21.0" E',
      utm: '55K 565399E 7865276N',
      mgrs: '55K EU 65398 65276',
    ),
    (
      name: 'Null Island',
      lat: 0.0,
      lng: 0.0,
      dd: '0.000000° N, 0.000000° E',
      ddm: "0° 00.000' N, 0° 00.000' E",
      dms: '0° 00\' 00.0" N, 0° 00\' 00.0" E',
      utm: '31N 166021E 0N',
      mgrs: '31N AA 66021 00000',
    ),
  ];

  for (final c in cases) {
    group(c.name, () {
      test('decimal degrees', () {
        expect(
          formatCoordinates(c.lat, c.lng, CoordinateFormat.decimalDegrees),
          c.dd,
        );
      });
      test('degrees decimal minutes', () {
        expect(
          formatCoordinates(
            c.lat,
            c.lng,
            CoordinateFormat.degreesDecimalMinutes,
          ),
          c.ddm,
        );
      });
      test('degrees minutes seconds', () {
        expect(
          formatCoordinates(
            c.lat,
            c.lng,
            CoordinateFormat.degreesMinutesSeconds,
          ),
          c.dms,
        );
      });
      test('utm', () {
        expect(formatCoordinates(c.lat, c.lng, CoordinateFormat.utm), c.utm);
      });
      test('mgrs', () {
        expect(formatCoordinates(c.lat, c.lng, CoordinateFormat.mgrs), c.mgrs);
      });
    });
  }

  test('a polar coordinate falls back to decimal degrees', () {
    // UTM is undefined above 84 N, so the grid formats degrade rather than
    // showing a wrong or empty reference.
    expect(
      formatCoordinates(85.5, 10.0, CoordinateFormat.mgrs),
      formatCoordinates(85.5, 10.0, CoordinateFormat.decimalDegrees),
    );
    expect(
      formatCoordinates(85.5, 10.0, CoordinateFormat.utm),
      formatCoordinates(85.5, 10.0, CoordinateFormat.decimalDegrees),
    );
  });

  test('seconds carry into minutes rather than showing 60', () {
    // 1.0 - 1e-9 degrees is a hair under one degree.
    final text = formatLatitude(
      0.9999999999,
      CoordinateFormat.degreesMinutesSeconds,
    );
    expect(text, isNot(contains('60.0"')));
    expect(text, '1° 00\' 00.0" N');
  });

  test('minutes carry into degrees rather than showing 60', () {
    final text = formatLatitude(
      0.9999999999,
      CoordinateFormat.degreesDecimalMinutes,
    );
    expect(text, isNot(contains('60.000')));
    expect(text, "1° 00.000' N");
  });

  group('single-axis formatting', () {
    test('renders one axis for the degree family', () {
      expect(
        formatLatitude(20.361944, CoordinateFormat.decimalDegrees),
        '20.361944° N',
      );
      expect(
        formatLongitude(-87.029722, CoordinateFormat.degreesDecimalMinutes),
        "87° 01.783' W",
      );
    });

    test('degrades grid formats to decimal degrees, since one axis of a '
        'grid reference means nothing', () {
      expect(
        formatLatitude(20.361944, CoordinateFormat.mgrs),
        '20.361944° N',
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/utils/coordinates/coordinate_formatter_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/core/utils/coordinates/mgrs_converter.dart';
import 'package:submersion/core/utils/coordinates/utm_converter.dart';

/// Renders a coordinate pair in the diver's chosen notation.
///
/// Grid formats degrade to decimal degrees outside the UTM latitude band
/// rather than returning an error string, so a polar site still shows a
/// usable position.
String formatCoordinates(
  double latitude,
  double longitude,
  CoordinateFormat format,
) {
  switch (format) {
    case CoordinateFormat.decimalDegrees:
    case CoordinateFormat.degreesDecimalMinutes:
    case CoordinateFormat.degreesMinutesSeconds:
      return '${formatLatitude(latitude, format)}, '
          '${formatLongitude(longitude, format)}';
    case CoordinateFormat.utm:
      final utm = latLngToUtm(latitude, longitude);
      if (utm == null) {
        return formatCoordinates(
          latitude,
          longitude,
          CoordinateFormat.decimalDegrees,
        );
      }
      return '${utm.zone}${utm.band} ${utm.easting.round()}E '
          '${utm.northing.round()}N';
    case CoordinateFormat.mgrs:
      final mgrs = latLngToMgrs(latitude, longitude);
      return mgrs ??
          formatCoordinates(
            latitude,
            longitude,
            CoordinateFormat.decimalDegrees,
          );
  }
}

/// Renders a single latitude. Grid formats degrade to decimal degrees.
String formatLatitude(double latitude, CoordinateFormat format) =>
    _formatAxis(latitude, format, isLatitude: true);

/// Renders a single longitude. Grid formats degrade to decimal degrees.
String formatLongitude(double longitude, CoordinateFormat format) =>
    _formatAxis(longitude, format, isLatitude: false);

String _formatAxis(
  double value,
  CoordinateFormat format, {
  required bool isLatitude,
}) {
  final hemisphere = isLatitude
      ? (value >= 0 ? 'N' : 'S')
      : (value >= 0 ? 'E' : 'W');
  final magnitude = value.abs();

  switch (format) {
    case CoordinateFormat.degreesDecimalMinutes:
      var degrees = magnitude.floor();
      var minutes = (magnitude - degrees) * 60;
      // Rounding for display can reach exactly 60; carry instead of printing
      // a minute value that does not exist.
      if (double.parse(minutes.toStringAsFixed(3)) >= 60) {
        minutes = 0;
        degrees += 1;
      }
      return '$degrees° ${minutes.toStringAsFixed(3).padLeft(6, '0')}\' '
          '$hemisphere';

    case CoordinateFormat.degreesMinutesSeconds:
      var degrees = magnitude.floor();
      final minutesFull = (magnitude - degrees) * 60;
      var minutes = minutesFull.floor();
      var seconds = (minutesFull - minutes) * 60;
      if (double.parse(seconds.toStringAsFixed(1)) >= 60) {
        seconds = 0;
        minutes += 1;
      }
      if (minutes >= 60) {
        minutes = 0;
        degrees += 1;
      }
      return '$degrees° ${minutes.toString().padLeft(2, '0')}\' '
          '${seconds.toStringAsFixed(1).padLeft(4, '0')}" $hemisphere';

    case CoordinateFormat.decimalDegrees:
    case CoordinateFormat.utm:
    case CoordinateFormat.mgrs:
      return '${magnitude.toStringAsFixed(6)}° $hemisphere';
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/utils/coordinates/coordinate_formatter_test.dart`
Expected: PASS, 21 tests.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/utils/coordinates/coordinate_formatter.dart test/core/utils/coordinates/coordinate_formatter_test.dart
git commit -m "feat(coordinates): add coordinate formatter for all five formats"
```

---

### Task 5: Coordinate parser

**Files:**
- Create: `lib/core/utils/coordinates/coordinate_parser.dart`
- Test: `test/core/utils/coordinates/coordinate_parser_test.dart`

**Interfaces:**
- Consumes: `mgrsToLatLng` (Task 3), `utmToLatLng` (Task 2).
- Produces: `({double latitude, double longitude})? parseCoordinates(String input)` and `double? parseSingleAxis(String input, {required bool isLatitude})`.

The parser is deliberately independent of the active display setting: pasted text arrives in whatever notation its author used.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/coordinates/coordinate_parser.dart';

void main() {
  void expectNear(
    ({double latitude, double longitude})? actual,
    double lat,
    double lng, {
    double tolerance = 1e-6,
  }) {
    expect(actual, isNotNull);
    expect(actual!.latitude, closeTo(lat, tolerance));
    expect(actual.longitude, closeTo(lng, tolerance));
  }

  group('decimal degrees', () {
    test('signed pair, the form the app stored before this feature', () {
      expectNear(parseCoordinates('20.361944, -87.029722'), 20.361944, -87.029722);
    });

    test('space separated', () {
      expectNear(parseCoordinates('20.361944 -87.029722'), 20.361944, -87.029722);
    });

    test('with degree symbols and hemispheres', () {
      expectNear(
        parseCoordinates('20.361944° N, 87.029722° W'),
        20.361944,
        -87.029722,
      );
    });

    test('hemisphere as a prefix', () {
      expectNear(parseCoordinates('N20.361944 W87.029722'), 20.361944, -87.029722);
    });
  });

  group('degrees decimal minutes', () {
    test('standard chartplotter form', () {
      expectNear(
        parseCoordinates("20° 21.717' N, 87° 01.783' W"),
        20.36195,
        -87.0297166,
        tolerance: 1e-5,
      );
    });

    test('unicode prime instead of apostrophe', () {
      expectNear(
        parseCoordinates('20° 21.717′ N, 87° 01.783′ W'),
        20.36195,
        -87.0297166,
        tolerance: 1e-5,
      );
    });
  });

  group('degrees minutes seconds', () {
    test('standard form', () {
      expectNear(
        parseCoordinates('20° 21\' 43.0" N, 87° 01\' 47.0" W'),
        20.361944,
        -87.029722,
        tolerance: 1e-4,
      );
    });

    test('unicode double prime', () {
      expectNear(
        parseCoordinates(
          '20° 21′ 43.0″ N, 87° 01′ 47.0″ W',
        ),
        20.361944,
        -87.029722,
        tolerance: 1e-4,
      );
    });

    test('southern and eastern hemispheres', () {
      expectNear(
        parseCoordinates('19° 18\' 19.0" S, 147° 37\' 21.0" E'),
        -19.305278,
        147.6225,
        tolerance: 1e-4,
      );
    });
  });

  group('grid references', () {
    test('mgrs grouped', () {
      expectNear(
        parseCoordinates('16Q DH 96898 51535'),
        20.361944,
        -87.029722,
        tolerance: 2e-5,
      );
    });

    test('mgrs run together', () {
      expectNear(
        parseCoordinates('16QDH9689851535'),
        20.361944,
        -87.029722,
        tolerance: 2e-5,
      );
    });

    test('utm with E/N suffixes', () {
      expectNear(
        parseCoordinates('16Q 496898E 2251535N'),
        20.361944,
        -87.029722,
        tolerance: 2e-5,
      );
    });

    test('utm without suffixes', () {
      expectNear(
        parseCoordinates('16Q 496898 2251535'),
        20.361944,
        -87.029722,
        tolerance: 2e-5,
      );
    });
  });

  group('rejection', () {
    test('rejects junk', () {
      expect(parseCoordinates('somewhere near the reef'), isNull);
      expect(parseCoordinates(''), isNull);
      expect(parseCoordinates('   '), isNull);
    });

    test('rejects out-of-range degrees rather than normalizing, since that '
        'almost always means a typo', () {
      expect(parseCoordinates('91.0, 10.0'), isNull);
      expect(parseCoordinates('10.0, 181.0'), isNull);
    });

    test('rejects impossible minutes and seconds', () {
      expect(parseCoordinates("20° 61.000' N, 87° 01.783' W"), isNull);
      expect(
        parseCoordinates('20° 21\' 61.0" N, 87° 01\' 47.0" W'),
        isNull,
      );
    });

    test('rejects a single number, which is not a coordinate pair', () {
      expect(parseCoordinates('20.361944'), isNull);
    });
  });

  group('parseSingleAxis', () {
    test('parses a bare decimal', () {
      expect(parseSingleAxis('20.361944', isLatitude: true), closeTo(20.361944, 1e-9));
    });

    test('parses a hemisphere-qualified value', () {
      expect(
        parseSingleAxis('87.029722° W', isLatitude: false),
        closeTo(-87.029722, 1e-9),
      );
    });

    test('enforces the axis range', () {
      expect(parseSingleAxis('91.0', isLatitude: true), isNull);
      expect(parseSingleAxis('91.0', isLatitude: false), closeTo(91.0, 1e-9));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/utils/coordinates/coordinate_parser_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:submersion/core/utils/coordinates/mgrs_converter.dart';
import 'package:submersion/core/utils/coordinates/utm_converter.dart';

/// An MGRS reference: zone, band, two square letters, then an even run of
/// digits. Checked before UTM because both begin with a zone and a band.
final RegExp _mgrsShape = RegExp(
  r'^\d{1,2}[C-HJ-NP-X]\s*[A-HJ-NP-Z][A-HJ-NP-V]\s*\d+$',
  caseSensitive: false,
);

/// A UTM reference: zone, band, easting, northing, with optional E/N marks.
final RegExp _utmShape = RegExp(
  r'^(\d{1,2})\s*([C-HJ-NP-X])\s+(\d+(?:\.\d+)?)\s*E?[\s,]+(\d+(?:\.\d+)?)\s*N?$',
  caseSensitive: false,
);

/// Any run of digits with an optional decimal part.
final RegExp _number = RegExp(r'\d+(?:\.\d+)?');

/// Parses a coordinate pair from free text in any supported notation.
///
/// Deliberately independent of the diver's display preference: text arrives
/// from dive guides, messages, and chartplotter screens in whatever notation
/// its author used, and rejecting a valid coordinate because it is not the
/// currently selected format would be hostile.
///
/// Returns null rather than throwing; partially typed input is a normal
/// state while editing, not an error.
({double latitude, double longitude})? parseCoordinates(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  if (_mgrsShape.hasMatch(trimmed.replaceAll(RegExp(r'\s+'), ''))) {
    return mgrsToLatLng(trimmed);
  }

  final utmMatch = _utmShape.firstMatch(trimmed);
  if (utmMatch != null) {
    final zone = int.parse(utmMatch.group(1)!);
    final band = utmMatch.group(2)!.toUpperCase();
    if (zone < 1 || zone > 60) return null;
    final result = utmToLatLng(
      zone,
      band,
      double.parse(utmMatch.group(3)!),
      double.parse(utmMatch.group(4)!),
    );
    if (!_inRange(result.latitude, result.longitude)) return null;
    return result;
  }

  return _parseDegreeFamily(trimmed);
}

/// Parses a single axis, used by the per-axis sub-fields of the input widget.
double? parseSingleAxis(String input, {required bool isLatitude}) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  final value = _parseAxisText(trimmed, isLatitude: isLatitude);
  if (value == null) return null;
  final limit = isLatitude ? 90.0 : 180.0;
  if (value.abs() > limit) return null;
  return value;
}

/// Splits free text into a latitude half and a longitude half, then parses
/// each as degrees, degrees-minutes, or degrees-minutes-seconds.
({double latitude, double longitude})? _parseDegreeFamily(String input) {
  final normalized = input
      .replaceAll('′', "'") // prime
      .replaceAll('″', '"') // double prime
      .replaceAll('´', "'")
      .replaceAll('’', "'");

  // Prefer an explicit comma split; otherwise split on the hemisphere letter
  // that ends the first half, and fall back to splitting the numbers evenly.
  final halves = _splitHalves(normalized);
  if (halves == null) return null;

  final latitude = _parseAxisText(halves.$1, isLatitude: true);
  final longitude = _parseAxisText(halves.$2, isLatitude: false);
  if (latitude == null || longitude == null) return null;
  if (!_inRange(latitude, longitude)) return null;
  return (latitude: latitude, longitude: longitude);
}

(String, String)? _splitHalves(String input) {
  final commaIndex = input.indexOf(',');
  if (commaIndex > 0) {
    final first = input.substring(0, commaIndex);
    final second = input.substring(commaIndex + 1);
    if (_number.hasMatch(first) && _number.hasMatch(second)) {
      return (first, second);
    }
  }

  // A trailing N or S ends the latitude half.
  final hemisphereSplit = RegExp(r'[NSns]\s*(?=[\d\-+EWew])').firstMatch(input);
  if (hemisphereSplit != null) {
    return (
      input.substring(0, hemisphereSplit.end),
      input.substring(hemisphereSplit.end),
    );
  }

  // Otherwise split evenly on whitespace between two numbers.
  final numbers = _number.allMatches(input).toList();
  if (numbers.length < 2 || numbers.length.isOdd) return null;
  final splitAt = numbers[numbers.length ~/ 2].start;
  return (input.substring(0, splitAt), input.substring(splitAt));
}

/// Parses one axis expressed as degrees, degrees and minutes, or degrees,
/// minutes and seconds, with the sign taken from a hemisphere letter or a
/// leading minus.
double? _parseAxisText(String text, {required bool isLatitude}) {
  final upper = text.toUpperCase();
  final negative = upper.contains(isLatitude ? 'S' : 'W') || upper.contains('-');
  if (isLatitude && (upper.contains('E') || upper.contains('W'))) return null;
  if (!isLatitude && (upper.contains('N') || upper.contains('S'))) return null;

  final parts = _number
      .allMatches(text)
      .map((m) => double.parse(m.group(0)!))
      .toList();
  if (parts.isEmpty || parts.length > 3) return null;

  final degrees = parts[0];
  final minutes = parts.length > 1 ? parts[1] : 0.0;
  final seconds = parts.length > 2 ? parts[2] : 0.0;
  // 60 minutes or 60 seconds is a misread, not a coordinate.
  if (minutes >= 60 || seconds >= 60) return null;
  if (parts.length > 1 && degrees != degrees.floorToDouble()) return null;

  final magnitude = degrees + minutes / 60 + seconds / 3600;
  return negative ? -magnitude : magnitude;
}

bool _inRange(double latitude, double longitude) =>
    latitude.abs() <= 90 && longitude.abs() <= 180;
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/utils/coordinates/coordinate_parser_test.dart`
Expected: PASS, 20 tests.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/core/utils/coordinates/coordinate_parser.dart test/core/utils/coordinates/coordinate_parser_test.dart
git commit -m "feat(coordinates): add tolerant multi-format coordinate parser"
```

---

### Task 6: Schema v150 — the `coordinate_format` column

**Files:**
- Modify: `lib/core/database/database.dart` (table at ~`:1500`, `currentSchemaVersion` at `:2956`, `migrationVersions` list ending ~`:3160`, DDL helper near `_assertVisibilityScaleColumns` at `:4432`, `onUpgrade` ladder ~`:7791`, `beforeOpen` backstop ~`:7911`)
- Test: `test/core/database/migration_v150_coordinate_format_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `diver_settings.coordinate_format TEXT NOT NULL DEFAULT 'decimalDegrees'`; `AppDatabase.currentSchemaVersion == 150`.

- [ ] **Step 1: Re-verify the schema version is still free**

```bash
git fetch origin main
git show origin/main:lib/core/database/database.dart | grep -n "currentSchemaVersion = "
```

If `origin/main` is at 149, v150 is correct. If it has moved, use the next free integer and update every `150` in this task and in Task 7.

- [ ] **Step 2: Write the failing test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v150 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(150));
    expect(AppDatabase.migrationVersions, contains(150));
  });

  test('a fresh database has diver_settings.coordinate_format', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('coordinate_format'));
  });

  test('the column defaults to decimalDegrees', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final column = cols.firstWhere(
      (c) => c.read<String>('name') == 'coordinate_format',
    );
    // Defaulting to decimal degrees means upgrading changes nobody's chosen
    // notation.
    expect(column.read<String?>('dflt_value'), contains('decimalDegrees'));
  });

  test('a database stranded before v150 gains the column via beforeOpen',
      () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('''
          CREATE TABLE diver_settings (
            id TEXT NOT NULL PRIMARY KEY,
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('coordinate_format'));
  });

  test('the assert is a no-op when the table is absent', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('CREATE TABLE unrelated (id TEXT)');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    await db.customSelect('SELECT 1').get();
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/core/database/migration_v150_coordinate_format_test.dart`
Expected: FAIL, `migrationVersions` does not contain 150.

- [ ] **Step 4: Add the table column**

In `lib/core/database/database.dart`, after `visibilityScaleModerateM` (~line 1516) and before the `// Time/Date format settings` comment:

```dart
  /// v150: how GPS coordinates are rendered and entered (issue #1041).
  ///
  /// Presentational only -- coordinates are always stored as decimal-degree
  /// doubles, so changing this re-renders every site without altering a
  /// single stored value. Defaults to 'decimalDegrees', which is what the app
  /// showed before v150.
  TextColumn get coordinateFormat =>
      text().withDefault(const Constant('decimalDegrees'))();
```

- [ ] **Step 5: Bump the schema version and ladder**

At `lib/core/database/database.dart:2956`:

```dart
  static const int currentSchemaVersion = 150;
```

At the end of the `migrationVersions` list (after `149,`):

```dart
    // v150: diver_settings.coordinate_format (issue #1041): the diver's GPS
    // coordinate notation. Presentational only -- coordinates stay decimal
    // degrees in storage.
    150,
```

- [ ] **Step 6: Add the idempotent DDL helper**

Immediately after `_assertVisibilityScaleColumns()` (which ends at ~line 4461):

```dart
  /// Idempotent DDL for the v150 diver_settings coordinate format column.
  /// Same dual-call contract as [_assertVisibilityScaleColumns].
  Future<void> _assertCoordinateFormatColumn() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('coordinate_format')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN coordinate_format '
        "TEXT NOT NULL DEFAULT 'decimalDegrees'",
      );
    }
  }
```

- [ ] **Step 7: Wire the helper into the ladder and the backstop**

In `onUpgrade`, after the `if (from < 149) await reportProgress();` line (~7791):

```dart
        // v150: the diver's GPS coordinate notation (issue #1041).
        if (from < 150) {
          await _assertCoordinateFormatColumn();
        }
        if (from < 150) await reportProgress();
```

In `beforeOpen`, alongside the other `_assert*` calls (~7911):

```dart
        await _assertCoordinateFormatColumn();
```

- [ ] **Step 8: Regenerate Drift code and run the test**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/core/database/migration_v150_coordinate_format_test.dart
```

Expected: PASS, 5 tests.

- [ ] **Step 9: Commit**

```bash
dart format .
git add lib/core/database/database.dart lib/core/database/database.g.dart test/core/database/migration_v150_coordinate_format_test.dart
git commit -m "feat(db): add diver_settings.coordinate_format in schema v150"
```

---

### Task 7: Settings plumbing

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (field ~`:124`, constructor ~`:443`, `copyWith` ~`:599` and ~`:722`, setters ~`:1198`, providers ~`:1866`)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (insert ~`:73`, update ~`:229`, map ~`:427`, parsers ~`:601`)
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (~`:5447`)
- Test: `test/features/settings/data/repositories/diver_settings_repository_coordinate_format_test.dart`

**Interfaces:**
- Consumes: `CoordinateFormat` (Task 1), the v150 column (Task 6).
- Produces: `AppSettings.coordinateFormat`, `AppSettings.copyWith(coordinateFormat:)`, `SettingsNotifier.setCoordinateFormat(CoordinateFormat)`, `final coordinateFormatProvider = Provider<CoordinateFormat>`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('AppSettings.coordinateFormat', () {
    test('defaults to decimal degrees so upgrading changes no notation', () {
      const settings = AppSettings();
      expect(settings.coordinateFormat, CoordinateFormat.decimalDegrees);
    });

    test('copyWith carries the format', () {
      const settings = AppSettings();
      final updated = settings.copyWith(coordinateFormat: CoordinateFormat.mgrs);
      expect(updated.coordinateFormat, CoordinateFormat.mgrs);
      // Unrelated settings survive.
      expect(updated.depthUnit, settings.depthUnit);
    });
  });

  group('DiverSettingsRepository coordinate format persistence', () {
    late AppDatabase db;
    late DiverSettingsRepository repository;

    setUp(() async {
      db = await setUpTestDatabase();
      repository = DiverSettingsRepository();
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: 'd1',
              name: 'Test Diver',
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('new settings default to decimal degrees', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.coordinateFormat, CoordinateFormat.decimalDegrees);
    });

    for (final format in CoordinateFormat.values) {
      test('round-trips ${format.name}', () async {
        await repository.createSettingsForDiver('d1');
        await repository.updateSettingsForDiver(
          'd1',
          AppSettings(coordinateFormat: format),
        );
        final loaded = await repository.getSettingsForDiver('d1');
        expect(loaded!.coordinateFormat, format);
      });
    }

    test('an unrecognized stored format degrades to decimal degrees', () async {
      await repository.createSettingsForDiver('d1');
      await db.customStatement(
        "UPDATE diver_settings SET coordinate_format = 'nonsense' "
        "WHERE diver_id = 'd1'",
      );
      final loaded = await repository.getSettingsForDiver('d1');
      // A corrupt preference must degrade, not throw.
      expect(loaded!.coordinateFormat, CoordinateFormat.decimalDegrees);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/settings/data/repositories/diver_settings_repository_coordinate_format_test.dart`
Expected: FAIL, `AppSettings` has no `coordinateFormat`.

- [ ] **Step 3: Add the field to `AppSettings`**

In `settings_providers.dart`, after the visibility scale fields (~line 130), add the import `import 'package:submersion/core/utils/coordinates/coordinate_format.dart';` and the field:

```dart
  /// How GPS coordinates are rendered and entered.
  ///
  /// Presentational only: coordinates are always stored as decimal degrees,
  /// so changing this re-renders every site without altering a stored value.
  final CoordinateFormat coordinateFormat;
```

Constructor (~line 446, after `visibilityScaleModerateM`):

```dart
    this.coordinateFormat = CoordinateFormat.decimalDegrees,
```

`copyWith` parameter (~line 602, after `visibilityScaleModerateM`):

```dart
    CoordinateFormat? coordinateFormat,
```

`copyWith` assignment (~line 728, after `visibilityScaleModerateM:`):

```dart
      coordinateFormat: coordinateFormat ?? this.coordinateFormat,
```

- [ ] **Step 4: Add the setter and the selector provider**

After `setVisibilityScale` (~line 1211):

```dart
  Future<void> setCoordinateFormat(CoordinateFormat format) async {
    state = state.copyWith(coordinateFormat: format);
    await _saveSettings();
  }
```

After `altitudeUnitProvider` (~line 1868):

```dart
final coordinateFormatProvider = Provider<CoordinateFormat>((ref) {
  return ref.watch(settingsProvider.select((s) => s.coordinateFormat));
});
```

- [ ] **Step 5: Wire the repository**

In `diver_settings_repository.dart`, add the import, then:

Insert defaults (~line 76, after `visibilityScaleModerateM`):

```dart
              coordinateFormat: Value(s.coordinateFormat.name),
```

Update block (~line 232):

```dart
          coordinateFormat: Value(settings.coordinateFormat.name),
```

`_mapRowToAppSettings` (~line 432):

```dart
      coordinateFormat: _parseCoordinateFormat(row.coordinateFormat),
```

New parser after `_parseVisibilityScalePreset` (~line 606):

```dart
  /// Falls back to decimal degrees, which is what the app rendered before
  /// v150, so an unrecognized stored value degrades to the previous
  /// behaviour rather than throwing.
  CoordinateFormat _parseCoordinateFormat(String value) {
    return CoordinateFormat.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CoordinateFormat.decimalDegrees,
    );
  }
```

- [ ] **Step 6: Add the sync default**

In `sync_data_serializer.dart`, inside `_applyDiverSettingDefaults` after `'sacUnit': 'litersPerMin',` (~line 5447):

```dart
        // Issue #1041. v144's visibility columns were never given defaults
        // here; this one is, so a payload from a pre-v150 peer hydrates to
        // the documented default instead of null.
        'coordinateFormat': 'decimalDegrees',
```

- [ ] **Step 7: Repair the three test doubles that implement every member**

Adding a member to `SettingsNotifier` is a breaking change for any test double that `implements` it without a `noSuchMethod` fallback. 91 files declare `implements SettingsNotifier`; 88 route unknown members through `noSuchMethod` and need nothing. These three do not, and will fail to compile:

- `test/helpers/mock_providers.dart`
- `test/features/settings/presentation/pages/settings_page_test.dart`
- `test/features/statistics/presentation/pages/records_page_test.dart`

Add to each, alongside the existing setters:

```dart
  @override
  Future<void> setCoordinateFormat(CoordinateFormat format) async =>
      state = state.copyWith(coordinateFormat: format);
```

with the `coordinate_format.dart` import. Do not add `noSuchMethod` to them — that would silently swallow future interface drift in exactly the files most likely to notice it.

- [ ] **Step 8: Run the test to verify it passes**

Run: `flutter test test/features/settings/data/repositories/diver_settings_repository_coordinate_format_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 9: Run the wider settings suite for regressions**

Run: `flutter test test/features/settings/ test/features/statistics/ test/helpers/`
Expected: PASS, no new failures.

- [ ] **Step 10: Commit**

```bash
dart format .
git add lib/features/settings lib/core/services/sync/sync_data_serializer.dart test/features/settings test/features/statistics test/helpers
git commit -m "feat(settings): persist the diver's coordinate format preference"
```

---

### Task 8: `UnitFormatter.formatCoordinates` and the display sites

**Files:**
- Modify: `lib/core/utils/unit_formatter.dart`
- Modify the display sites listed below
- Test: `test/core/utils/unit_formatter_coordinates_test.dart`

**Interfaces:**
- Consumes: `formatCoordinates`, `formatLatitude`, `formatLongitude` (Task 4), `AppSettings.coordinateFormat` (Task 7).
- Produces: `String UnitFormatter.formatCoordinates(double? latitude, double? longitude)`, `String UnitFormatter.formatLatitude(double)`, `String UnitFormatter.formatLongitude(double)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  setUp(() => Intl.defaultLocale = 'en_US');

  test('renders in the diver-selected format', () {
    const dd = UnitFormatter(AppSettings());
    expect(
      dd.formatCoordinates(20.361944, -87.029722),
      '20.361944° N, 87.029722° W',
    );

    const mgrs = UnitFormatter(
      AppSettings(coordinateFormat: CoordinateFormat.mgrs),
    );
    expect(mgrs.formatCoordinates(20.361944, -87.029722), '16Q DH 96898 51535');
  });

  test('renders the placeholder when either axis is missing', () {
    const formatter = UnitFormatter(AppSettings());
    expect(formatter.formatCoordinates(null, -87.029722), '--');
    expect(formatter.formatCoordinates(20.361944, null), '--');
    expect(formatter.formatCoordinates(null, null), '--');
  });

  test('single-axis helpers follow the same preference', () {
    const formatter = UnitFormatter(
      AppSettings(coordinateFormat: CoordinateFormat.degreesDecimalMinutes),
    );
    expect(formatter.formatLatitude(20.361944), "20° 21.717' N");
    expect(formatter.formatLongitude(-87.029722), "87° 01.783' W");
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/utils/unit_formatter_coordinates_test.dart`
Expected: FAIL, `formatCoordinates` is not defined.

- [ ] **Step 3: Add the methods to `UnitFormatter`**

Add the import `import 'package:submersion/core/utils/coordinates/coordinate_formatter.dart' as coords;` and, after the depth section:

```dart
  // ============================================================================
  // Coordinates
  // ============================================================================

  /// Format a coordinate pair in the diver's chosen notation.
  ///
  /// Returns the standard '--' placeholder unless both axes are present: half
  /// a coordinate is not a position.
  String formatCoordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return '--';
    return coords.formatCoordinates(
      latitude,
      longitude,
      settings.coordinateFormat,
    );
  }

  /// Format a single latitude. Grid formats degrade to decimal degrees, since
  /// one axis of a grid reference means nothing on its own.
  String formatLatitude(double latitude) =>
      coords.formatLatitude(latitude, settings.coordinateFormat);

  /// Format a single longitude. See [formatLatitude] on grid formats.
  String formatLongitude(double longitude) =>
      coords.formatLongitude(longitude, settings.coordinateFormat);
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/utils/unit_formatter_coordinates_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Migrate the user-facing display sites**

Replace the inline `toStringAsFixed` coordinate rendering with `units.formatCoordinates(lat, lng)` at each site below. Every one of these already has, or is a `ConsumerWidget` that can obtain, `final units = UnitFormatter(ref.watch(settingsProvider));`.

| File | Line | Note |
| --- | --- | --- |
| `lib/features/dive_sites/presentation/pages/site_detail_page.dart` | 944, 950 | Display and the tap-to-copy clipboard payload. Copy what the diver sees. |
| `lib/features/dive_log/presentation/widgets/surface_gps_section.dart` | 329 | Entry/exit GPS label |
| `lib/features/dive_3d/presentation/widgets/seascape_hover_tooltip.dart` | 50-51 | |
| `lib/features/media/presentation/widgets/quick_site_from_gps_dialog.dart` | 78, 97-98 | |
| `lib/features/media/presentation/widgets/photo_gps_suggestion_banner.dart` | 101-102 | Passed as an l10n argument |
| `lib/features/media/presentation/widgets/write_metadata_dialog.dart` | 120-121 | |
| `lib/features/equipment/presentation/widgets/geofence_editor_sheet.dart` | 154-155 | |
| `lib/features/dive_sites/presentation/widgets/location_picker_map.dart` | 289-291, 318, 344 | Line 289 also feeds the semantics label |
| `lib/features/dive_sites/presentation/pages/site_import_page.dart` | 798-799 | |
| `lib/features/dive_centers/presentation/pages/dive_center_import_page.dart` | 782-783 | |
| `lib/features/dive_centers/domain/constants/dive_center_field.dart` | 231-232 | Field-value display |
| `lib/features/dive_sites/domain/constants/site_field.dart` | 519 | Field-value display |
| `lib/features/import_wizard/data/adapters/universal_adapter.dart` | 736 | Import preview subtitle |
| `lib/features/universal_import/data/services/import_duplicate_checker.dart` | 451 | Duplicate preview subtitle |
| `lib/features/maps/presentation/pages/offline_maps_page.dart` | 499-502 | Region SW/NE bounds |

**Do not change** `GeoPoint.toString()` in `lib/features/dive_sites/domain/entities/dive_site.dart:221` — it is a domain entity with no settings access, and export and cache-key callers depend on its stable decimal form. Also leave every file listed under "Out of scope" in the spec: the CSV and Excel exporters, the reef/bathymetry/weather/dashboard cache keys, and all log statements.

For the two `domain/constants` files, which are not widgets: pass the already-constructed `UnitFormatter` in from the caller rather than reading a provider from domain code.

- [ ] **Step 6: Run the affected suites**

Run: `flutter test test/features/dive_sites test/features/media test/features/dive_centers test/features/equipment`
Expected: PASS. Some tests assert the old bare-decimal strings; update those assertions to the new DD rendering, which is a deliberate change.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/core/utils/unit_formatter.dart lib/features test/core/utils/unit_formatter_coordinates_test.dart test/features
git commit -m "feat(coordinates): render every displayed coordinate in the chosen format"
```

---

### Task 9: `CoordinateInput` widget

**Files:**
- Create: `lib/shared/widgets/forms/coordinate_input.dart`
- Test: `test/shared/widgets/forms/coordinate_input_test.dart`

**Interfaces:**
- Consumes: `CoordinateFormat` (Task 1), `formatLatitude`/`formatLongitude` (Task 4), `parseCoordinates`/`parseSingleAxis` (Task 5), `latLngToUtm`/`utmToLatLng` (Task 2), `latLngToMgrs`/`mgrsToLatLng` (Task 3).
- Produces:

```dart
class CoordinateInput extends StatefulWidget {
  const CoordinateInput({
    super.key,
    required this.format,
    required this.latitude,
    required this.longitude,
    required this.onChanged,
    this.latitudeLabel,
    this.longitudeLabel,
    this.errorText,
  });

  final CoordinateFormat format;
  final double? latitude;
  final double? longitude;
  final void Function(double? latitude, double? longitude) onChanged;
  final String? latitudeLabel;
  final String? longitudeLabel;
  final String? errorText;
}
```

The public interface is decimal degrees in both directions, so the consuming form's validators and save path never learn which format is active.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/shared/widgets/forms/coordinate_input.dart';

void main() {
  Future<void> pumpInput(
    WidgetTester tester, {
    required CoordinateFormat format,
    double? latitude,
    double? longitude,
    required void Function(double?, double?) onChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoordinateInput(
            format: format,
            latitude: latitude,
            longitude: longitude,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  testWidgets('decimal degrees shows two axis fields', (tester) async {
    await pumpInput(
      tester,
      format: CoordinateFormat.decimalDegrees,
      latitude: 20.361944,
      longitude: -87.029722,
      onChanged: (_, _) {},
    );
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('mgrs collapses to a single grid reference field',
      (tester) async {
    await pumpInput(
      tester,
      format: CoordinateFormat.mgrs,
      latitude: 20.361944,
      longitude: -87.029722,
      onChanged: (_, _) {},
    );
    // One axis-independent field, seeded with the reference.
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('16Q DH 96898 51535'), findsOneWidget);
  });

  testWidgets('utm shows zone, easting and northing', (tester) async {
    await pumpInput(
      tester,
      format: CoordinateFormat.utm,
      latitude: 20.361944,
      longitude: -87.029722,
      onChanged: (_, _) {},
    );
    expect(find.text('16Q'), findsOneWidget);
    expect(find.text('496898'), findsOneWidget);
    expect(find.text('2251535'), findsOneWidget);
  });

  testWidgets('editing a decimal field reports decimal degrees out',
      (tester) async {
    double? lat;
    double? lng;
    await pumpInput(
      tester,
      format: CoordinateFormat.decimalDegrees,
      latitude: 0,
      longitude: 0,
      onChanged: (a, b) {
        lat = a;
        lng = b;
      },
    );
    await tester.enterText(find.byType(TextFormField).first, '20.361944');
    await tester.pump();
    expect(lat, closeTo(20.361944, 1e-9));
  });

  testWidgets('typing a grid reference reports decimal degrees out',
      (tester) async {
    double? lat;
    double? lng;
    await pumpInput(
      tester,
      format: CoordinateFormat.mgrs,
      onChanged: (a, b) {
        lat = a;
        lng = b;
      },
    );
    await tester.enterText(find.byType(TextFormField), '16Q DH 96898 51535');
    await tester.pump();
    expect(lat, closeTo(20.361944, 2e-5));
    expect(lng, closeTo(-87.029722, 2e-5));
  });

  testWidgets('pasting any format into an axis field fills both axes',
      (tester) async {
    double? lat;
    double? lng;
    await pumpInput(
      tester,
      format: CoordinateFormat.decimalDegrees,
      onChanged: (a, b) {
        lat = a;
        lng = b;
      },
    );
    // A DMS pair pasted while the app is set to decimal degrees still works:
    // text arrives in whatever notation its author used.
    await tester.enterText(
      find.byType(TextFormField).first,
      '20° 21\' 43.0" N, 87° 01\' 47.0" W',
    );
    await tester.pump();
    expect(lat, closeTo(20.361944, 1e-4));
    expect(lng, closeTo(-87.029722, 1e-4));
  });

  testWidgets('an unparseable entry reports null rather than a stale value',
      (tester) async {
    double? lat = 1;
    await pumpInput(
      tester,
      format: CoordinateFormat.decimalDegrees,
      onChanged: (a, _) => lat = a,
    );
    await tester.enterText(find.byType(TextFormField).first, 'not a number');
    await tester.pump();
    expect(lat, isNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/shared/widgets/forms/coordinate_input_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Implement the widget**

Build a `StatefulWidget` holding one `TextEditingController` per visible sub-field. Rules:

1. `didUpdateWidget` re-seeds the controllers when `widget.format` changes or when the incoming lat/lng differ from what the controllers currently represent. Never re-seed on every rebuild — that fights the user's cursor.
2. Each controller has a listener that recomputes a `(double?, double?)` pair from all current sub-fields and calls `widget.onChanged`.
3. **Before** per-axis parsing, run the whole field text through `parseCoordinates`. If it returns a pair, the user pasted a full coordinate: fill every sub-field from it and report it. This is what makes paste work in any format.
4. Layout by format:
   - `decimalDegrees`: two fields, seeded with `formatLatitude`/`formatLongitude` stripped to the bare signed decimal for editing, parsed with `parseSingleAxis`.
   - `degreesDecimalMinutes`: per axis, degrees + decimal-minutes fields and an N/S or E/W `DropdownButton`.
   - `degreesMinutesSeconds`: per axis, degrees + minutes + seconds fields and the hemisphere dropdown.
   - `utm`: a zone-and-band field (e.g. `16Q`), an easting field, a northing field; convert with `utmToLatLng`.
   - `mgrs`: one field; convert with `mgrsToLatLng`.
5. Report `null, null` whenever the current sub-fields do not form a complete valid coordinate, so a half-typed entry never looks like a saved position.
6. Show `widget.errorText` beneath the group when non-null.

Use `FormRow.text` from `lib/shared/widgets/forms/form_row.dart` for individual fields so the group matches the surrounding form chrome.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/shared/widgets/forms/coordinate_input_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```bash
dart format .
git add lib/shared/widgets/forms/coordinate_input.dart test/shared/widgets/forms/coordinate_input_test.dart
git commit -m "feat(coordinates): add adaptive CoordinateInput widget"
```

---

### Task 10: Wire `CoordinateInput` into the edit forms

**Files:**
- Modify: `lib/features/dive_sites/presentation/widgets/edit_sections/location_section.dart:39-44, 73-92`
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart:76-77, 118-127, 158-159, 190-191, 227-228, 257-258, 743-744, 1145-1146, 1210-1211, 1245-1246, 1260-1261, 1332-1333, 1578-1582`
- Modify: `lib/features/dive_centers/presentation/pages/dive_center_edit_page.dart:46-47, 90-91, 104-105, 148-149, 172-173, 209-211, 911-912, 954-955, 1018-1019`
- Test: `test/features/dive_sites/presentation/site_edit_coordinate_format_test.dart`

**Interfaces:**
- Consumes: `CoordinateInput` (Task 9), `coordinateFormatProvider` (Task 7).
- Produces: no new public API.

`LocationSection` swaps `latitudeController`/`longitudeController`/`latValidator`/`lonValidator` for `latitude`, `longitude`, `onCoordinatesChanged`, `coordinateError`, and `coordinateFormat`. Both pages keep `double?` fields for the current coordinate instead of two text controllers; every existing `double.tryParse(_latitudeController.text)` site reads the `double?` directly, and every site that wrote formatted text into a controller now assigns the `double?`.

- [ ] **Step 1: Write the failing test**

`LocationSection` is a plain `StatelessWidget`, so it can be hosted directly with no `ProviderScope` and no database — the same approach `visibility_scale_picker_test.dart` takes.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/location_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/coordinate_input.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  Widget section({
    required CoordinateFormat format,
    double? latitude,
    double? longitude,
    required void Function(double?, double?) onChanged,
  }) {
    return LocationSection(
      expanded: true,
      onToggle: () {},
      summary: '',
      isEmpty: false,
      latitude: latitude,
      longitude: longitude,
      coordinateFormat: format,
      onCoordinatesChanged: onChanged,
      altitudeController: TextEditingController(),
      altitudeValidator: (_) => null,
      isGettingLocation: false,
      onUseMyLocation: () {},
      onPickFromMap: () {},
      units: const UnitFormatter(AppSettings()),
    );
  }

  testWidgets('hosts a CoordinateInput in the active format', (tester) async {
    await tester.pumpWidget(
      host(
        section(
          format: CoordinateFormat.mgrs,
          latitude: 20.361944,
          longitude: -87.029722,
          onChanged: (_, _) {},
        ),
      ),
    );

    final input = tester.widget<CoordinateInput>(find.byType(CoordinateInput));
    expect(input.format, CoordinateFormat.mgrs);
    expect(find.text('16Q DH 96898 51535'), findsOneWidget);
  });

  testWidgets('a grid reference typed in MGRS reports decimal degrees out',
      (tester) async {
    double? lat;
    double? lng;
    await tester.pumpWidget(
      host(
        section(
          format: CoordinateFormat.mgrs,
          onChanged: (a, b) {
            lat = a;
            lng = b;
          },
        ),
      ),
    );

    await tester.enterText(
      find.descendant(
        of: find.byType(CoordinateInput),
        matching: find.byType(TextFormField),
      ),
      '16Q DH 96898 51535',
    );
    await tester.pump();

    // The whole feature rests on this: the diver types a grid reference and
    // the form hands the page decimal degrees to store.
    expect(lat, closeTo(20.361944, 2e-5));
    expect(lng, closeTo(-87.029722, 2e-5));
  });

  testWidgets('switching format re-renders the same position', (tester) async {
    await tester.pumpWidget(
      host(
        section(
          format: CoordinateFormat.decimalDegrees,
          latitude: 20.361944,
          longitude: -87.029722,
          onChanged: (_, _) {},
        ),
      ),
    );
    expect(find.text('20.361944'), findsOneWidget);

    await tester.pumpWidget(
      host(
        section(
          format: CoordinateFormat.degreesMinutesSeconds,
          latitude: 20.361944,
          longitude: -87.029722,
          onChanged: (_, _) {},
        ),
      ),
    );
    // Same stored position, different notation: 20 degrees 21 minutes.
    expect(find.text('21'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/site_edit_coordinate_format_test.dart`
Expected: FAIL.

- [ ] **Step 3: Change `LocationSection`'s interface**

Replace the four coordinate parameters with:

```dart
    required this.latitude,
    required this.longitude,
    required this.onCoordinatesChanged,
    required this.coordinateFormat,
    this.coordinateError,
```

```dart
  final double? latitude;
  final double? longitude;
  final void Function(double? latitude, double? longitude) onCoordinatesChanged;
  final CoordinateFormat coordinateFormat;
  final String? coordinateError;
```

and replace the two `FormRow.text` blocks at lines 73-92 with:

```dart
            CoordinateInput(
              format: coordinateFormat,
              latitude: latitude,
              longitude: longitude,
              onChanged: onCoordinatesChanged,
              latitudeLabel: l10n.diveSites_edit_gps_latitude_label,
              longitudeLabel: l10n.diveSites_edit_gps_longitude_label,
              errorText: coordinateError,
            ),
```

- [ ] **Step 4: Convert `site_edit_page.dart` to `double?` state**

Replace `_latitudeController` and `_longitudeController` with `double? _latitude; double? _longitude;` plus `String? _coordinateError;`. At each listed line, replace controller text reads with the field and controller writes with an assignment inside `setState`. The save path at `:1332-1333` uses `_latitude`/`_longitude` directly instead of `double.tryParse`. Read `coordinateFormatProvider` in `build` and pass it down.

- [ ] **Step 5: Apply the same conversion to `dive_center_edit_page.dart`**

Same shape at the listed lines. This page builds its coordinate fields inline rather than through a section widget, so drop `CoordinateInput` in where the two `TextFormField`s currently are.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/dive_sites test/features/dive_centers`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format .
git add lib/features/dive_sites lib/features/dive_centers test/features/dive_sites test/features/dive_centers
git commit -m "feat(coordinates): enter coordinates in the diver's chosen format"
```

---

### Task 11: Settings UI and localization

**Files:**
- Create: `lib/features/settings/presentation/widgets/coordinate_format_picker.dart`
- Modify: `lib/features/settings/presentation/pages/settings_page.dart:521-530`
- Modify: all 11 files in `lib/l10n/arb/`
- Test: `test/features/settings/presentation/coordinate_format_picker_test.dart`

**Interfaces:**
- Consumes: `CoordinateFormat` (Task 1), `formatCoordinates` (Task 4), `SettingsNotifier.setCoordinateFormat` (Task 7).
- Produces: `void showCoordinateFormatPicker(BuildContext, WidgetRef, AppSettings)` and `String coordinateFormatLabel(AppLocalizations, CoordinateFormat)`, mirroring `visibility_scale_picker.dart`.

- [ ] **Step 1: Add the English ARB keys**

In `lib/l10n/arb/app_en.arb`, beside the other settings keys (these take no placeholders, so no `@` metadata blocks, matching the visibility-scale keys):

```json
  "settings_coordinateFormat_title": "Coordinate format",
  "settings_coordinateFormat_subtitle": "How GPS positions are shown and entered",
  "settings_coordinateFormat_decimalDegrees": "Decimal degrees",
  "settings_coordinateFormat_degreesDecimalMinutes": "Degrees and decimal minutes",
  "settings_coordinateFormat_degreesMinutesSeconds": "Degrees, minutes, seconds",
  "settings_coordinateFormat_utm": "UTM",
  "settings_coordinateFormat_mgrs": "MGRS",
```

- [ ] **Step 2: Translate into the other ten locales**

Add the same seven keys to `app_ar`, `app_de`, `app_es`, `app_fr`, `app_he`, `app_hu`, `app_it`, `app_nl`, `app_pt`, `app_zh`, translated. `UTM` and `MGRS` are proper nouns and stay as-is in every locale. Then regenerate:

```bash
flutter gen-l10n
```

- [ ] **Step 3: Write the failing test**

Modelled directly on `test/features/settings/presentation/widgets/visibility_scale_picker_test.dart`, which is the closest precedent — a recording fake with a `noSuchMethod` fallback, hosted without a database.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/coordinate_format_picker.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Stands in for SettingsNotifier so the picker's saves can be inspected
/// without a database. Only setCoordinateFormat is exercised here.
class _RecordingSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  final List<CoordinateFormat> saved;

  _RecordingSettingsNotifier(super.initial, this.saved);

  @override
  Future<void> setCoordinateFormat(CoordinateFormat format) async {
    state = state.copyWith(coordinateFormat: format);
    saved.add(format);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late List<CoordinateFormat> saved;
  late ProviderContainer container;

  setUp(() {
    saved = [];
    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _RecordingSettingsNotifier(const AppSettings(), saved),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  Widget host(Widget child) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  Future<void> openPicker(WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => showCoordinateFormatPicker(
              context,
              ref,
              container.read(settingsProvider),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers every format', (tester) async {
    await openPicker(tester);
    for (final format in CoordinateFormat.values) {
      expect(
        find.text(coordinateFormatLabel(
          AppLocalizations.of(tester.element(find.byType(Scaffold)))!,
          format,
        )),
        findsOneWidget,
        reason: 'missing an option for ${format.name}',
      );
    }
  });

  testWidgets('shows the same sample point rendered in each notation',
      (tester) async {
    await openPicker(tester);
    // The worked examples are what make the choice legible to a diver who
    // does not already know the notations by name.
    expect(find.text('20.361944° N, 87.029722° W'), findsOneWidget);
    expect(find.text("20° 21.717' N, 87° 01.783' W"), findsOneWidget);
    expect(find.text('16Q DH 96898 51535'), findsOneWidget);
  });

  testWidgets('selecting a format saves it and closes', (tester) async {
    await openPicker(tester);
    await tester.tap(find.text('16Q DH 96898 51535'));
    await tester.pumpAndSettle();

    expect(saved, [CoordinateFormat.mgrs]);
    expect(find.text('16Q DH 96898 51535'), findsNothing);
  });
}
```

- [ ] **Step 4: Implement the picker**

Model on `lib/features/settings/presentation/widgets/visibility_scale_picker.dart`. Each `ListTile` shows the format's localized name as the title and the shared sample point rendered in that format as the subtitle:

```dart
/// A recognizable reef so the sample reads as a real position rather than
/// test data. Cozumel's Palancar reef.
const double _sampleLatitude = 20.361944;
const double _sampleLongitude = -87.029722;
```

- [ ] **Step 5: Add the settings tile**

In `settings_page.dart`, after the visibility-scale tile (~line 530):

```dart
                  const Divider(height: 1),
                  _buildUnitTile(
                    context,
                    title: context.l10n.settings_coordinateFormat_title,
                    value: coordinateFormatLabel(
                      context.l10n,
                      settings.coordinateFormat,
                    ),
                    onTap: () =>
                        showCoordinateFormatPicker(context, ref, settings),
                  ),
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/settings/`
Expected: PASS.

- [ ] **Step 7: Full verification**

```bash
dart format .
flutter analyze
flutter test
```

Expected: no formatting changes, no analyzer issues, all tests pass.

- [ ] **Step 8: Commit**

```bash
git add lib/features/settings lib/l10n test/features/settings
git commit -m "feat(settings): let the diver choose a GPS coordinate format"
```

---

## Verification Checklist

- [ ] `flutter analyze` is clean across the whole project
- [ ] `dart format .` produces no changes
- [ ] `flutter test` passes in full
- [ ] `AppDatabase.currentSchemaVersion` is still the next free integer on `origin/main`
- [ ] All 11 ARB files carry the seven new keys
- [ ] Exports (CSV, Excel, UDDF, GPX) still emit decimal degrees
- [ ] Cache keys in the reef, bathymetry, weather, and dashboard layers are unchanged
- [ ] A site created by typing an MGRS reference stores the same decimal degrees as one created by typing DD
