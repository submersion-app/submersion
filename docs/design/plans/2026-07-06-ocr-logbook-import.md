# OCR Paper Logbook Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Photograph a paper dive log page and turn it into a prefilled Submersion dive entry, fully on-device.

**Architecture:** Three layers per the approved spec (`docs/superpowers/specs/2026-07-06-ocr-logbook-import-design.md`): an `OcrEngine` interface with per-platform implementations (Apple Vision, ML Kit, Windows OCR, Tesseract), a pure-Dart layout-aware parser that turns positioned text into `ParsedDiveFields`, and a scan flow that ends in `DiveEditPage` (create mode) prefilled via a new `DivePrefill` parameter with the source photo attached.

**Tech Stack:** Flutter/Dart, Riverpod, go_router, `google_mlkit_text_recognition` (Android), new in-repo plugin `packages/submersion_ocr` (Swift Vision for iOS/macOS, C++ WinRT for Windows), Tesseract CLI (Linux).

## Global Constraints

- Worktree: all work happens in `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/ocr-logbook-import` on branch `worktree-ocr-logbook-import`. Never touch the main checkout.
- All values stored METRIC (meters, bar, celsius, liters, kg). Display conversion is DiveEditPage's job, not ours — `DivePrefill` carries metric.
- `dart format .` must produce no changes before every commit.
- Run `flutter analyze` (whole project, never piped through tail) before every commit.
- Run only the specific test files you created/changed (broad `flutter test` times out).
- New user-facing strings go in `lib/l10n/arb/app_en.arb` AND all 10 other locales (ar, de, es, fr, he, hu, it, nl, pt, zh), then `flutter gen-l10n`.
- No emojis anywhere. No `print` in production code.
- Commit after each task. No Co-Authored-By lines in commit messages.
- Mocking library: `mockito ^5.6.1` is the project standard, but prefer hand-written fakes for the small interfaces in this feature.
- If DB-touching tests fail with "database.g.dart not found", run `dart run build_runner build --delete-conflicting-outputs` once.

## Spec deviations (agreed during planning)

1. The parser emits a feature-local `ParsedDiveFields` model, not `IncomingDiveData` — the shared model lacks most paper-log fields and is only used for dive-computer comparison UI.
2. `DiveEditPage`'s site field holds a `DiveSite?` object (no free text). An unresolved OCR site name therefore goes into a notes appendix instead of "prefilling the site field"; a confidently fuzzy-matched existing site is pre-linked.
3. Visibility on the edit form is an enum dropdown, not a number; extracted visibility text goes to the notes appendix.
4. Buddy/divemaster are structured entities on the form (`BuddyWithRole` via picker); extracted names go to the notes appendix in v1.
5. The spec named two entry points (add-dive menu + import hub tile). The add-dive bottom sheet turned out to BE the app's import source list (Log Manually / Import from Computer), so v1 ships that single entry point; a tile in the `/transfer` import wizard area is deferred.

## File Structure

```
lib/features/ocr_import/
  domain/models/ocr_result.dart          # OcrTextBlock, OcrResult
  domain/models/parsed_dive_fields.dart  # parser output (metric)
  domain/services/ocr_engine.dart        # abstract OcrEngine
  domain/services/value_normalizer.dart  # shorthand token parsing
  domain/services/label_definitions.dart # LogField enum + label table
  domain/services/label_binder.dart      # geometric label->value binding
  domain/services/unit_context.dart      # page-level unit inference
  domain/services/logbook_parser.dart    # orchestrates it all
  domain/services/site_resolver.dart     # fuzzy site-name -> DiveSite
  data/engines/mlkit_ocr_engine.dart     # Android
  data/engines/channel_ocr_engine.dart   # iOS/macOS/Windows via plugin
  data/engines/tesseract_ocr_engine.dart # Linux
  presentation/providers/ocr_providers.dart  # engine factory provider
  presentation/controllers/scan_flow_controller.dart
  presentation/pages/ocr_scan_page.dart
lib/features/dive_log/domain/entities/dive_prefill.dart  # DivePrefill
packages/submersion_ocr/                # new plugin: darwin + windows
test/features/ocr_import/...            # mirrors lib structure
test/features/ocr_import/fixtures/      # sample-page OcrResult fixtures
```

Modified: `pubspec.yaml`, `lib/features/dive_log/presentation/pages/dive_edit_page.dart`, `lib/features/dive_log/presentation/widgets/add_dive_bottom_sheet.dart`, `lib/core/router/app_router.dart`, `lib/features/media/data/services/media_import_service.dart`, all 11 arb files.

---

### Task 1: Domain models and OcrEngine interface

**Files:**
- Create: `lib/features/ocr_import/domain/models/ocr_result.dart`
- Create: `lib/features/ocr_import/domain/models/parsed_dive_fields.dart`
- Create: `lib/features/ocr_import/domain/services/ocr_engine.dart`
- Test: `test/features/ocr_import/domain/models/ocr_result_test.dart`

**Interfaces:**
- Consumes: nothing (foundation task).
- Produces: `OcrTextBlock(text, boundingBox, confidence)`, `OcrResult(blocks, imageSize)`, `ParsedDiveFields` (all-optional metric fields + `unmapped` map), `abstract class OcrEngine { Future<OcrResult> recognize(Uint8List imageBytes); Future<bool> get isAvailable; }`. Every later task uses these exact names.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/ocr_import/domain/models/ocr_result_test.dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';

void main() {
  group('OcrTextBlock', () {
    test('exposes center of bounding box', () {
      const block = OcrTextBlock(
        text: 'DEPTH',
        boundingBox: Rect.fromLTWH(10, 20, 40, 10),
      );
      expect(block.center, const Offset(30, 25));
    });

    test('height reflects bounding box height', () {
      const block = OcrTextBlock(
        text: '69',
        boundingBox: Rect.fromLTWH(0, 0, 20, 14),
      );
      expect(block.height, 14);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/ocr_import/domain/models/ocr_result_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'submersion/features/ocr_import...'` (file does not exist).

- [ ] **Step 3: Write the models**

```dart
// lib/features/ocr_import/domain/models/ocr_result.dart
import 'dart:ui';

import 'package:equatable/equatable.dart';

/// A single fragment of recognized text with its position on the page.
///
/// [boundingBox] is in image pixel coordinates, origin top-left
/// (engines that use other conventions convert before constructing this).
class OcrTextBlock extends Equatable {
  final String text;
  final Rect boundingBox;
  final double? confidence;

  const OcrTextBlock({
    required this.text,
    required this.boundingBox,
    this.confidence,
  });

  Offset get center => boundingBox.center;
  double get height => boundingBox.height;

  @override
  List<Object?> get props => [text, boundingBox, confidence];
}

/// Positioned text recognized from one page image.
class OcrResult extends Equatable {
  final List<OcrTextBlock> blocks;
  final Size imageSize;

  const OcrResult({required this.blocks, required this.imageSize});

  bool get isEmpty => blocks.isEmpty;

  @override
  List<Object?> get props => [blocks, imageSize];
}
```

```dart
// lib/features/ocr_import/domain/models/parsed_dive_fields.dart
import 'package:equatable/equatable.dart';

/// Parser output. All values metric: meters, bar, celsius, liters, kg.
/// Null means "not confidently extracted" — never guessed.
class ParsedDiveFields extends Equatable {
  final int? diveNumber;
  final DateTime? date; // date component; time merged in when found
  final bool hasTimeOfDay; // true when [date] includes a real Time In
  final int? durationMinutes;
  final double? maxDepthMeters;
  final double? waterTempCelsius;
  final double? airTempCelsius;
  final double? startPressureBar;
  final double? endPressureBar;
  final double? o2Percent;
  final double? cylinderVolumeLiters;
  final double? weightKg;
  final String? siteName;
  final String? locationText; // country/region line when distinct from site
  final String? notes;
  final int? rating; // 1-5, only when written as text/number

  /// Extracted but unmappable values (visibility, buddy, divemaster,
  /// unresolved site name...). Rendered as a notes appendix by the flow.
  final Map<String, String> unmapped;

  const ParsedDiveFields({
    this.diveNumber,
    this.date,
    this.hasTimeOfDay = false,
    this.durationMinutes,
    this.maxDepthMeters,
    this.waterTempCelsius,
    this.airTempCelsius,
    this.startPressureBar,
    this.endPressureBar,
    this.o2Percent,
    this.cylinderVolumeLiters,
    this.weightKg,
    this.siteName,
    this.locationText,
    this.notes,
    this.rating,
    this.unmapped = const {},
  });

  bool get isEmpty =>
      diveNumber == null &&
      date == null &&
      durationMinutes == null &&
      maxDepthMeters == null &&
      waterTempCelsius == null &&
      airTempCelsius == null &&
      startPressureBar == null &&
      endPressureBar == null &&
      o2Percent == null &&
      cylinderVolumeLiters == null &&
      weightKg == null &&
      siteName == null &&
      locationText == null &&
      notes == null &&
      rating == null &&
      unmapped.isEmpty;

  @override
  List<Object?> get props => [
    diveNumber,
    date,
    hasTimeOfDay,
    durationMinutes,
    maxDepthMeters,
    waterTempCelsius,
    airTempCelsius,
    startPressureBar,
    endPressureBar,
    o2Percent,
    cylinderVolumeLiters,
    weightKg,
    siteName,
    locationText,
    notes,
    rating,
    unmapped,
  ];
}
```

```dart
// lib/features/ocr_import/domain/services/ocr_engine.dart
import 'dart:typed_data';

import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';

/// Pixels in, positioned text out. Implementations must be dumb:
/// no parsing, no field logic — that all lives in LogbookParser.
abstract class OcrEngine {
  /// Whether the engine can run on this device (e.g. Tesseract installed).
  Future<bool> get isAvailable;

  Future<OcrResult> recognize(Uint8List imageBytes);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/ocr_import/domain/models/ocr_result_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/ocr_import test/features/ocr_import
git commit -m "feat(ocr-import): domain models and OcrEngine interface"
```

---

### Task 2: Value normalizer

**Files:**
- Create: `lib/features/ocr_import/domain/services/value_normalizer.dart`
- Test: `test/features/ocr_import/domain/services/value_normalizer_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces (top-level functions, all null-safe on garbage input):
  - `QuantityToken? parseQuantity(String raw)` where `class QuantityToken { final double value; final String? unit; }` — unit is a lowercase canonical token: `'m'|'ft'|'bar'|'psi'|'c'|'f'|'min'|'l'|'cuft'|'kg'|'lbs'|'%'` or null when bare. Handles `3K` (pressure shorthand: value 3000, unit null), `11.1m`, `60 ft`, `200 bar`, `73`, `24°C`.
  - `DateTime? parseDateToken(String raw, {required bool preferDayFirst})` — handles `6 Feb '06`, `05/14/2023`, `2023-05-14`, `14.5.2023`; >12 rule disambiguates ambiguous numerics, else `preferDayFirst` decides; rejects future dates > now.
  - `Duration? parseDurationToken(String raw)` — `42 min`, `45min`, `0:32`, `32`.
  - `({int hour, int minute})? parseClockToken(String raw)` — `10:00A`, `10:32`, `2:15 PM`; rejects >23:59.
  - `double? parseO2Percent(String raw)` — `EAN32`, `32%`, `Nitrox 32`; range-gated 21-100.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/ocr_import/domain/services/value_normalizer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/ocr_import/domain/services/value_normalizer.dart';

void main() {
  group('parseQuantity', () {
    test('explicit metric depth with decimal', () {
      final q = parseQuantity('11.1m');
      expect(q!.value, 11.1);
      expect(q.unit, 'm');
    });

    test('imperial with space', () {
      final q = parseQuantity('60 ft');
      expect(q!.value, 60);
      expect(q.unit, 'ft');
    });

    test('pressure K shorthand expands to thousands, unit unknown', () {
      final q = parseQuantity('3K');
      expect(q!.value, 3000);
      expect(q.unit, isNull);
    });

    test('bar pressure', () {
      final q = parseQuantity('200 bar');
      expect(q!.value, 200);
      expect(q.unit, 'bar');
    });

    test('temperature with degree symbol', () {
      final q = parseQuantity('24°C');
      expect(q!.value, 24);
      expect(q.unit, 'c');
    });

    test('bare number has null unit', () {
      final q = parseQuantity('69');
      expect(q!.value, 69);
      expect(q.unit, isNull);
    });

    test('garbage returns null', () {
      expect(parseQuantity('The Wheel only'), isNull);
    });
  });

  group('parseDateToken', () {
    test('handwritten month name with two-digit year', () {
      expect(
        parseDateToken("6 Feb '06", preferDayFirst: false),
        DateTime(2006, 2, 6),
      );
    });

    test('slash date disambiguated by >12 rule', () {
      // 14 cannot be a month, so this is MM/DD even with preferDayFirst.
      expect(
        parseDateToken('05/14/2023', preferDayFirst: true),
        DateTime(2023, 5, 14),
      );
    });

    test('ambiguous slash date follows preferDayFirst', () {
      expect(
        parseDateToken('05/04/2023', preferDayFirst: true),
        DateTime(2023, 4, 5),
      );
      expect(
        parseDateToken('05/04/2023', preferDayFirst: false),
        DateTime(2023, 5, 4),
      );
    });

    test('ISO date', () {
      expect(
        parseDateToken('2023-05-14', preferDayFirst: true),
        DateTime(2023, 5, 14),
      );
    });

    test('future dates rejected', () {
      final nextYear = DateTime.now().year + 1;
      expect(parseDateToken('01/01/$nextYear', preferDayFirst: false), isNull);
    });
  });

  group('parseDurationToken', () {
    test('minutes with suffix', () {
      expect(parseDurationToken('45min'), const Duration(minutes: 45));
    });

    test('colon form is hours:minutes', () {
      expect(parseDurationToken('0:32'), const Duration(minutes: 32));
    });

    test('bare number treated as minutes', () {
      expect(parseDurationToken('32'), const Duration(minutes: 32));
    });
  });

  group('parseClockToken', () {
    test('AM shorthand', () {
      expect(parseClockToken('10:00A'), (hour: 10, minute: 0));
    });

    test('PM shorthand adds 12', () {
      expect(parseClockToken('2:15 PM'), (hour: 14, minute: 15));
    });

    test('plain 24h time', () {
      expect(parseClockToken('10:32'), (hour: 10, minute: 32));
    });

    test('rejects impossible time', () {
      expect(parseClockToken('31:00'), isNull);
    });
  });

  group('parseO2Percent', () {
    test('EAN prefix', () => expect(parseO2Percent('EAN32'), 32));
    test('percent form', () => expect(parseO2Percent('32%'), 32));
    test('nitrox word', () => expect(parseO2Percent('Nitrox 32'), 32));
    test('out of range rejected', () => expect(parseO2Percent('EAN12'), isNull));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/ocr_import/domain/services/value_normalizer_test.dart`
Expected: FAIL — package import unresolved.

- [ ] **Step 3: Implement the normalizer**

```dart
// lib/features/ocr_import/domain/services/value_normalizer.dart
/// Shorthand-tolerant token parsing for paper logbook values.
///
/// These functions never throw; unparseable input returns null.
library;

class QuantityToken {
  final double value;

  /// Canonical lowercase unit token
  /// ('m','ft','bar','psi','c','f','min','l','cuft','kg','lbs','%')
  /// or null when the number is bare.
  final String? unit;

  const QuantityToken(this.value, this.unit);
}

final _quantityRe = RegExp(
  r'^([0-9]+(?:[.,][0-9]+)?)\s*'
  r"(k|m|ft|'|bar|psi|°?\s*c|°?\s*f|min|mins|l|cuft|kg|lbs|%)?\s*$",
  caseSensitive: false,
);

QuantityToken? parseQuantity(String raw) {
  final match = _quantityRe.firstMatch(raw.trim());
  if (match == null) return null;
  var value = double.parse(match.group(1)!.replaceAll(',', '.'));
  var unit = match.group(2)?.toLowerCase().replaceAll('°', '').trim();
  if (unit == 'k') {
    // Pressure shorthand: "3K" = 3000. Unit stays unknown.
    value *= 1000;
    unit = null;
  }
  if (unit == "'") unit = 'ft';
  if (unit == 'mins') unit = 'min';
  return QuantityToken(value, unit);
}

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

final _monthNameDateRe = RegExp(
  r"^([0-9]{1,2})\s+([a-z]{3,9})\.?,?\s+'?([0-9]{2,4})$",
  caseSensitive: false,
);
final _numericDateRe = RegExp(
  r'^([0-9]{1,4})[/.\-]([0-9]{1,2})[/.\-]([0-9]{2,4})$',
);

DateTime? parseDateToken(String raw, {required bool preferDayFirst}) {
  final text = raw.trim();
  DateTime? result;

  final named = _monthNameDateRe.firstMatch(text);
  if (named != null) {
    final month = _months[named.group(2)!.toLowerCase().substring(0, 3)];
    if (month != null) {
      result = _buildDate(
        _expandYear(int.parse(named.group(3)!)),
        month,
        int.parse(named.group(1)!),
      );
    }
  }

  if (result == null) {
    final numeric = _numericDateRe.firstMatch(text);
    if (numeric != null) {
      final a = int.parse(numeric.group(1)!);
      final b = int.parse(numeric.group(2)!);
      final c = int.parse(numeric.group(3)!);
      if (a > 999) {
        // ISO: yyyy-mm-dd
        result = _buildDate(a, b, c);
      } else {
        final year = _expandYear(c);
        if (a > 12 && b <= 12) {
          result = _buildDate(year, b, a); // a must be the day
        } else if (b > 12 && a <= 12) {
          result = _buildDate(year, a, b); // b must be the day
        } else if (preferDayFirst) {
          result = _buildDate(year, b, a);
        } else {
          result = _buildDate(year, a, b);
        }
      }
    }
  }

  if (result == null) return null;
  if (result.isAfter(DateTime.now())) return null;
  return result;
}

int _expandYear(int y) {
  if (y >= 1000) return y;
  final currentTwoDigit = DateTime.now().year % 100;
  return y <= currentTwoDigit ? 2000 + y : 1900 + y;
}

DateTime? _buildDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final d = DateTime(year, month, day);
  // DateTime normalizes overflow (Feb 30 -> Mar 2); reject that.
  if (d.month != month || d.day != day) return null;
  return d;
}

final _durationColonRe = RegExp(r'^([0-9]{1,2}):([0-9]{2})$');
final _durationMinRe = RegExp(r'^([0-9]{1,3})\s*(?:min|mins)?$',
    caseSensitive: false);

Duration? parseDurationToken(String raw) {
  final text = raw.trim();
  final colon = _durationColonRe.firstMatch(text);
  if (colon != null) {
    return Duration(
      hours: int.parse(colon.group(1)!),
      minutes: int.parse(colon.group(2)!),
    );
  }
  final mins = _durationMinRe.firstMatch(text);
  if (mins != null) return Duration(minutes: int.parse(mins.group(1)!));
  return null;
}

final _clockRe = RegExp(
  r'^([0-9]{1,2}):([0-9]{2})\s*(a|p|am|pm)?\.?$',
  caseSensitive: false,
);

({int hour, int minute})? parseClockToken(String raw) {
  final match = _clockRe.firstMatch(raw.trim());
  if (match == null) return null;
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final suffix = match.group(3)?.toLowerCase();
  if (suffix != null && suffix.startsWith('p') && hour < 12) hour += 12;
  if (suffix != null && suffix.startsWith('a') && hour == 12) hour = 0;
  if (hour > 23 || minute > 59) return null;
  return (hour: hour, minute: minute);
}

final _o2Re = RegExp(
  r'^(?:ean\s*|nitrox\s*)?([0-9]{2,3})\s*%?$',
  caseSensitive: false,
);

double? parseO2Percent(String raw) {
  final text = raw.trim();
  final hasKeyword = RegExp(r'ean|nitrox|%', caseSensitive: false)
      .hasMatch(text);
  if (!hasKeyword) return null;
  final match = _o2Re.firstMatch(text);
  if (match == null) return null;
  final value = double.parse(match.group(1)!);
  if (value < 21 || value > 100) return null;
  return value;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/ocr_import/domain/services/value_normalizer_test.dart`
Expected: PASS (all groups).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/ocr_import test/features/ocr_import
git commit -m "feat(ocr-import): shorthand value normalizer"
```

---

### Task 3: Label table and geometric binder

**Files:**
- Create: `lib/features/ocr_import/domain/services/label_definitions.dart`
- Create: `lib/features/ocr_import/domain/services/label_binder.dart`
- Test: `test/features/ocr_import/domain/services/label_binder_test.dart`

**Interfaces:**
- Consumes: `OcrTextBlock` (Task 1).
- Produces:
  - `enum LogField { diveNumber, date, siteName, location, timeIn, timeOut, bottomTime, maxDepth, startPressure, endPressure, waterTemp, airTemp, visibility, weight, buddy, divemaster, notes, o2Percent, rating }`
  - `class LabelMatch { final LogField field; final OcrTextBlock block; }`
  - `List<LabelMatch> findLabels(List<OcrTextBlock> blocks)` — longest/most-specific label wins per block; a block matched as a label is matched to exactly one field.
  - `OcrTextBlock? bindValue(LabelMatch label, List<OcrTextBlock> blocks, {required Set<OcrTextBlock> labelBlocks})` — nearest non-label block right-of, below, or above the label within `3 * label.block.height` vertical / `12 * height` horizontal distance; right-of preferred, then below, then above.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/ocr_import/domain/services/label_binder_test.dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';
import 'package:submersion/features/ocr_import/domain/services/label_binder.dart';
import 'package:submersion/features/ocr_import/domain/services/label_definitions.dart';

OcrTextBlock block(String text, double l, double t, {double w = 80, double h = 12}) =>
    OcrTextBlock(text: text, boundingBox: Rect.fromLTWH(l, t, w, h));

void main() {
  group('findLabels', () {
    test('matches common template labels', () {
      final blocks = [
        block('Dive No.', 0, 0),
        block('Date', 200, 0),
        block('Location', 0, 30),
        block('Bottom Time', 100, 300),
      ];
      final labels = findLabels(blocks);
      expect(
        labels.map((l) => l.field),
        containsAll([
          LogField.diveNumber,
          LogField.date,
          LogField.siteName,
          LogField.bottomTime,
        ]),
      );
    });

    test('Certification No. never matches dive number', () {
      final labels = findLabels([block('Certification No.', 0, 900)]);
      expect(labels, isEmpty);
    });

    test('Bottom Time To Date never matches bottom time', () {
      final labels = findLabels([block('Bottom Time To Date', 0, 900)]);
      expect(labels, isEmpty);
    });
  });

  group('bindValue', () {
    test('binds value right of label', () {
      final label = block('Location', 0, 30);
      final value = block("O'ahu - pipe", 100, 30);
      final labels = findLabels([label]);
      final bound = bindValue(labels.single, [label, value],
          labelBlocks: {label});
      expect(bound?.text, "O'ahu - pipe");
    });

    test('binds value above label (PADI Z-diagram)', () {
      final label = block('DEPTH', 100, 220);
      final value = block('69', 105, 190, w: 30);
      final labels = findLabels([label]);
      final bound = bindValue(labels.single, [label, value],
          labelBlocks: {label});
      expect(bound?.text, '69');
    });

    test('binds value below label (boxed template)', () {
      final label = block('START (psi)', 100, 100);
      final value = block('2800', 110, 118, w: 40);
      final labels = findLabels([label]);
      final bound = bindValue(labels.single, [label, value],
          labelBlocks: {label});
      expect(bound?.text, '2800');
    });

    test('never binds another label as a value', () {
      final label = block('Time IN', 0, 100);
      final otherLabel = block('Time OUT', 120, 100);
      final labels = findLabels([label, otherLabel]);
      final timeIn = labels.firstWhere((l) => l.field == LogField.timeIn);
      final bound = bindValue(timeIn, [label, otherLabel],
          labelBlocks: {label, otherLabel});
      expect(bound, isNull);
    });

    test('ignores values beyond the distance threshold', () {
      final label = block('Weight', 0, 100);
      final farValue = block('11', 0, 600, w: 20);
      final labels = findLabels([label]);
      final bound = bindValue(labels.single, [label, farValue],
          labelBlocks: {label});
      expect(bound, isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/ocr_import/domain/services/label_binder_test.dart`
Expected: FAIL — imports unresolved.

- [ ] **Step 3: Implement label table and binder**

```dart
// lib/features/ocr_import/domain/services/label_definitions.dart
/// Printed label vocabulary observed on real logbook templates
/// (PADI blue pages, PADI training log, generic third-party pages).
library;

enum LogField {
  diveNumber,
  date,
  siteName,
  location,
  timeIn,
  timeOut,
  bottomTime,
  maxDepth,
  startPressure,
  endPressure,
  waterTemp,
  airTemp,
  visibility,
  weight,
  buddy,
  divemaster,
  notes,
  o2Percent,
  rating,
}

class LabelDefinition {
  final LogField field;
  final RegExp pattern;

  const LabelDefinition(this.field, this.pattern);
}

/// Negative guards: a block matching any of these is NOT a field label,
/// even if a positive pattern also matches. Checked first.
final List<RegExp> labelStopList = [
  RegExp(r'certification\s*(no|#)', caseSensitive: false),
  RegExp(r'bottom\s*time\s*to\s*date', caseSensitive: false),
  RegExp(r'cumulative', caseSensitive: false),
  RegExp(r'time\s*this\s*dive', caseSensitive: false),
  RegExp(r'planned\s*time', caseSensitive: false),
  RegExp(r'verification\s*signature', caseSensitive: false),
];

/// Positive label patterns. Anchored (^...$-ish with optional colon)
/// so instructional prose does not match.
final List<LabelDefinition> labelDefinitions = [
  LabelDefinition(
    LogField.diveNumber,
    RegExp(r'^dive\s*(no\.?|#|number)\s*:?$', caseSensitive: false),
  ),
  LabelDefinition(
    LogField.date,
    RegExp(r'^date\s*:?$', caseSensitive: false),
  ),
  LabelDefinition(
    LogField.siteName,
    RegExp(r'^(location|site|location/site\s*name|dive\s*site)\s*:?$',
        caseSensitive: false),
  ),
  LabelDefinition(
    LogField.location,
    RegExp(r'^country(/region)?\s*:?$', caseSensitive: false),
  ),
  LabelDefinition(
    LogField.timeIn,
    RegExp(r'^time\s*\(?in\)?\s*:?$', caseSensitive: false),
  ),
  LabelDefinition(
    LogField.timeOut,
    RegExp(r'^time\s*\(?out\)?\s*:?$', caseSensitive: false),
  ),
  LabelDefinition(
    LogField.bottomTime,
    RegExp(r'^(bottom\s*time|abt\+?|time)\s*:?=?$', caseSensitive: false),
  ),
  LabelDefinition(
    LogField.maxDepth,
    RegExp(r'^(max\.?\s*depth|depth|max)\s*:?$', caseSensitive: false),
  ),
  LabelDefinition(
    LogField.startPressure,
    RegExp(
        r'^(start(\s*\(?(psi|bar)\)?)?|air\s*in|start\s*psi/bar|bar/psi\s*start)\s*:?$',
        caseSensitive: false),
  ),
  LabelDefinition(
    LogField.endPressure,
    RegExp(
        r'^(end(\s*\(?(psi|bar)\)?)?|air\s*out|end\s*psi/bar|bar/psi\s*end)\s*:?$',
        caseSensitive: false),
  ),
  LabelDefinition(
    LogField.waterTemp,
    RegExp(r'^(bottom|water\s*temp\.?(\s*bottom)?)\s*:?$',
        caseSensitive: false),
  ),
  LabelDefinition(
    LogField.airTemp,
    RegExp(r'^air$', caseSensitive: false),
  ),
  LabelDefinition(
    LogField.visibility,
    RegExp(r'^visibility(\s*\(?(m/ft|ft|m)\)?)?\s*:?$', caseSensitive: false),
  ),
  LabelDefinition(
    LogField.weight,
    RegExp(r'^weight(\s*used)?\s*:?$', caseSensitive: false),
  ),
  LabelDefinition(
    LogField.buddy,
    RegExp(r'^buddy\s*:?$', caseSensitive: false),
  ),
  LabelDefinition(
    LogField.divemaster,
    RegExp(r'^(divemaster|instructor|dive\s*master)\s*:?$',
        caseSensitive: false),
  ),
  LabelDefinition(
    LogField.notes,
    RegExp(r'^(comments?|notes?|dive\s*notes(\s*&\s*observations)?)\s*:?$',
        caseSensitive: false),
  ),
  LabelDefinition(
    LogField.o2Percent,
    RegExp(r'^(nitrox|o2|ean)\s*%?\s*:?$', caseSensitive: false),
  ),
  LabelDefinition(
    LogField.rating,
    RegExp(r'^rating\s*:?$', caseSensitive: false),
  ),
];
```

```dart
// lib/features/ocr_import/domain/services/label_binder.dart
import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';
import 'package:submersion/features/ocr_import/domain/services/label_definitions.dart';

class LabelMatch {
  final LogField field;
  final OcrTextBlock block;

  const LabelMatch(this.field, this.block);
}

/// Find all label blocks. Stop-list guards run first so that
/// "Certification No." can never become a dive-number label.
List<LabelMatch> findLabels(List<OcrTextBlock> blocks) {
  final matches = <LabelMatch>[];
  for (final block in blocks) {
    final text = block.text.trim();
    if (labelStopList.any((re) => re.hasMatch(text))) continue;
    for (final def in labelDefinitions) {
      if (def.pattern.hasMatch(text)) {
        matches.add(LabelMatch(def.field, block));
        break; // first (most specific, list-ordered) definition wins
      }
    }
  }
  return matches;
}

/// Bind the value block for [label]: nearest non-label block right-of,
/// below, or above, within a threshold scaled to the label's text height.
OcrTextBlock? bindValue(
  LabelMatch label,
  List<OcrTextBlock> blocks, {
  required Set<OcrTextBlock> labelBlocks,
}) {
  final l = label.block;
  final h = l.height;
  OcrTextBlock? best;
  var bestScore = double.infinity;

  for (final candidate in blocks) {
    if (identical(candidate, l) || labelBlocks.contains(candidate)) continue;
    if (candidate.text.trim().isEmpty) continue;

    final dx = candidate.center.dx - l.center.dx;
    final dy = candidate.center.dy - l.center.dy;

    double score;
    if (dx > 0 && dy.abs() < 1.5 * h && dx < 12 * h) {
      score = dx; // right-of: strongly preferred
    } else if (dy > 0 && dy < 3 * h && dx.abs() < 6 * h) {
      score = 2 * h + dy + dx.abs(); // below
    } else if (dy < 0 && dy > -3 * h && dx.abs() < 6 * h) {
      score = 3 * h - dy + dx.abs(); // above (PADI Z-diagram)
    } else {
      continue;
    }

    if (score < bestScore) {
      bestScore = score;
      best = candidate;
    }
  }
  return best;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/ocr_import/domain/services/label_binder_test.dart`
Expected: PASS. If the "above" test fails on the score ordering, adjust thresholds — the invariant that matters: right-of beats below beats above when several candidates qualify.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/ocr_import test/features/ocr_import
git commit -m "feat(ocr-import): label table and geometric value binder"
```

---

### Task 4: Page-level unit context

**Files:**
- Create: `lib/features/ocr_import/domain/services/unit_context.dart`
- Test: `test/features/ocr_import/domain/services/unit_context_test.dart`

**Interfaces:**
- Consumes: `OcrTextBlock` (Task 1), `parseQuantity` (Task 2).
- Produces:
  - `class UnitDefaults { final bool depthFeet; final bool pressurePsi; final bool tempFahrenheit; final bool weightLbs; const UnitDefaults({...all required}); }` — built by callers from `AppSettings` (`DepthUnit.feet` -> `depthFeet: true`, etc.).
  - `UnitDefaults inferPageUnits(List<OcrTextBlock> blocks, UnitDefaults fallback)` — explicit tokens anywhere on the page override the fallback per quantity kind: any `ft` token => `depthFeet: true`, any `m` depth token => false; `psi`/`bar`, `f`/`c`, `lbs`/`kg` likewise. Printed template hints count (PADI prints `bar/psi` — ambiguous, ignored; `5m/15ft stop` — ambiguous, ignored: only unambiguous single-unit tokens vote). Majority of votes wins per kind; tie or no votes => fallback.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/ocr_import/domain/services/unit_context_test.dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';
import 'package:submersion/features/ocr_import/domain/services/unit_context.dart';

OcrTextBlock block(String text) => OcrTextBlock(
      text: text,
      boundingBox: const Rect.fromLTWH(0, 0, 50, 10),
    );

const metric = UnitDefaults(
  depthFeet: false,
  pressurePsi: false,
  tempFahrenheit: false,
  weightLbs: false,
);

void main() {
  test('explicit ft token flips depth to feet', () {
    final units = inferPageUnits([block('60 ft'), block('69')], metric);
    expect(units.depthFeet, isTrue);
  });

  test('explicit imperial context flips temperature too', () {
    // A psi page with bare temps is a US log: 73 means Fahrenheit.
    final units = inferPageUnits([block('3000 psi')], metric);
    expect(units.pressurePsi, isTrue);
    expect(units.tempFahrenheit, isTrue);
  });

  test('metric tokens keep metric', () {
    final units = inferPageUnits(
      [block('11.1m'), block('200 bar')],
      const UnitDefaults(
        depthFeet: true,
        pressurePsi: true,
        tempFahrenheit: true,
        weightLbs: true,
      ),
    );
    expect(units.depthFeet, isFalse);
    expect(units.pressurePsi, isFalse);
  });

  test('ambiguous printed hints do not vote', () {
    final units = inferPageUnits(
      [block('5m/15ft stop'), block('bar/psi')],
      metric,
    );
    expect(units.depthFeet, isFalse);
    expect(units.pressurePsi, isFalse);
  });

  test('no tokens falls back to settings', () {
    final units = inferPageUnits([block('69'), block('32')], metric);
    expect(units.depthFeet, isFalse);
    expect(units.tempFahrenheit, isFalse);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/ocr_import/domain/services/unit_context_test.dart`
Expected: FAIL — imports unresolved.

- [ ] **Step 3: Implement unit inference**

```dart
// lib/features/ocr_import/domain/services/unit_context.dart
import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';
import 'package:submersion/features/ocr_import/domain/services/value_normalizer.dart';

class UnitDefaults {
  final bool depthFeet;
  final bool pressurePsi;
  final bool tempFahrenheit;
  final bool weightLbs;

  const UnitDefaults({
    required this.depthFeet,
    required this.pressurePsi,
    required this.tempFahrenheit,
    required this.weightLbs,
  });
}

/// Explicit unit tokens on the page vote for the page's unit system.
/// One imperial signal (ft or psi) makes the whole page imperial-leaning:
/// paper logs are written in one system. Blocks containing BOTH systems
/// ("5m/15ft stop", "bar/psi" template hints) are ambiguous and skipped.
UnitDefaults inferPageUnits(List<OcrTextBlock> blocks, UnitDefaults fallback) {
  var imperialVotes = 0;
  var metricVotes = 0;

  for (final b in blocks) {
    final text = b.text.toLowerCase();
    final hasImperial = RegExp(r'\b(ft|psi|°?f|lbs)\b').hasMatch(text);
    final hasMetric = RegExp(r'\b([0-9.]+\s*m|bar|°?c|kg)\b').hasMatch(text);
    if (hasImperial && hasMetric) continue; // template hint, ambiguous
    // Only count tokens attached to a number (real values, not prose).
    final q = parseQuantity(b.text);
    if (q?.unit == null) continue;
    switch (q!.unit) {
      case 'ft' || 'psi' || 'f' || 'lbs':
        imperialVotes++;
      case 'm' || 'bar' || 'c' || 'kg':
        metricVotes++;
    }
  }

  if (imperialVotes == metricVotes) return fallback;
  final imperial = imperialVotes > metricVotes;
  return UnitDefaults(
    depthFeet: imperial,
    pressurePsi: imperial,
    tempFahrenheit: imperial,
    weightLbs: imperial,
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/ocr_import/domain/services/unit_context_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/ocr_import test/features/ocr_import
git commit -m "feat(ocr-import): page-level unit inference"
```

---

### Task 5: LogbookParser

**Files:**
- Create: `lib/features/ocr_import/domain/services/logbook_parser.dart`
- Test: `test/features/ocr_import/domain/services/logbook_parser_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 1-4 (exact names as declared there).
- Produces: `class LogbookParser { ParsedDiveFields parse(OcrResult ocr, {required UnitDefaults fallbackUnits, required bool preferDayFirst}); }` — the single entry point the scan flow (Task 15) calls.

**Behavior contract (implement exactly):**
1. `findLabels` over all blocks; build `labelBlocks` set.
2. For each label, `bindValue`, then normalize by field kind (quantity fields via `parseQuantity`, date via `parseDateToken`, times via `parseClockToken`, bottom time via `parseDurationToken`, O2 via `parseO2Percent`). Free-text fields (siteName, location, buddy, divemaster) take the bound block's raw text; reject bound free-text that parses as a bare number.
3. Notes: all blocks whose top edge is below the notes label's top edge, excluding label blocks and blocks already bound, joined with spaces in top-to-bottom, left-to-right order.
4. Pattern pass for fields still null: scan unbound, non-label blocks with `parseDateToken` (date), `parseO2Percent` (o2), and `parseQuantity` where the unit is self-describing (`m`/`ft` => maxDepth if null, `bar`/`psi` largest value => startPressure / smallest => endPressure when both null, `min` => bottom time). Label-bound results always win (pattern pass only fills nulls).
5. Unit resolution: `inferPageUnits` once per page; explicit token on the individual value wins over page inference. Convert to metric: ft/3.28084, psi/14.5038, F `(f-32)*5/9`, lbs*0.453592.
6. Time merge: date + timeIn => `date` with time and `hasTimeOfDay: true`. Bottom time missing but timeIn and timeOut present => duration from the pair (add 24h if out < in).
7. Sanity gates (drop to null, silently): depth 0-350 m, duration 1-600 min, water temp -2-40 C, air temp -40-50 C, pressures 1-400 bar, weight 0-40 kg, dive number 1-20000, rating 1-5. Start pressure <= end pressure => drop both.
8. Unmapped extras: bound-but-unmappable fields (visibility, weight when the form cannot take it — weight IS mapped, visibility is not; also buddy, divemaster, location) go into `unmapped` keyed by a stable English key: `'visibility'`, `'buddy'`, `'divemaster'`. siteName and locationText stay first-class fields (the flow decides what to do with them).

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/ocr_import/domain/services/logbook_parser_test.dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';
import 'package:submersion/features/ocr_import/domain/services/logbook_parser.dart';
import 'package:submersion/features/ocr_import/domain/services/unit_context.dart';

OcrTextBlock block(String text, double l, double t,
        {double w = 80, double h = 12}) =>
    OcrTextBlock(text: text, boundingBox: Rect.fromLTWH(l, t, w, h));

const metric = UnitDefaults(
  depthFeet: false,
  pressurePsi: false,
  tempFahrenheit: false,
  weightLbs: false,
);

OcrResult page(List<OcrTextBlock> blocks) =>
    OcrResult(blocks: blocks, imageSize: const Size(1000, 1400));

void main() {
  final parser = LogbookParser();

  test('label-bound metric page parses to metric fields', () {
    final result = parser.parse(
      page([
        block('Date', 0, 0),
        block('05/14/2023', 90, 0),
        block('Location', 0, 30),
        block('Pinnacle, Sodwana Bay', 90, 30, w: 200),
        block('DEPTH', 40, 220),
        block('11.1m', 45, 195, w: 40),
        block('TIME', 150, 220),
        block('45min', 150, 195, w: 40),
        block('Start psi/bar', 0, 300, w: 90),
        block('200 bar', 100, 300, w: 50),
        block('End psi/bar', 0, 330, w: 90),
        block('70 bar', 100, 330, w: 50),
      ]),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    expect(result.date, DateTime(2023, 5, 14));
    expect(result.siteName, 'Pinnacle, Sodwana Bay');
    expect(result.maxDepthMeters, closeTo(11.1, 0.001));
    expect(result.durationMinutes, 45);
    expect(result.startPressureBar, 200);
    expect(result.endPressureBar, 70);
  });

  test('imperial page converts to metric storage', () {
    final result = parser.parse(
      page([
        block('DEPTH', 40, 220),
        block('69', 45, 195, w: 30),
        block('Visibility', 0, 400),
        block('60 ft', 100, 400, w: 40),
        block('bar/psi START', 200, 100, w: 90),
        block('3K', 200, 120, w: 30),
      ]),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    // 60 ft visibility makes the page imperial: 69 is feet, 3K is psi.
    expect(result.maxDepthMeters, closeTo(21.03, 0.05));
    expect(result.startPressureBar, closeTo(206.8, 0.5));
    expect(result.unmapped['visibility'], '60 ft');
  });

  test('duration derived from time in and out', () {
    final result = parser.parse(
      page([
        block('Time IN', 0, 100),
        block('10:00A', 0, 120, w: 50),
        block('Time OUT', 120, 100),
        block('10:32', 120, 120, w: 50),
        block('Date', 0, 0),
        block("6 Feb '06", 90, 0, w: 70),
      ]),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    expect(result.durationMinutes, 32);
    expect(result.hasTimeOfDay, isTrue);
    expect(result.date, DateTime(2006, 2, 6, 10, 0));
  });

  test('implausible depth is silently dropped', () {
    final result = parser.parse(
      page([
        block('DEPTH', 40, 220),
        block('1800', 45, 195, w: 40),
      ]),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    expect(result.maxDepthMeters, isNull);
  });

  test('notes collect handwriting below the comments label', () {
    final result = parser.parse(
      page([
        block('Comments', 0, 700),
        block('WE SAW', 0, 750, w: 120),
        block('A HUMPBACK WHALE', 0, 790, w: 300),
      ]),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    expect(result.notes, 'WE SAW A HUMPBACK WHALE');
  });

  test('empty page yields isEmpty result', () {
    final result = parser.parse(
      page([]),
      fallbackUnits: metric,
      preferDayFirst: false,
    );
    expect(result.isEmpty, isTrue);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/ocr_import/domain/services/logbook_parser_test.dart`
Expected: FAIL — `LogbookParser` unresolved.

- [ ] **Step 3: Implement LogbookParser**

Implement `lib/features/ocr_import/domain/services/logbook_parser.dart` as a single class following the numbered behavior contract above. Skeleton with all conversion constants and the field dispatch — flesh out the private helpers, keeping each under ~40 lines:

```dart
// lib/features/ocr_import/domain/services/logbook_parser.dart
import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';
import 'package:submersion/features/ocr_import/domain/models/parsed_dive_fields.dart';
import 'package:submersion/features/ocr_import/domain/services/label_binder.dart';
import 'package:submersion/features/ocr_import/domain/services/label_definitions.dart';
import 'package:submersion/features/ocr_import/domain/services/unit_context.dart';
import 'package:submersion/features/ocr_import/domain/services/value_normalizer.dart';

class LogbookParser {
  static const _ftToM = 1 / 3.28084;
  static const _psiToBar = 1 / 14.5038;
  static const _lbsToKg = 0.453592;

  ParsedDiveFields parse(
    OcrResult ocr, {
    required UnitDefaults fallbackUnits,
    required bool preferDayFirst,
  }) {
    if (ocr.isEmpty) return const ParsedDiveFields();

    final units = inferPageUnits(ocr.blocks, fallbackUnits);
    final labels = findLabels(ocr.blocks);
    final labelBlocks = {for (final l in labels) l.block};
    final bound = <LogField, OcrTextBlock>{};
    for (final label in labels) {
      // Notes handled separately (region, not single block).
      if (label.field == LogField.notes) continue;
      final value = bindValue(label, ocr.blocks, labelBlocks: labelBlocks);
      if (value != null && !bound.containsValue(value)) {
        bound.putIfAbsent(label.field, () => value);
      }
    }

    final quantities = _extractQuantities(bound, units);
    final dateTimes = _extractDateAndTimes(bound, preferDayFirst);
    final freeText = _extractFreeText(bound);
    final notes = _extractNotes(
      labels,
      ocr.blocks,
      labelBlocks,
      bound.values.toSet(),
    );
    final filled = _patternPass(
      quantities,
      dateTimes,
      ocr.blocks,
      labelBlocks,
      bound.values.toSet(),
      units,
    );
    return _applySanityGates(filled, freeText, notes);
  }
}
```

Private helper contracts (each is short; the behavior contract above plus Task 5's and Task 6's tests are the full specification):

- `_extractQuantities(Map<LogField, OcrTextBlock> bound, UnitDefaults units)`: for maxDepth/startPressure/endPressure/waterTemp/airTemp/weight, run `parseQuantity` on the bound text; explicit unit token on the value wins, bare numbers use `units`. Convert with `_ftToM`, `_psiToBar`, `(f - 32) * 5 / 9`, `_lbsToKg`. Also diveNumber (`int.tryParse`), rating (`int.tryParse`), o2 (`parseO2Percent`), bottomTime (`parseDurationToken`).
- `_extractDateAndTimes(bound, preferDayFirst)`: date via `parseDateToken`; timeIn/timeOut via `parseClockToken`; merge timeIn into the date (`hasTimeOfDay`); derive duration from in/out when bottomTime is null (+24 h when out < in).
- `_extractFreeText(bound)`: siteName, location, buddy, divemaster raw text; reject values that `parseQuantity` fully consumes (a number is not a site name). buddy/divemaster/visibility raw text goes to `unmapped`.
- `_extractNotes(labels, blocks, labelBlocks, boundValues)`: blocks below the notes label's top edge, excluding labels and bound values, sorted top-to-bottom then left-to-right, joined with spaces.
- `_patternPass(...)`: fill still-null fields only, from unbound non-label blocks: `parseDateToken` for date, `parseO2Percent` for o2, `parseQuantity` with self-describing units (`m`/`ft` -> maxDepth; `bar`/`psi` -> larger value startPressure, smaller endPressure, only when both null; `min` -> bottomTime).
- `_applySanityGates(...)`: the numbered gate ranges; assemble the final `ParsedDiveFields`.

Keep every heuristic constant (thresholds, gate ranges) as named `static const`s at the top of the class.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/ocr_import/domain/services/logbook_parser_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/ocr_import test/features/ocr_import
git commit -m "feat(ocr-import): layout-aware logbook parser"
```

---

### Task 6: Sample-page fixture suite

**Files:**
- Create: `test/features/ocr_import/fixtures/logbook_fixtures.dart`
- Test: `test/features/ocr_import/domain/services/logbook_parser_fixtures_test.dart`

**Interfaces:**
- Consumes: `LogbookParser.parse` (Task 5), `OcrTextBlock`/`OcrResult` (Task 1).
- Produces: named fixture builders other tasks may reuse: `OcrResult padiHandwrittenImperial()`, `OcrResult padiTrainingMetric()`, `OcrResult genericThirdParty()`, `OcrResult typewriterBoxed()`, `OcrResult certificationTrap()`.

Each fixture reproduces the geometry of one of the five real sample pages from the spec (see spec "Reference: sample pages"). Build them with the same `block(text, l, t, {w, h})` helper as Task 5's test, exported from `logbook_fixtures.dart`. Content per fixture:

1. **padiHandwrittenImperial** (sample 1): `Dive No.`+`66`, `Date`+`6 Feb '06`, `Location`+`O'ahu - pipe`, `Time IN`+`10:00A`, `Time OUT`+`10:32`, `bar/psi START`+`3K`, `bar/psi END`+`1600`, `Weight`+`6`, `Bottom`+`73` (temperature area), `Visibility`+`60 ft`, `DEPTH` with `69` ABOVE it, `BOTTOM TIME` with `32` ABOVE it, `Comments` label with `HOLY`/`WE SAW`/`A HUMPBACK WHALE` blocks below, plus noise blocks: `Certification No.`, `RNT`, `ABT`, `TBT`, `MULTI-LEVEL DIVE`, `For use with The Wheel only.`, `5m/15ft stop`.
   Expected: diveNumber 66; date 2006-02-06 10:00 with hasTimeOfDay; duration 32; maxDepth ~21.0 m (69 ft); startPressure ~206.8 bar (3000 psi); endPressure ~110.3 bar (1600 psi); waterTemp ~22.8 C (73 F); weight ~2.7 kg (6 lbs); siteName `O'ahu - pipe`; notes contains `HUMPBACK WHALE`; unmapped visibility `60 ft`.
2. **padiTrainingMetric** (sample 2): `Date`+`05/14/2023`, `Visibility`+`20`, `Location`+`Pinnacle, Sodwana Bay`, `Air`+`24`, `Bottom`+`25`, `Weight`+`11`, `DEPTH` with `11.1m` above, `TIME` with `45min` above, `Start psi/bar`+`200 bar`, `End psi/bar`+`70 bar`, `Comments`+`First dive in the ocean!`, noise: `Skills Completed`, `Predive safety check`, `Certification No`+`616757`, `Verification Signature`.
   Expected: date 2023-05-14 (no time); maxDepth 11.1; duration 45; start 200 / end 70 bar; airTemp 24; waterTemp 25; siteName `Pinnacle, Sodwana Bay`; notes `First dive in the ocean!`; diveNumber null (blank on page; `616757` must NOT leak into it).
3. **genericThirdParty** (sample 3 layout, values invented): `Dive #`+`102`, `Date`+`03/07/2024`, `Location`+`Blue Corner`, `Max`+`28m` (right-of), `Start`+`210 bar` below-label, `End`+`60 bar`, `Nitrox`+`32 %`.
   Expected: diveNumber 102; maxDepth 28; o2Percent 32; pressures 210/60.
4. **typewriterBoxed** (sample 4 layout, values invented): `Location/Site Name:`+`Chac Mool Cenote` right-of, `Country/Region:`+`Mexico`, `Water Temp Bottom :`+`25`, `Bottom Time :`+`51 min`, `Max Depth` with `12` below, `Time In`+`9:40`, `Time Out`+`10:31`.
   Expected: siteName `Chac Mool Cenote`; locationText `Mexico`; waterTemp 25; duration 51; maxDepth 12.
5. **certificationTrap**: ONLY `Certification No.`+`616757` and `Bottom Time To Date`+`48:30` and `Cumulative Time`+`52:10`.
   Expected: `isEmpty` true.

- [ ] **Step 1: Write fixtures and the failing test file** — one `test()` per fixture asserting every expected value listed above (use `closeTo` for converted quantities).

- [ ] **Step 2: Run to see which pass**

Run: `flutter test test/features/ocr_import/domain/services/logbook_parser_fixtures_test.dart`
Expected: some failures are likely — fixtures exercise combinations Task 5's minimal tests did not.

- [ ] **Step 3: Fix the parser until all fixtures pass.** Rules: fix by generalizing heuristics (adjust label patterns, thresholds, pattern-pass rules), never by special-casing a fixture's exact text. If a fixture expectation turns out wrong (transcription error), fix the fixture and say so in the commit message.

- [ ] **Step 4: Re-run Task 5 tests too**

Run: `flutter test test/features/ocr_import/`
Expected: ALL ocr_import tests pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add test/features/ocr_import lib/features/ocr_import
git commit -m "test(ocr-import): sample-page fixture suite for the parser"
```

---

### Task 7: DivePrefill and DiveEditPage prefill support

**Files:**
- Create: `lib/features/dive_log/domain/entities/dive_prefill.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (constructor at line 102, create-mode branch of `initState` around line 271-299)
- Modify: `lib/core/router/app_router.dart` (route `'newDive'` at line ~273)
- Test: `test/features/dive_log/presentation/pages/dive_edit_prefill_test.dart`

**Interfaces:**
- Consumes: `DiveSite`, `DiveTank`, `GasMix` (existing dive_log entities; `GasMix.o2` is a PERCENTAGE 0-100).
- Produces:

```dart
// lib/features/dive_log/domain/entities/dive_prefill.dart
import 'package:submersion/features/dive_log/domain/entities/dive_site.dart';

/// Initial values for DiveEditPage create mode. All metric.
/// Built by the OCR scan flow; deliberately independent of ocr_import
/// so dive_log never imports that feature.
class DivePrefill {
  final int? diveNumber;
  final DateTime? dateTime;
  final bool hasTimeOfDay;
  final int? durationMinutes;
  final double? maxDepthMeters;
  final double? waterTempCelsius;
  final double? airTempCelsius;
  final int? rating;
  final String? notes;
  final DiveSite? site; // pre-resolved existing site, or null
  final double? startPressureBar;
  final double? endPressureBar;
  final double? o2Percent;
  final double? cylinderVolumeLiters;
  final double? weightKg;
  final String? photoPath; // source logbook photo to attach after save
  final String? importSource; // e.g. 'ocr'

  const DivePrefill({
    this.diveNumber,
    this.dateTime,
    this.hasTimeOfDay = false,
    this.durationMinutes,
    this.maxDepthMeters,
    this.waterTempCelsius,
    this.airTempCelsius,
    this.rating,
    this.notes,
    this.site,
    this.startPressureBar,
    this.endPressureBar,
    this.o2Percent,
    this.cylinderVolumeLiters,
    this.weightKg,
    this.photoPath,
    this.importSource,
  });
}
```

  (If `DiveSite` lives in a different file, check `dive.dart` imports and match.)
- `DiveEditPage` gains `final DivePrefill? prefill;` (`this.prefill` in the constructor). Later tasks construct `DiveEditPage(prefill: ...)` via the `newDive` route's `state.extra`.

- [ ] **Step 1: Write the failing widget test**

Copy the test harness (ProviderScope overrides, pumping pattern) from the existing `test/features/dive_log/presentation/pages/dive_edit_page_test.dart` — reuse its setup verbatim; only the pumped widget and assertions differ:

```dart
// test/features/dive_log/presentation/pages/dive_edit_prefill_test.dart
// (imports and setUp copied from dive_edit_page_test.dart)

testWidgets('prefill populates create-mode fields', (tester) async {
  final prefill = DivePrefill(
    diveNumber: 66,
    dateTime: DateTime(2006, 2, 6, 10, 0),
    hasTimeOfDay: true,
    durationMinutes: 32,
    maxDepthMeters: 21.0,
    waterTempCelsius: 22.8,
    notes: 'WE SAW A HUMPBACK WHALE',
    rating: 5,
    startPressureBar: 206.8,
    endPressureBar: 110.3,
    importSource: 'ocr',
  );
  await pumpEditPage(tester, prefill: prefill); // helper mirroring existing tests
  expect(find.widgetWithText(TextField, '66'), findsOneWidget);
  expect(find.widgetWithText(TextField, '32'), findsOneWidget);
  expect(find.text('WE SAW A HUMPBACK WHALE'), findsOneWidget);
  // Depth shown in the active display unit (metric default in tests): 21.0
  expect(find.widgetWithText(TextField, '21.0'), findsOneWidget);
});

testWidgets('no prefill leaves create mode unchanged', (tester) async {
  await pumpEditPage(tester);
  expect(find.text('WE SAW A HUMPBACK WHALE'), findsNothing);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_prefill_test.dart`
Expected: FAIL — `prefill` parameter does not exist.

- [ ] **Step 3: Implement**

1. Create `dive_prefill.dart` exactly as in Interfaces (write out all constructor params).
2. `DiveEditPage`: add `final DivePrefill? prefill;` + constructor param.
3. In `initState`'s create branch (the `else` where `_suggestNextDiveNumber()` runs, around line 285), after existing defaults, call `_applyPrefill()`:

```dart
void _applyPrefill() {
  final p = widget.prefill;
  if (p == null) return;
  final units = UnitFormatter(ref.read(settingsProvider));
  if (p.diveNumber != null) {
    _diveNumberController.text = p.diveNumber.toString();
  }
  if (p.dateTime != null) {
    _entryDate = p.dateTime!;
    if (p.hasTimeOfDay) {
      _entryTime = TimeOfDay.fromDateTime(p.dateTime!);
    }
  }
  if (p.durationMinutes != null) {
    _durationController.text = p.durationMinutes.toString();
  }
  if (p.maxDepthMeters != null) {
    _maxDepthController.text =
        units.convertDepth(p.maxDepthMeters!).toStringAsFixed(1);
  }
  if (p.waterTempCelsius != null) {
    _waterTempController.text =
        units.convertTemperature(p.waterTempCelsius!).toStringAsFixed(0);
  }
  if (p.airTempCelsius != null) {
    _airTempController.text =
        units.convertTemperature(p.airTempCelsius!).toStringAsFixed(0);
  }
  if (p.notes != null) _notesController.text = p.notes!;
  if (p.rating != null) _rating = p.rating!;
  if (p.site != null) _selectedSite = p.site;
  if (p.startPressureBar != null ||
      p.endPressureBar != null ||
      p.o2Percent != null ||
      p.cylinderVolumeLiters != null) {
    final base = _tanks.isNotEmpty ? _tanks.first : null;
    _tanks = [
      DiveTank(
        id: base?.id ?? const Uuid().v4(),
        volume: p.cylinderVolumeLiters ?? base?.volume,
        startPressure: p.startPressureBar ?? base?.startPressure,
        endPressure: p.endPressureBar ?? base?.endPressure,
        gasMix: p.o2Percent != null
            ? GasMix(o2: p.o2Percent!)
            : (base?.gasMix ?? const GasMix()),
      ),
      ..._tanks.skip(1),
    ];
  }
}
```

   Adapt field names to what you find in the file: `_entryTime`'s exact type (`TimeOfDay`) and the exact default-tank construction at line 278 — mirror it. Weight: search the file for the weight controller (`grep -n weight lib/features/dive_log/presentation/pages/dive_edit_page.dart`); if a single weight text controller exists, prefill it via `units` conversion; if weight is structured (multiple weights), skip it and note that in the task's commit message.
4. On save in create mode, if `widget.prefill?.importSource != null`, set `importSource` on the created `Dive` (find where the `Dive` is assembled from controllers, ~line 848-889, and pass `importSource: widget.prefill?.importSource`).
5. Router: change the `newDive` route builder to pass extra:

```dart
GoRoute(
  path: 'new',
  name: 'newDive',
  builder: (context, state) =>
      DiveEditPage(prefill: state.extra as DivePrefill?),
),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_prefill_test.dart`
Then: `flutter test test/features/dive_log/presentation/pages/dive_edit_page_test.dart` (regression: create mode unchanged when prefill is null).
Expected: PASS both.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log lib/core/router test/features/dive_log
git commit -m "feat(dive-log): DivePrefill support in DiveEditPage create mode"
```

---

### Task 8: Site resolver

**Files:**
- Create: `lib/features/ocr_import/domain/services/site_resolver.dart`
- Test: `test/features/ocr_import/domain/services/site_resolver_test.dart`

**Interfaces:**
- Consumes: `normalize`, `diceCoefficient` from `lib/core/text/fuzzy_match.dart` (existing); `DiveSite` entity.
- Produces: `DiveSite? resolveSiteByName(String extractedName, List<DiveSite> candidates, {double threshold = 0.75})` — pure function; best Dice-coefficient match over normalized names at/above threshold, else null. The scan flow supplies candidates from the existing sites repository.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/ocr_import/domain/services/site_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/ocr_import/domain/services/site_resolver.dart';

DiveSite site(String id, String name) => DiveSite(id: id, name: name);

void main() {
  final sites = [
    site('1', 'Blue Corner'),
    site('2', 'Pinnacle, Sodwana Bay'),
    site('3', 'Molokini Crater'),
  ];

  test('exact name matches', () {
    expect(resolveSiteByName('Blue Corner', sites)?.id, '1');
  });

  test('OCR noise still matches above threshold', () {
    expect(resolveSiteByName('Pinnacle Sodwana Bay', sites)?.id, '2');
  });

  test('unrelated name returns null', () {
    expect(resolveSiteByName("O'ahu - pipe", sites), isNull);
  });

  test('empty input returns null', () {
    expect(resolveSiteByName('', sites), isNull);
    expect(resolveSiteByName('Blue Corner', const []), isNull);
  });
}
```

(If the `DiveSite` constructor requires more fields, add the minimal required ones in the `site` helper — check `lib/features/dive_sites/domain/entities/dive_site.dart`.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/ocr_import/domain/services/site_resolver_test.dart`
Expected: FAIL — unresolved import.

- [ ] **Step 3: Implement**

```dart
// lib/features/ocr_import/domain/services/site_resolver.dart
import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Fuzzy-match an OCR-extracted site name against existing sites.
/// Returns the best match at/above [threshold], else null — the caller
/// then routes the raw name to the notes appendix instead.
DiveSite? resolveSiteByName(
  String extractedName,
  List<DiveSite> candidates, {
  double threshold = 0.75,
}) {
  final query = normalize(extractedName);
  if (query.isEmpty) return null;
  DiveSite? best;
  var bestScore = 0.0;
  for (final site in candidates) {
    final score = diceCoefficient(query, normalize(site.name));
    if (score > bestScore) {
      bestScore = score;
      best = site;
    }
  }
  return bestScore >= threshold ? best : null;
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/ocr_import/domain/services/site_resolver_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/ocr_import test/features/ocr_import
git commit -m "feat(ocr-import): fuzzy site name resolver"
```

---

### Task 9: Local-file photo import for scanned pages

**Files:**
- Modify: `lib/features/media/data/services/media_import_service.dart`
- Test: `test/features/media/data/services/media_import_local_file_test.dart`

**Interfaces:**
- Consumes: `MediaItem` (`sourceType: MediaSourceType.localFile`, `filePath`, `mediaType: MediaType.photo`), `MediaRepository.createMedia(MediaItem)` (`lib/features/media/data/repositories/media_repository.dart:96`), `path_provider`.
- Produces: on `MediaImportService`:

```dart
/// Copies [sourceFile] into the app documents directory
/// (subdir 'scanned_logs/') and creates a localFile media row
/// linked to [diveId]. Returns the created MediaItem.
Future<MediaItem> importLocalFileForDive({
  required File sourceFile,
  required String diveId,
  DateTime? takenAt,
})
```

- [ ] **Step 1: Write the failing test.** Look at how existing `media_import_service` tests construct the service (check `test/features/media/` for the pattern — repository fake vs. in-memory DB) and reuse that harness. Assertions:

```dart
test('copies file into scanned_logs and creates localFile media row',
    () async {
  final tmp = await Directory.systemTemp.createTemp('ocr_test');
  final source = File('${tmp.path}/page.jpg')
    ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG magic bytes
  final item = await service.importLocalFileForDive(
    sourceFile: source,
    diveId: 'dive-1',
  );
  expect(item.sourceType, MediaSourceType.localFile);
  expect(item.diveId, 'dive-1');
  expect(item.mediaType, MediaType.photo);
  expect(item.filePath, contains('scanned_logs'));
  expect(File(item.filePath!).existsSync(), isTrue);
  // repository received the row (fake captures createMedia calls)
});
```

Use `PathProviderPlatform` test override (see `path_provider_platform_interface` `setMockInitialValues` pattern, or an injected documents-directory getter if the service already has one — prefer whichever the existing media tests use).

- [ ] **Step 2: Run to verify failure** — method does not exist.

- [ ] **Step 3: Implement** in `media_import_service.dart`, mirroring `_createMediaItemFromAsset` (line ~125) for field conventions:

```dart
Future<MediaItem> importLocalFileForDive({
  required File sourceFile,
  required String diveId,
  DateTime? takenAt,
}) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'scanned_logs'));
  await dir.create(recursive: true);
  final id = const Uuid().v4();
  final ext = p.extension(sourceFile.path).isEmpty
      ? '.jpg'
      : p.extension(sourceFile.path);
  final dest = await sourceFile.copy(p.join(dir.path, '$id$ext'));
  final item = MediaItem(
    id: id,
    diveId: diveId,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    filePath: dest.path,
    originalFilename: p.basename(sourceFile.path),
    takenAt: takenAt ?? DateTime.now(),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
  return _mediaRepository.createMedia(item);
}
```

Match the service's existing imports/uuid usage; if `MediaItem` requires more fields, copy defaults from `_createMediaItemFromAsset`.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/media/data/services/media_import_local_file_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/media test/features/media
git commit -m "feat(media): import a local image file as dive media"
```

---

### Task 10: Android engine (ML Kit)

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/features/ocr_import/data/engines/mlkit_ocr_engine.dart`
- Test: `test/features/ocr_import/data/engines/mlkit_ocr_engine_test.dart`

**Interfaces:**
- Consumes: `OcrEngine`, `OcrResult`, `OcrTextBlock` (Task 1).
- Produces: `class MlkitOcrEngine implements OcrEngine` and a pure mapping function `OcrResult mapRecognizedText(RecognizedText recognized, Size imageSize)` (mapping is what gets unit-tested).

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add google_mlkit_text_recognition`
Then move the added line in `pubspec.yaml` into a new commented section following the file's existing grouping style:

```yaml
  # OCR (paper logbook import)
  # Android on-device text recognition; Apple/Windows use packages/submersion_ocr.
  google_mlkit_text_recognition: <caret version pub chose>
```

- [ ] **Step 2: Write the failing mapping test**

`RecognizedText.fromJson` is the package's own platform-deserialization entry point — use it to build test input without a device:

```dart
// test/features/ocr_import/data/engines/mlkit_ocr_engine_test.dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:submersion/features/ocr_import/data/engines/mlkit_ocr_engine.dart';

void main() {
  test('maps ML Kit lines to OcrTextBlocks with pixel rects', () {
    final recognized = RecognizedText.fromJson({
      'text': 'DEPTH 69',
      'blocks': [
        {
          'text': 'DEPTH 69',
          'rect': {'left': 10.0, 'top': 20.0, 'right': 110.0, 'bottom': 40.0},
          'recognizedLanguages': ['en'],
          'points': [],
          'lines': [
            {
              'text': 'DEPTH',
              'rect': {'left': 10.0, 'top': 20.0, 'right': 60.0, 'bottom': 32.0},
              'recognizedLanguages': ['en'],
              'points': [],
              'confidence': 0.9,
              'angle': 0.0,
              'elements': [],
            },
            {
              'text': '69',
              'rect': {'left': 70.0, 'top': 20.0, 'right': 90.0, 'bottom': 32.0},
              'recognizedLanguages': ['en'],
              'points': [],
              'confidence': 0.8,
              'angle': 0.0,
              'elements': [],
            },
          ],
        },
      ],
    });
    final result = mapRecognizedText(recognized, const Size(1000, 1400));
    expect(result.blocks, hasLength(2));
    expect(result.blocks.first.text, 'DEPTH');
    expect(result.blocks.first.boundingBox, const Rect.fromLTRB(10, 20, 60, 32));
    expect(result.imageSize, const Size(1000, 1400));
  });
}
```

If `fromJson` requires a different shape (check the package source in `~/.pub-cache` for the exact keys), adjust the map — the assertion set is the contract.

- [ ] **Step 3: Run to verify failure, then implement**

```dart
// lib/features/ocr_import/data/engines/mlkit_ocr_engine.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';
import 'package:submersion/features/ocr_import/domain/services/ocr_engine.dart';

/// One OcrTextBlock per ML Kit LINE (not block): lines are the label/value
/// granularity the binder needs; blocks merge whole columns.
OcrResult mapRecognizedText(RecognizedText recognized, Size imageSize) {
  final blocks = <OcrTextBlock>[
    for (final block in recognized.blocks)
      for (final line in block.lines)
        OcrTextBlock(
          text: line.text,
          boundingBox: line.boundingBox,
          confidence: line.confidence,
        ),
  ];
  return OcrResult(blocks: blocks, imageSize: imageSize);
}

class MlkitOcrEngine implements OcrEngine {
  @override
  Future<bool> get isAvailable async => Platform.isAndroid;

  @override
  Future<OcrResult> recognize(Uint8List imageBytes) async {
    // ML Kit needs a file path; write bytes to a temp file.
    final tmp = await getTemporaryDirectory();
    final file = File(
      '${tmp.path}/ocr_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(imageBytes);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(file.path);
      final recognized = await recognizer.processImage(input);
      final decoded = await decodeImageFromList(imageBytes);
      return mapRecognizedText(
        recognized,
        Size(decoded.width.toDouble(), decoded.height.toDouble()),
      );
    } finally {
      await recognizer.close();
      await file.delete();
    }
  }
}
```

(`decodeImageFromList` is from `dart:ui` via `package:flutter/painting.dart` — import `package:flutter/painting.dart` if the analyzer complains. If `line.confidence` does not exist in the resolved package version, pass null.)

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/ocr_import/data/engines/mlkit_ocr_engine_test.dart`
Expected: PASS. Recognition quality itself is a manual on-device smoke item, not CI.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add pubspec.yaml pubspec.lock lib/features/ocr_import test/features/ocr_import
git commit -m "feat(ocr-import): Android ML Kit engine"
```

---

### Task 11: submersion_ocr plugin — Dart API + Apple Vision (iOS/macOS)

**Files:**
- Create: `packages/submersion_ocr/pubspec.yaml`
- Create: `packages/submersion_ocr/lib/submersion_ocr.dart`
- Create: `packages/submersion_ocr/darwin/Classes/SubmersionOcrPlugin.swift`
- Create: `packages/submersion_ocr/darwin/submersion_ocr.podspec`
- Modify: root `pubspec.yaml` (path dependency)
- Create: `lib/features/ocr_import/data/engines/channel_ocr_engine.dart`
- Test: `test/features/ocr_import/data/engines/channel_ocr_engine_test.dart`

**Interfaces:**
- Consumes: `OcrEngine`/`OcrResult`/`OcrTextBlock` (Task 1).
- Produces:
  - Plugin Dart API: `class SubmersionOcr { static Future<List<Map<String, dynamic>>> recognizeText(Uint8List imageBytes); }` over `MethodChannel('submersion_ocr')`, method `recognizeText`, argument `{'image': Uint8List}`, returning `List<Map>` of `{'text': String, 'left': double, 'top': double, 'width': double, 'height': double, 'confidence': double?, 'imageWidth': double, 'imageHeight': double}` — coordinates ALREADY converted to top-left-origin pixels by the native side.
  - App-side `class ChannelOcrEngine implements OcrEngine` wrapping it (used for iOS, macOS, Windows — Task 12 implements the same channel contract natively on Windows).

- [ ] **Step 1: Scaffold the plugin.** Model everything on `packages/submersion_saf` (`publish_to: none`, version 0.1.0). Key difference: two Apple platforms sharing one `darwin/` source dir.

```yaml
# packages/submersion_ocr/pubspec.yaml
name: submersion_ocr
description: On-device OCR (positioned text) for Submersion. Apple Vision on iOS/macOS, Windows.Media.Ocr on Windows.
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.5.0
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter

flutter:
  plugin:
    platforms:
      ios:
        pluginClass: SubmersionOcrPlugin
        sharedDarwinSource: true
      macos:
        pluginClass: SubmersionOcrPlugin
        sharedDarwinSource: true
      windows:
        pluginClass: SubmersionOcrPluginCApi
```

```yaml
# root pubspec.yaml, next to the existing submersion_saf entry
  submersion_ocr:
    path: packages/submersion_ocr
```

```ruby
# packages/submersion_ocr/darwin/submersion_ocr.podspec
Pod::Spec.new do |s|
  s.name             = 'submersion_ocr'
  s.version          = '0.1.0'
  s.summary          = 'On-device OCR for Submersion.'
  s.description      = 'Apple Vision text recognition returning positioned text blocks.'
  s.homepage         = 'https://submersion.app'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Submersion' => 'dev@submersion.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.swift_version = '5.0'
end
```

- [ ] **Step 2: Dart channel wrapper + app-side engine + failing test**

```dart
// packages/submersion_ocr/lib/submersion_ocr.dart
import 'dart:typed_data';

import 'package:flutter/services.dart';

class SubmersionOcr {
  static const MethodChannel _channel = MethodChannel('submersion_ocr');

  /// Returns one map per recognized text line:
  /// {text, left, top, width, height, confidence?, imageWidth, imageHeight}
  /// Coordinates are top-left-origin pixels.
  static Future<List<Map<String, dynamic>>> recognizeText(
    Uint8List imageBytes,
  ) async {
    final raw = await _channel.invokeListMethod<Object?>(
      'recognizeText',
      {'image': imageBytes},
    );
    return (raw ?? const [])
        .map((e) => Map<String, dynamic>.from(e! as Map))
        .toList();
  }
}
```

```dart
// lib/features/ocr_import/data/engines/channel_ocr_engine.dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion_ocr/submersion_ocr.dart';

import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';
import 'package:submersion/features/ocr_import/domain/services/ocr_engine.dart';

/// iOS/macOS (Apple Vision) and Windows (Windows.Media.Ocr) via the
/// submersion_ocr plugin. The native side owns coordinate normalization.
class ChannelOcrEngine implements OcrEngine {
  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<OcrResult> recognize(Uint8List imageBytes) async {
    final maps = await SubmersionOcr.recognizeText(imageBytes);
    if (maps.isEmpty) {
      return const OcrResult(blocks: [], imageSize: Size.zero);
    }
    final blocks = [
      for (final m in maps)
        OcrTextBlock(
          text: m['text'] as String,
          boundingBox: Rect.fromLTWH(
            (m['left'] as num).toDouble(),
            (m['top'] as num).toDouble(),
            (m['width'] as num).toDouble(),
            (m['height'] as num).toDouble(),
          ),
          confidence: (m['confidence'] as num?)?.toDouble(),
        ),
    ];
    final first = maps.first;
    return OcrResult(
      blocks: blocks,
      imageSize: Size(
        (first['imageWidth'] as num).toDouble(),
        (first['imageHeight'] as num).toDouble(),
      ),
    );
  }
}
```

```dart
// test/features/ocr_import/data/engines/channel_ocr_engine_test.dart
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/ocr_import/data/engines/channel_ocr_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decodes channel maps into OcrResult', () async {
    const channel = MethodChannel('submersion_ocr');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'recognizeText');
      return [
        {
          'text': 'DEPTH',
          'left': 10.0,
          'top': 20.0,
          'width': 50.0,
          'height': 12.0,
          'confidence': 0.95,
          'imageWidth': 1000.0,
          'imageHeight': 1400.0,
        },
      ];
    });
    final result = await ChannelOcrEngine().recognize(Uint8List(4));
    expect(result.blocks.single.text, 'DEPTH');
    expect(result.blocks.single.boundingBox.left, 10);
    expect(result.imageSize.width, 1000);
  });
}
```

Run: `flutter test test/features/ocr_import/data/engines/channel_ocr_engine_test.dart` — FAIL until wrapper + engine exist, then PASS. Run `flutter pub get` at repo root after adding the path dependency.

- [ ] **Step 3: Swift implementation (shared darwin source)**

```swift
// packages/submersion_ocr/darwin/Classes/SubmersionOcrPlugin.swift
import Vision
#if os(iOS)
import Flutter
import UIKit
#else
import FlutterMacOS
import AppKit
#endif

public class SubmersionOcrPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #else
    let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(name: "submersion_ocr", binaryMessenger: messenger)
    registrar.addMethodCallDelegate(SubmersionOcrPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "recognizeText",
          let args = call.arguments as? [String: Any],
          let imageData = args["image"] as? FlutterStandardTypedData else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let cgImage = Self.cgImage(from: imageData.data) else {
      result(FlutterError(code: "decode_failed", message: "Could not decode image", details: nil))
      return
    }
    let width = CGFloat(cgImage.width)
    let height = CGFloat(cgImage.height)

    let request = VNRecognizeTextRequest { req, error in
      if let error = error {
        result(FlutterError(code: "vision_failed", message: error.localizedDescription, details: nil))
        return
      }
      var blocks: [[String: Any]] = []
      for obs in (req.results as? [VNRecognizedTextObservation]) ?? [] {
        guard let candidate = obs.topCandidates(1).first else { continue }
        // Vision boundingBox: normalized, bottom-left origin. Flip Y.
        let bb = obs.boundingBox
        blocks.append([
          "text": candidate.string,
          "left": bb.minX * width,
          "top": (1.0 - bb.maxY) * height,
          "width": bb.width * width,
          "height": bb.height * height,
          "confidence": Double(candidate.confidence),
          "imageWidth": Double(width),
          "imageHeight": Double(height),
        ])
      }
      result(blocks)
    }
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true

    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "vision_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private static func cgImage(from data: Data) -> CGImage? {
    #if os(iOS)
    return UIImage(data: data)?.cgImage
    #else
    guard let ns = NSImage(data: data) else { return nil }
    var rect = CGRect(origin: .zero, size: ns.size)
    return ns.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    #endif
  }
}
```

- [ ] **Step 4: Build check.** Run `flutter pub get`, then `flutter build macos --debug` (from the worktree). If CocoaPods complains about the new plugin, run `pod install` in `macos/` (stale-Pods trap: a plugin gaining files needs per-platform `pod install`). Expected: build succeeds. Manual smoke (photograph a page, run OCR) happens in Task 15's verification.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add packages/submersion_ocr pubspec.yaml pubspec.lock lib/features/ocr_import test/features/ocr_import macos/Podfile.lock ios/Podfile.lock 2>/dev/null || true
git commit -m "feat(ocr-import): submersion_ocr plugin with Apple Vision engine"
```

---

### Task 12: submersion_ocr Windows implementation

**Files:**
- Create: `packages/submersion_ocr/windows/CMakeLists.txt`
- Create: `packages/submersion_ocr/windows/submersion_ocr_plugin.h`
- Create: `packages/submersion_ocr/windows/submersion_ocr_plugin.cpp`
- Create: `packages/submersion_ocr/windows/include/submersion_ocr/submersion_ocr_plugin_c_api.h`
- Create: `packages/submersion_ocr/windows/submersion_ocr_plugin_c_api.cpp`

**Interfaces:**
- Consumes: the channel contract from Task 11 (`recognizeText`, `{'image': bytes}` in, list of maps out, top-left pixel coordinates).
- Produces: the same contract via `Windows.Media.Ocr`. `OcrEngine::TryCreateFromUserProfileLanguages()`; decode bytes with `BitmapDecoder` from an `InMemoryRandomAccessStream`; emit one map per `OcrLine` (union of its words' rects; per-word confidence unavailable — send null).

**Windows-specific traps (from prior plugin work in this repo):**
- Plugin `.cc/.cpp` compiles with `/WX`; `windows.h` min/max macros break WinRT headers — `#define NOMINMAX` before any include, and never use bare `min`/`max`.
- Only the "Build Windows" CI job compiles this; local macOS work cannot. Structure the code so CI is the verification gate.

- [ ] **Step 1: Copy the plugin scaffolding** (CMakeLists, c_api shim) from an existing federated Windows plugin — `packages/auto_updater_windows/windows/` in this repo shows the exact pattern (project name, `flutter_plugin_registrar`, target properties). Rename symbols to `submersion_ocr_plugin` / `SubmersionOcrPluginCApi`. Add `WindowsApp.lib` to `target_link_libraries` for C++/WinRT.

- [ ] **Step 2: Implement the handler** in `submersion_ocr_plugin.cpp`:

```cpp
// Core recognize path (member function; registration/boilerplate mirrors
// auto_updater_windows). Compile-critical details shown in full:
#define NOMINMAX
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>
#include <winrt/Windows.Storage.Streams.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

using namespace winrt;
using namespace Windows::Media::Ocr;
using namespace Windows::Graphics::Imaging;
using namespace Windows::Storage::Streams;

void SubmersionOcrPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() != "recognizeText") {
    result->NotImplemented();
    return;
  }
  const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
  const auto* bytes = args ? std::get_if<std::vector<uint8_t>>(
      &args->at(flutter::EncodableValue("image"))) : nullptr;
  if (!bytes) {
    result->Error("bad_args", "expected {'image': bytes}");
    return;
  }
  auto shared_result = std::shared_ptr<
      flutter::MethodResult<flutter::EncodableValue>>(std::move(result));
  auto data = *bytes;  // copy for the coroutine
  RecognizeAsync(std::move(data), shared_result);
}

winrt::fire_and_forget SubmersionOcrPlugin::RecognizeAsync(
    std::vector<uint8_t> data,
    std::shared_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  try {
    InMemoryRandomAccessStream stream;
    DataWriter writer(stream.GetOutputStreamAt(0));
    writer.WriteBytes(array_view<const uint8_t>(data.data(),
                                                data.data() + data.size()));
    co_await writer.StoreAsync();
    auto decoder = co_await BitmapDecoder::CreateAsync(stream);
    auto bitmap = co_await decoder.GetSoftwareBitmapAsync();
    auto engine = OcrEngine::TryCreateFromUserProfileLanguages();
    if (!engine) {
      result->Success(flutter::EncodableValue(flutter::EncodableList{}));
      co_return;
    }
    auto ocr = co_await engine.RecognizeAsync(bitmap);
    flutter::EncodableList lines;
    double img_w = static_cast<double>(bitmap.PixelWidth());
    double img_h = static_cast<double>(bitmap.PixelHeight());
    for (auto const& line : ocr.Lines()) {
      double l = 1e18, t = 1e18, r = -1e18, b = -1e18;
      for (auto const& word : line.Words()) {
        auto rect = word.BoundingRect();
        if (rect.X < l) l = rect.X;
        if (rect.Y < t) t = rect.Y;
        if (rect.X + rect.Width > r) r = rect.X + rect.Width;
        if (rect.Y + rect.Height > b) b = rect.Y + rect.Height;
      }
      lines.push_back(flutter::EncodableValue(flutter::EncodableMap{
          {flutter::EncodableValue("text"),
           flutter::EncodableValue(winrt::to_string(line.Text()))},
          {flutter::EncodableValue("left"), flutter::EncodableValue(l)},
          {flutter::EncodableValue("top"), flutter::EncodableValue(t)},
          {flutter::EncodableValue("width"), flutter::EncodableValue(r - l)},
          {flutter::EncodableValue("height"), flutter::EncodableValue(b - t)},
          {flutter::EncodableValue("confidence"),
           flutter::EncodableValue()},
          {flutter::EncodableValue("imageWidth"),
           flutter::EncodableValue(img_w)},
          {flutter::EncodableValue("imageHeight"),
           flutter::EncodableValue(img_h)},
      }));
    }
    result->Success(flutter::EncodableValue(lines));
  } catch (winrt::hresult_error const& e) {
    result->Error("ocr_failed", winrt::to_string(e.message()));
  }
}
```

(Note the explicit `if (a < b)` comparisons instead of `min`/`max` — the `/WX` + macro trap.)

- [ ] **Step 3: Verify via CI.** Push the branch and confirm the "Build Windows" workflow compiles. No unit tests for native Windows code; the channel contract is already covered by Task 11's Dart test.

- [ ] **Step 4: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add packages/submersion_ocr
git commit -m "feat(ocr-import): Windows.Media.Ocr implementation"
```

---

### Task 13: Linux Tesseract engine

**Files:**
- Create: `lib/features/ocr_import/data/engines/tesseract_ocr_engine.dart`
- Test: `test/features/ocr_import/data/engines/tesseract_ocr_engine_test.dart`

**Interfaces:**
- Consumes: `OcrEngine` family (Task 1).
- Produces: `class TesseractOcrEngine implements OcrEngine` with constructor `TesseractOcrEngine({RunProcess runProcess = Process.run})` where `typedef RunProcess = Future<ProcessResult> Function(String, List<String>)` — injectable for tests. `isAvailable` = `which tesseract` succeeds. `recognize` writes bytes to a temp file, runs `tesseract <file> stdout tsv`, parses the TSV: rows with `level == 4` (textline) define geometry; concatenate that line's `level == 5` word texts. TSV columns: `level page_num block_num par_num line_num word_num left top width height conf text`.

- [ ] **Step 1: Write the failing tests** — inject a fake `runProcess` returning a canned TSV:

```dart
const sampleTsv = '''
level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext
1\t1\t0\t0\t0\t0\t0\t0\t1000\t1400\t-1\t
4\t1\t1\t1\t1\t0\t10\t20\t100\t14\t-1\t
5\t1\t1\t1\t1\t1\t10\t20\t50\t14\t91\tDEPTH
5\t1\t1\t1\t1\t2\t70\t20\t40\t14\t88\t69
''';

test('parses tesseract TSV into line-level blocks', () async {
  final engine = TesseractOcrEngine(
    runProcess: (cmd, args) async => ProcessResult(0, 0, sampleTsv, ''),
  );
  final result = await engine.recognize(Uint8List.fromList([1, 2, 3]));
  expect(result.blocks.single.text, 'DEPTH 69');
  expect(result.blocks.single.boundingBox,
      const Rect.fromLTWH(10, 20, 100, 14));
});

test('isAvailable false when binary missing', () async {
  final engine = TesseractOcrEngine(
    runProcess: (cmd, args) async => ProcessResult(0, 1, '', 'not found'),
  );
  expect(await engine.isAvailable, isFalse);
});

test('nonzero exit yields empty result', () async {
  final engine = TesseractOcrEngine(
    runProcess: (cmd, args) async => ProcessResult(0, 1, '', 'boom'),
  );
  final result = await engine.recognize(Uint8List.fromList([1]));
  expect(result.isEmpty, isTrue);
});
```

- [ ] **Step 2: Run to verify failure, then implement**

```dart
// lib/features/ocr_import/data/engines/tesseract_ocr_engine.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';
import 'package:submersion/features/ocr_import/domain/services/ocr_engine.dart';

typedef RunProcess = Future<ProcessResult> Function(String, List<String>);

/// Linux engine: shells out to the system `tesseract` binary in TSV mode.
/// Print-quality pages only; handwriting support is poor by nature.
class TesseractOcrEngine implements OcrEngine {
  final RunProcess _run;

  TesseractOcrEngine({RunProcess? runProcess})
      : _run = runProcess ?? _defaultRun;

  static Future<ProcessResult> _defaultRun(String cmd, List<String> args) =>
      Process.run(cmd, args);

  @override
  Future<bool> get isAvailable async {
    try {
      final result = await _run('which', ['tesseract']);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  @override
  Future<OcrResult> recognize(Uint8List imageBytes) async {
    Directory? tmp;
    try {
      tmp = await Directory.systemTemp.createTemp('submersion_ocr');
      final file = File('${tmp.path}/page.png');
      await file.writeAsBytes(imageBytes);
      final result = await _run('tesseract', [file.path, 'stdout', 'tsv']);
      if (result.exitCode != 0) {
        return const OcrResult(blocks: [], imageSize: Size.zero);
      }
      return _parseTsv(result.stdout as String);
    } on ProcessException {
      return const OcrResult(blocks: [], imageSize: Size.zero);
    } finally {
      await tmp?.delete(recursive: true);
    }
  }

  OcrResult _parseTsv(String tsv) {
    var imageSize = Size.zero;
    final lineRects = <String, Rect>{};
    final lineWords = <String, List<String>>{};
    final lineConfs = <String, List<double>>{};

    for (final row in tsv.split('\n').skip(1)) {
      final cols = row.split('\t');
      if (cols.length < 12) continue;
      final level = int.tryParse(cols[0]);
      if (level == null) continue;
      final rect = Rect.fromLTWH(
        double.tryParse(cols[6]) ?? 0,
        double.tryParse(cols[7]) ?? 0,
        double.tryParse(cols[8]) ?? 0,
        double.tryParse(cols[9]) ?? 0,
      );
      final key = '${cols[2]}:${cols[3]}:${cols[4]}';
      if (level == 1) {
        imageSize = Size(rect.width, rect.height);
      } else if (level == 4) {
        lineRects[key] = rect;
      } else if (level == 5) {
        final text = cols[11].trim();
        if (text.isEmpty) continue;
        lineWords.putIfAbsent(key, () => []).add(text);
        final conf = double.tryParse(cols[10]) ?? -1;
        if (conf >= 0) lineConfs.putIfAbsent(key, () => []).add(conf);
      }
    }

    final blocks = <OcrTextBlock>[
      for (final entry in lineWords.entries)
        if (lineRects.containsKey(entry.key))
          OcrTextBlock(
            text: entry.value.join(' '),
            boundingBox: lineRects[entry.key]!,
            confidence: lineConfs[entry.key] == null
                ? null
                : lineConfs[entry.key]!.reduce((a, b) => a + b) /
                    lineConfs[entry.key]!.length /
                    100,
          ),
    ];
    return OcrResult(blocks: blocks, imageSize: imageSize);
  }
}
```

- [ ] **Step 3: Run to verify pass**

Run: `flutter test test/features/ocr_import/data/engines/tesseract_ocr_engine_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 4: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/ocr_import test/features/ocr_import
git commit -m "feat(ocr-import): Linux Tesseract engine"
```

---

### Task 14: Engine provider

**Files:**
- Create: `lib/features/ocr_import/presentation/providers/ocr_providers.dart`
- Test: `test/features/ocr_import/presentation/providers/ocr_providers_test.dart`

**Interfaces:**
- Consumes: all three engines (Tasks 10, 11, 13).
- Produces: `final ocrEngineProvider = Provider<OcrEngine>(...)` selecting by `defaultTargetPlatform`: android -> `MlkitOcrEngine`, iOS/macOS/windows -> `ChannelOcrEngine`, linux -> `TesseractOcrEngine`, anything else -> `TesseractOcrEngine` (harmless: `isAvailable` gates usage). Also `final ocrAvailabilityProvider = FutureProvider<bool>((ref) => ref.watch(ocrEngineProvider).isAvailable);`.

- [ ] **Step 1: Write the failing test.** Note: the provider must use `defaultTargetPlatform`, not `Platform.isX`, precisely so tests can override it.

```dart
// test/features/ocr_import/presentation/providers/ocr_providers_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/ocr_import/data/engines/channel_ocr_engine.dart';
import 'package:submersion/features/ocr_import/data/engines/mlkit_ocr_engine.dart';
import 'package:submersion/features/ocr_import/data/engines/tesseract_ocr_engine.dart';
import 'package:submersion/features/ocr_import/presentation/providers/ocr_providers.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  OcrEngineType engineFor(TargetPlatform platform) {
    debugDefaultTargetPlatformOverride = platform;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container.read(ocrEngineProvider).runtimeType;
  }

  test('android uses ML Kit', () {
    expect(engineFor(TargetPlatform.android), MlkitOcrEngine);
  });
  test('macOS uses the plugin channel', () {
    expect(engineFor(TargetPlatform.macOS), ChannelOcrEngine);
  });
  test('linux uses Tesseract', () {
    expect(engineFor(TargetPlatform.linux), TesseractOcrEngine);
  });
}
```

(`OcrEngineType` is just `Type` — write `Type engineFor(...)`.)

- [ ] **Step 2: Run to verify failure, then implement**

```dart
// lib/features/ocr_import/presentation/providers/ocr_providers.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/ocr_import/data/engines/channel_ocr_engine.dart';
import 'package:submersion/features/ocr_import/data/engines/mlkit_ocr_engine.dart';
import 'package:submersion/features/ocr_import/data/engines/tesseract_ocr_engine.dart';
import 'package:submersion/features/ocr_import/domain/services/ocr_engine.dart';

final ocrEngineProvider = Provider<OcrEngine>((ref) {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => MlkitOcrEngine(),
    TargetPlatform.iOS ||
    TargetPlatform.macOS ||
    TargetPlatform.windows =>
      ChannelOcrEngine(),
    _ => TesseractOcrEngine(),
  };
});

final ocrAvailabilityProvider = FutureProvider<bool>(
  (ref) => ref.watch(ocrEngineProvider).isAvailable,
);
```

- [ ] **Step 3: Run to verify pass**

Run: `flutter test test/features/ocr_import/presentation/providers/ocr_providers_test.dart`

- [ ] **Step 4: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/ocr_import test/features/ocr_import
git commit -m "feat(ocr-import): platform engine provider"
```

---

### Task 15: Scan flow controller and page

**Files:**
- Create: `lib/features/ocr_import/presentation/controllers/scan_flow_controller.dart`
- Create: `lib/features/ocr_import/presentation/pages/ocr_scan_page.dart`
- Modify: `lib/core/router/app_router.dart` (new route under the `/dives` block at line ~259)
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (photo attach after save)
- Test: `test/features/ocr_import/presentation/controllers/scan_flow_controller_test.dart`

**Interfaces:**
- Consumes: `ocrEngineProvider` (Task 14), `LogbookParser` (Task 5), `resolveSiteByName` (Task 8), `DivePrefill` (Task 7), `importLocalFileForDive` (Task 9), `settingsProvider`/`AppSettings` units, existing sites list provider (find the provider the sites list page watches — `grep -rn "sitesProvider\|allSitesProvider" lib/features/dive_sites/presentation/providers/` and use that).
- Produces:

```dart
class ScanFlowController {
  ScanFlowController({
    required OcrEngine engine,
    required LogbookParser parser,
    required List<DiveSite> existingSites,
    required UnitDefaults fallbackUnits,
    required bool preferDayFirst,
  });

  /// Runs OCR + parse + site resolution. Never throws:
  /// engine/parse errors produce an empty-fields prefill so the flow
  /// always lands on the edit form with the photo attached.
  Future<DivePrefill> process(Uint8List imageBytes, String photoPath);
}
```

**Controller behavior (implement exactly):**
1. `engine.recognize` in try/catch; on error or empty result return `DivePrefill(photoPath: photoPath, importSource: 'ocr')`.
2. `parser.parse` with the injected units/locale.
3. Site: `parsed.siteName` -> `resolveSiteByName`; match => `site:`; no match => site name joins the appendix.
4. Notes assembly: `parsed.notes`, then if `parsed.unmapped` is non-empty or the site was unresolved, append a plain-text appendix:

```
--- Scanned from paper log ---
Site: O'ahu - pipe
Visibility: 60 ft
Buddy: ...
```

   (One `Key: value` line per entry; keys capitalized. This appendix is intentionally not localized — it is data, not UI chrome.)
5. Map every remaining `ParsedDiveFields` field 1:1 onto `DivePrefill`, `hasTimeOfDay` included, plus `photoPath` and `importSource: 'ocr'`.

**Page behavior:** `OcrScanPage` (ConsumerStatefulWidget, route `/dives/scan`, name `scanPaperLog`):
- On open: platform-appropriate acquisition — `ImagePicker().pickImage(source: ImageSource.camera)` with a gallery alternative button on iOS/Android; `file_picker` (`FilePicker.platform.pickFiles(type: FileType.image)`) on desktop.
- States: picking -> processing (spinner + "Reading page...") -> done (`context.pushReplacement('/dives/new', extra: prefill)`) or cancelled (`context.pop()`).
- If `ocrAvailabilityProvider` resolves false (Linux without Tesseract): show explanatory body text ("Install tesseract-ocr to scan paper logs, e.g. sudo apt install tesseract-ocr") instead of the picker; keep a Cancel button. Localize this string (Task 16 adds all keys).
- If the parse produced an entirely empty prefill, still navigate, and show a SnackBar on the edit page via the prefill route? No — keep it simple: `OcrScanPage` shows a brief SnackBar "Couldn't read much from this page" (localized, `persist: false`, `showCloseIcon: true` per repo convention) just before navigating.

**Photo attach (in DiveEditPage, create-mode save path):** after a successful create with `widget.prefill?.photoPath != null`, call `importLocalFileForDive(sourceFile: File(photoPath), diveId: savedId)` in try/catch; failure shows a SnackBar but never blocks the save.

- [ ] **Step 1: Write the failing controller tests** — fake engine (canned `OcrResult` from Task 6 fixtures), real parser, in-memory site list:

```dart
test('happy path produces prefill with resolved site', () async {
  final controller = ScanFlowController(
    engine: FakeEngine(padiTrainingMetric()),
    parser: LogbookParser(),
    existingSites: [site('2', 'Pinnacle, Sodwana Bay')],
    fallbackUnits: metric,
    preferDayFirst: false,
  );
  final prefill = await controller.process(Uint8List(4), '/tmp/p.jpg');
  expect(prefill.site?.id, '2');
  expect(prefill.maxDepthMeters, closeTo(11.1, 0.001));
  expect(prefill.photoPath, '/tmp/p.jpg');
  expect(prefill.importSource, 'ocr');
});

test('unresolved site name lands in notes appendix', () async {
  final controller = ScanFlowController(
    engine: FakeEngine(padiHandwrittenImperial()),
    parser: LogbookParser(),
    existingSites: const [],
    fallbackUnits: metric,
    preferDayFirst: false,
  );
  final prefill = await controller.process(Uint8List(4), '/tmp/p.jpg');
  expect(prefill.site, isNull);
  expect(prefill.notes, contains("Site: O'ahu - pipe"));
  expect(prefill.notes, contains('Visibility: 60 ft'));
});

test('engine failure degrades to photo-only prefill', () async {
  final controller = ScanFlowController(
    engine: ThrowingEngine(),
    parser: LogbookParser(),
    existingSites: const [],
    fallbackUnits: metric,
    preferDayFirst: false,
  );
  final prefill = await controller.process(Uint8List(4), '/tmp/p.jpg');
  expect(prefill.photoPath, '/tmp/p.jpg');
  expect(prefill.maxDepthMeters, isNull);
});
```

(`FakeEngine`/`ThrowingEngine` are 5-line hand-written fakes implementing `OcrEngine` in the test file.)

- [ ] **Step 2: Run to verify failure, then implement controller, page, route, and the DiveEditPage photo-attach hook.** Route addition:

```dart
GoRoute(
  path: 'scan',
  name: 'scanPaperLog',
  builder: (context, state) => const OcrScanPage(),
),
```

- [ ] **Step 3: Run to verify pass**

Run: `flutter test test/features/ocr_import/presentation/controllers/scan_flow_controller_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 4: Manual smoke on macOS**

Run: `flutter run -d macos`. Scan one of the real sample-log photos end to end: pick file -> spinner -> edit form prefilled -> save -> dive exists with photo attached and `importSource` 'ocr'. Fix what breaks; this is the first full-stack run.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/ocr_import lib/features/dive_log lib/core/router test/features/ocr_import
git commit -m "feat(ocr-import): scan flow from photo to prefilled dive"
```

---

### Task 16: Entry points and localization

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/add_dive_bottom_sheet.dart`
- Modify: all 11 arb files in `lib/l10n/arb/` (`app_en.arb`, ar, de, es, fr, he, hu, it, nl, pt, zh)
- Test: `test/features/dive_log/presentation/widgets/add_dive_bottom_sheet_test.dart` (create if absent)

**Interfaces:**
- Consumes: route `scanPaperLog` (Task 15).
- Produces: the user-visible entry point.

- [ ] **Step 1: Add English strings to `app_en.arb`** (key style matches existing `diveLog_listPage_bottomSheet_*` keys):

```json
"diveLog_listPage_bottomSheet_scanPaperLog": "Scan Paper Log",
"ocrImport_scanPage_title": "Scan Paper Log",
"ocrImport_scanPage_processing": "Reading page...",
"ocrImport_scanPage_pickPhoto": "Choose Photo",
"ocrImport_scanPage_takePhoto": "Take Photo",
"ocrImport_scanPage_nothingRead": "Couldn't read much from this page - fields left blank",
"ocrImport_scanPage_engineMissing": "Text recognition is not available. Install Tesseract to scan paper logs (for example: sudo apt install tesseract-ocr).",
"ocrImport_editPage_photoAttachFailed": "The dive was saved, but attaching the scanned page failed"
```

- [ ] **Step 2: Translate every key into all 10 other locales** (ar, de, es, fr, he, hu, it, nl, pt, zh) — no locale may be missed; CI/gen-l10n treats missing keys as untranslated. Then run `flutter gen-l10n` and replace the hardcoded strings from Task 15's page/SnackBars with `context.l10n.*` references.

- [ ] **Step 3: Add the tile** to `add_dive_bottom_sheet.dart` after the "Import from Computer" tile:

```dart
ListTile(
  leading: const Icon(Icons.document_scanner_outlined),
  title: Text(
    sheetContext.l10n.diveLog_listPage_bottomSheet_scanPaperLog,
  ),
  onTap: () {
    Navigator.pop(sheetContext);
    context.push('/dives/scan');
  },
),
```

- [ ] **Step 4: Widget test** — pump a `MaterialApp` with localizations + a button invoking `showAddDiveBottomSheet`, tap it, assert `find.text('Scan Paper Log')` appears. If an existing bottom-sheet test file exists, extend it instead.

Run: `flutter test test/features/dive_log/presentation/widgets/add_dive_bottom_sheet_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log lib/l10n test/features/dive_log lib/features/ocr_import
git commit -m "feat(ocr-import): scan entry point and localized strings"
```

---

### Task 17: Final verification

**Files:** none new.

- [ ] **Step 1: Full targeted test sweep** — run each test file created by this plan (Tasks 1-16), one command per file or small group:

```bash
flutter test test/features/ocr_import/
flutter test test/features/dive_log/presentation/pages/dive_edit_prefill_test.dart test/features/dive_log/presentation/pages/dive_edit_page_test.dart
flutter test test/features/media/data/services/media_import_local_file_test.dart
flutter test test/features/dive_log/presentation/widgets/add_dive_bottom_sheet_test.dart
```

Expected: ALL PASS.

- [ ] **Step 2: Whole-project gates**

```bash
dart format .        # must produce no changes
flutter analyze      # zero issues
```

- [ ] **Step 3: Platform builds available locally**

```bash
flutter build macos --debug
```

Push the branch (use `git push --no-verify` — the worktree pre-push hook runs against the main tree and reports false issues; `env -u GITHUB_TOKEN git push` if auth fails) and let CI cover Android/iOS/Windows/Linux builds.

- [ ] **Step 4: Manual smoke checklist** (record results in the PR description):
  - macOS: scan sample page 1 (imperial handwritten) and sample page 2 (metric print) end to end.
  - iOS/Android: camera capture path (requires hardware).
  - Verify: photo attached to the dive, `importSource` = 'ocr', units correct against the diver's settings, notes appendix present for unmapped values.

- [ ] **Step 5: Update the spec's status line** in `docs/superpowers/specs/2026-07-06-ocr-logbook-import-design.md` from "pending implementation plan" to "Implemented (plan: docs/superpowers/plans/2026-07-06-ocr-logbook-import.md)" and commit:

```bash
git add docs/superpowers/specs/2026-07-06-ocr-logbook-import-design.md
git commit -m "docs: mark OCR logbook import spec implemented"
```

---

## Deferred (explicitly not in this plan)

- Checkbox reading (water type, unit tick-boxes) — spec v1 scope cut.
- Template packs, batch capture, cloud extraction, marine-life extraction — spec "Out of scope".
- Structured buddy/divemaster binding to `BuddyWithRole` — names land in the notes appendix.
- A second entry-point tile in the `/transfer` import wizard area (spec deviation 5).
- Image preprocessing (deskew/contrast). Add only if the Task 15 manual smoke shows the engines need it.
