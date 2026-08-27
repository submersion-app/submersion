# Garmin FIT Import Enrichment — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Garmin FIT import extract everything the file contains — tank pressure/air-integration, gas mixes, per-sample deco (ceiling/TTS/NDL), CNS/OTU, heart rate, dive number, bottom time, surface interval, water type, deco model/GF, computer model — and let the existing site matcher see FIT/DC GPS.

**Architecture:** "Make FIT speak UDDF." Decompose the FIT parser into focused extractors; emit the UDDF-shaped `ImportPayload` so the existing `UddfEntityImporter` persists the rich data unchanged. Reuse the existing GPS→site matching engine; fix only the persistence omissions that keep coordinates from reaching it. No new matcher, no `fit_tool` fork.

**Tech Stack:** Flutter 3.x, Dart, `fit_tool: ^1.0.5` (FIT parsing), Drift (SQLite), Riverpod, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-06-22-garmin-fit-import-design.md` (read Appendix A/B for verified FIT field/scale ground truth).

## Global Constraints

- All Dart must pass `dart format .` (no diff) and whole-project `flutter analyze` (zero new issues) before each commit.
- TDD: write the failing test first, watch it fail, implement minimally, watch it pass, commit.
- Immutability: entities are immutable with `copyWith`; never mutate lists/objects in place.
- No emojis in code/comments/docs. No `print` in production code.
- Store values in metric internally (FIT is already metric: m, °C, bar, L). Display conversion is out of scope.
- Run **specific test files** (e.g. `flutter test test/features/dive_import/data/services/fit/fit_tank_extractor_test.dart`), never broad directories (avoids Bash timeouts).
- Commit messages: **no `Co-Authored-By` lines**. Work on a feature branch (e.g. `worktree-garmin-fit-import`), never `main`. Per-task commits are pre-authorized once this plan is approved.
- New user-facing strings must be translated into all 10 non-en locales and regenerated. (This plan reuses the existing `importSummary_matchSitesButton` string for the only UI change, so no new strings are expected — flagged per task if that changes.)
- FIT field numbers/scales are verified ground truth — copy them exactly: `tank_update`=319 (field 0=sensor, 1=pressure×0.01 bar, 253=timestamp); `tank_summary`=323 (field 0=sensor, 1=startP, 2=endP ×0.01 bar, 3=volumeUsed ×0.01 L); semicircle→degrees = value × (180 / 2147483648); `garmin_product`: 4223=Descent Mk3i, 4518=Descent X50i, 3865=T2 transmitter.

---

## File Structure

**New (FIT extractors, each one responsibility):** under `lib/features/dive_import/data/services/fit/`
- `fit_constants.dart` — message numbers, field numbers, scale constants.
- `fit_message_access.dart` — raw field-by-number access for `GenericMessage` (unnamed msgs).
- `fit_time_resolver.dart` — wall-clock from `local_timestamp`.
- `fit_device_mapper.dart` — `garmin_product` → model name.
- `fit_gas_extractor.dart` — `dive_gas` → gas mixes.
- `fit_tank_extractor.dart` — `tank_summary`/`tank_update` → tanks + pressure series.
- `fit_profile_extractor.dart` — `record` → samples (depth/temp/HR + ceiling/ndl/tts/cns).
- `fit_summary_extractor.dart` — `dive_summary`/`session`/`dive_settings` → summary fields.

**Modified:**
- `lib/features/dive_import/domain/entities/imported_dive.dart` — extend model.
- `lib/features/dive_import/data/services/fit_parser_service.dart` — orchestrate extractors + merge tank pressures into samples.
- `lib/features/universal_import/data/parsers/fit_import_parser.dart` — emit UDDF-shaped payload.
- `lib/features/dive_import/data/services/uddf_entity_importer.dart` — map `ceiling`; set `entryLocation`/`exitLocation` on the Dive.
- `lib/features/dive_log/data/repositories/dive_repository_impl.dart` — persist `entryLocation`/`exitLocation` in `createDive`.
- The dive-computer post-download results widget — surface the existing "Match Sites" affordance (#310).

**Tests:** mirror new files under `test/features/dive_import/data/services/fit/`, plus importer/integration tests under `test/features/dive_import/` and `test/features/universal_import/`.

---

## Phase 1 — Foundation: constants, message access, time, device

### Task 1: FIT constants + raw message access

**Files:**
- Create: `lib/features/dive_import/data/services/fit/fit_constants.dart`
- Create: `lib/features/dive_import/data/services/fit/fit_message_access.dart`
- Test: `test/features/dive_import/data/services/fit/fit_message_access_test.dart`

**Interfaces:**
- Produces: `FitConstants` (static const ints/doubles); `FitMessageAccess.rawNum(DataMessage, int fieldId) -> num?`, `FitMessageAccess.messagesWithGlobalId(List<Message>, int globalId) -> List<DataMessage>`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_import/data/services/fit/fit_message_access_test.dart
import 'package:fit_tool/fit_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_constants.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_message_access.dart';

void main() {
  test('rawNum reads a field by number from a GenericMessage (tank_update)', () {
    // Build a tank_update (msg 319): field 0=sensor, 1=pressure(raw), 253=ts.
    final def = DefinitionMessage(
      globalId: FitConstants.tankUpdateMsg,
      localId: 0,
    )
      ..fieldDefinitions.addAll([
        FieldDefinition(id: 253, baseType: BaseType.uint32, size: 4),
        FieldDefinition(id: 0, baseType: BaseType.uint32, size: 4),
        FieldDefinition(id: 1, baseType: BaseType.uint16, size: 2),
      ]);
    final msg = GenericMessage(definitionMessage: def)
      ..setFieldValueByIndex(253, 1126250405)
      ..setFieldValueByIndex(0, 2772884913)
      ..setFieldValueByIndex(1, 22125);

    expect(msg.globalId, FitConstants.tankUpdateMsg);
    expect(FitMessageAccess.rawNum(msg, 1), 22125);
    expect(FitMessageAccess.rawNum(msg, 0), 2772884913);
    expect(FitMessageAccess.rawNum(msg, 99), isNull);
  });

  test('messagesWithGlobalId filters by FIT global message number', () {
    final def = DefinitionMessage(globalId: FitConstants.tankSummaryMsg, localId: 0);
    final msg = GenericMessage(definitionMessage: def);
    final others = <Message>[RecordMessage()];
    final result = FitMessageAccess.messagesWithGlobalId(
      [msg, ...others],
      FitConstants.tankSummaryMsg,
    );
    expect(result, hasLength(1));
    expect(result.first.globalId, FitConstants.tankSummaryMsg);
  });
}
```

> NOTE: `setFieldValueByIndex` / `FieldDefinition` / `GenericMessage` come from `fit_tool`. If the exact builder API for synthetic `GenericMessage` construction differs at execution time, inspect `~/.pub-cache/hosted/pub.dev/fit_tool-1.0.5/lib/src/generic_message.dart` and `definition_message.dart` and adjust the construction (the assertions on `rawNum`/`messagesWithGlobalId` stay the same). This is the one library-capability spike; resolve it here before proceeding.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_import/data/services/fit/fit_message_access_test.dart`
Expected: FAIL — `fit_constants.dart`/`fit_message_access.dart` do not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/dive_import/data/services/fit/fit_constants.dart
/// Verified Garmin FIT message/field numbers and scales (see design spec
/// Appendix A). fit_tool 1.0.5 has no named classes for tank messages, so
/// they are read by global id + field number off GenericMessage.
class FitConstants {
  const FitConstants._();

  // Global message numbers.
  static const int tankUpdateMsg = 319;
  static const int tankSummaryMsg = 323;

  // tank_update field numbers.
  static const int tuTimestamp = 253;
  static const int tuSensor = 0;
  static const int tuPressure = 1;

  // tank_summary field numbers.
  static const int tsSensor = 0;
  static const int tsStartPressure = 1;
  static const int tsEndPressure = 2;
  static const int tsVolumeUsed = 3;

  // Scales: raw integer -> physical unit.
  static const double pressureScaleBar = 100.0; // raw / 100 = bar
  static const double volumeScaleLiters = 100.0; // raw / 100 = liters
  static const double semicircleToDegrees = 180.0 / 2147483648.0;
}
```

```dart
// lib/features/dive_import/data/services/fit/fit_message_access.dart
import 'package:fit_tool/fit_tool.dart';

/// Raw field access for FIT messages fit_tool exposes only as [GenericMessage]
/// (it has no profile, so values are unscaled — callers apply scales).
class FitMessageAccess {
  const FitMessageAccess._();

  static num? rawNum(DataMessage message, int fieldId) {
    final value = message.getField(fieldId)?.value;
    return value is num ? value : null;
  }

  static List<DataMessage> messagesWithGlobalId(
    List<Message> messages,
    int globalId,
  ) {
    return messages
        .whereType<DataMessage>()
        .where((m) => m.globalId == globalId)
        .toList();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_import/data/services/fit/fit_message_access_test.dart`
Expected: PASS

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_import/data/services/fit test/features/dive_import/data/services/fit
flutter analyze lib/features/dive_import/data/services/fit
git add lib/features/dive_import/data/services/fit test/features/dive_import/data/services/fit
git commit -m "feat(fit): add FIT constants and GenericMessage field access"
```

---

### Task 2: `FitTimeResolver` — local wall-clock from `local_timestamp`

**Files:**
- Create: `lib/features/dive_import/data/services/fit/fit_time_resolver.dart`
- Test: `test/features/dive_import/data/services/fit/fit_time_resolver_test.dart`

**Interfaces:**
- Produces: `FitTimeResolver.wallClockStart({required int? utcStartMs, required int? localStartMs, required int? utcTimestampMs, required int? localTimestampMs}) -> DateTime` — returns the dive's local wall-clock as a UTC-flagged `DateTime` (wall-clock-as-UTC convention).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_import/data/services/fit/fit_time_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_time_resolver.dart';

void main() {
  // Malta dive: session.startTime is 08:51:10 UTC; activity local_timestamp
  // shows 10:51:10 (UTC+2). The displayed wall-clock must be 10:51:10.
  final utcStart = DateTime.utc(2025, 10, 13, 8, 51, 10).millisecondsSinceEpoch;
  final utcAct = DateTime.utc(2025, 10, 13, 8, 51, 10).millisecondsSinceEpoch;
  final localAct = DateTime.utc(2025, 10, 13, 10, 51, 10).millisecondsSinceEpoch;

  test('applies activity UTC offset to the session start', () {
    final result = FitTimeResolver.wallClockStart(
      utcStartMs: utcStart,
      localStartMs: null,
      utcTimestampMs: utcAct,
      localTimestampMs: localAct,
    );
    expect(result, DateTime.utc(2025, 10, 13, 10, 51, 10));
    expect(result.isUtc, isTrue);
  });

  test('falls back to raw start when no local_timestamp is present', () {
    final result = FitTimeResolver.wallClockStart(
      utcStartMs: utcStart,
      localStartMs: null,
      utcTimestampMs: null,
      localTimestampMs: null,
    );
    expect(result, DateTime.utc(2025, 10, 13, 8, 51, 10));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_import/data/services/fit/fit_time_resolver_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/dive_import/data/services/fit/fit_time_resolver.dart
/// Resolves a dive's local wall-clock start, stored as a UTC-flagged DateTime
/// (the app's "wall-clock-as-UTC" convention: the displayed time must equal
/// the local time at the dive site regardless of the importing device's TZ).
///
/// FIT `record`/`session` timestamps are UTC. The `activity` message carries
/// both `timestamp` (UTC) and `local_timestamp`; their difference is the dive's
/// UTC offset, which we add to the UTC start to recover local wall-clock.
class FitTimeResolver {
  const FitTimeResolver._();

  static DateTime wallClockStart({
    required int? utcStartMs,
    required int? localStartMs,
    required int? utcTimestampMs,
    required int? localTimestampMs,
  }) {
    final startMs = utcStartMs ?? localStartMs ?? 0;
    var offsetMs = 0;
    if (utcTimestampMs != null && localTimestampMs != null) {
      offsetMs = localTimestampMs - utcTimestampMs;
    }
    final wall = DateTime.fromMillisecondsSinceEpoch(
      startMs + offsetMs,
      isUtc: true,
    );
    return DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
      wall.second,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_import/data/services/fit/fit_time_resolver_test.dart`
Expected: PASS

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_import/data/services/fit test/features/dive_import/data/services/fit
flutter analyze lib/features/dive_import/data/services/fit
git add lib/features/dive_import/data/services/fit test/features/dive_import/data/services/fit
git commit -m "feat(fit): resolve local wall-clock from FIT local_timestamp"
```

> EXECUTION NOTE: confirm `activity` is exposed by fit_tool (`ActivityMessage` with `localTimestamp`/`timestamp`) and that `record`/`session` start timestamps are available; the orchestrator (Task 9) supplies these ints. If `ActivityMessage.localTimestamp` is absent in fit_tool 1.0.5, read it via `FitMessageAccess.rawNum(activityMsg, 5)` (`local_timestamp` is field 5 of `activity`, msg 34) and treat as seconds since FIT epoch (add 631065600 s and ×1000 for ms).

---

### Task 3: `FitDeviceMapper` — product code → model name

**Files:**
- Create: `lib/features/dive_import/data/services/fit/fit_device_mapper.dart`
- Test: `test/features/dive_import/data/services/fit/fit_device_mapper_test.dart`

**Interfaces:**
- Produces: `FitDeviceMapper.modelName(int? garminProduct) -> String` (falls back to `'Garmin Descent'`).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_import/data/services/fit/fit_device_mapper_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_device_mapper.dart';

void main() {
  test('maps known Garmin dive product codes', () {
    expect(FitDeviceMapper.modelName(4223), 'Descent Mk3i');
    expect(FitDeviceMapper.modelName(4518), 'Descent X50i');
  });

  test('falls back for unknown or null product', () {
    expect(FitDeviceMapper.modelName(999999), 'Garmin Descent');
    expect(FitDeviceMapper.modelName(null), 'Garmin Descent');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_import/data/services/fit/fit_device_mapper_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/dive_import/data/services/fit/fit_device_mapper.dart
/// Maps Garmin FIT `file_id.garmin_product` codes to human model names.
/// Verified codes: 4223=Mk3i, 4518=X50i, 3865=T2 transmitter. Others are
/// best-effort from the Garmin FIT product list; unknown -> generic name.
class FitDeviceMapper {
  const FitDeviceMapper._();

  static const Map<int, String> _models = {
    2859: 'Descent Mk1',
    3258: 'Descent Mk2 / Mk2i',
    3542: 'Descent Mk2s',
    4223: 'Descent Mk3i',
    4518: 'Descent X50i',
    3865: 'Descent T2 Transmitter',
  };

  static String modelName(int? garminProduct) {
    if (garminProduct == null) return 'Garmin Descent';
    return _models[garminProduct] ?? 'Garmin Descent';
  }
}
```

> EXECUTION NOTE: verify the Mk2-family codes (2859/3258/3542) against `~/.pub-cache/hosted/pub.dev/fit_tool-1.0.5/lib/src/garmin_products.dart` (or the GarminProduct enum) if present; 4223/4518/3865 are verified from the sample files and must stay. Wrong secondary codes only mislabel an untested model, never break import.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_import/data/services/fit/fit_device_mapper_test.dart`
Expected: PASS

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_import/data/services/fit test/features/dive_import/data/services/fit
flutter analyze lib/features/dive_import/data/services/fit
git add lib/features/dive_import/data/services/fit test/features/dive_import/data/services/fit
git commit -m "feat(fit): map Garmin product codes to model names"
```

---

## Phase 2 — Extractors

### Task 4: `FitGasExtractor` — gas mixes from `dive_gas`

**Files:**
- Create: `lib/features/dive_import/data/services/fit/fit_gas_extractor.dart`
- Test: `test/features/dive_import/data/services/fit/fit_gas_extractor_test.dart`

**Interfaces:**
- Produces: `class FitGas { final int index; final double o2Percent; final double hePercent; final bool enabled; }`; `FitGasExtractor.extract(List<Message>) -> List<FitGas>` (sorted by index, enabled only).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_import/data/services/fit/fit_gas_extractor_test.dart
import 'package:fit_tool/fit_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_gas_extractor.dart';

void main() {
  test('extracts enabled gas mixes sorted by message index', () {
    final g0 = DiveGasMessage()
      ..messageIndex = 0
      ..oxygenContent = 30
      ..heliumContent = 0
      ..status = DiveGasStatus.enabled;
    final g1 = DiveGasMessage()
      ..messageIndex = 1
      ..oxygenContent = 50
      ..heliumContent = 0
      ..status = DiveGasStatus.enabled;

    final gases = FitGasExtractor.extract([g1, g0]);

    expect(gases, hasLength(2));
    expect(gases[0].index, 0);
    expect(gases[0].o2Percent, 30);
    expect(gases[1].o2Percent, 50);
  });
}
```

> EXECUTION NOTE: confirm `DiveGasMessage` getters (`oxygenContent`, `heliumContent`, `status`, `messageIndex`) and the `DiveGasStatus` enum in `~/.pub-cache/.../fit_tool/lib/src/profile/messages/dive_gas_message.dart`. Adjust names if they differ; the extracted values must match (O2=30/50, He=0).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_import/data/services/fit/fit_gas_extractor_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/dive_import/data/services/fit/fit_gas_extractor.dart
import 'package:fit_tool/fit_tool.dart';

class FitGas {
  const FitGas({
    required this.index,
    required this.o2Percent,
    required this.hePercent,
    required this.enabled,
  });

  final int index;
  final double o2Percent;
  final double hePercent;
  final bool enabled;
}

/// Extracts the enabled gas mixes from FIT `dive_gas` (msg 259) messages.
class FitGasExtractor {
  const FitGasExtractor._();

  static List<FitGas> extract(List<Message> messages) {
    final gases = messages
        .whereType<DiveGasMessage>()
        .map((m) {
          final enabled = m.status == DiveGasStatus.enabled;
          return FitGas(
            index: m.messageIndex ?? 0,
            o2Percent: (m.oxygenContent ?? 21).toDouble(),
            hePercent: (m.heliumContent ?? 0).toDouble(),
            enabled: enabled,
          );
        })
        .where((g) => g.enabled)
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return gases;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_import/data/services/fit/fit_gas_extractor_test.dart`
Expected: PASS

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_import/data/services/fit test/features/dive_import/data/services/fit
flutter analyze lib/features/dive_import/data/services/fit
git add lib/features/dive_import/data/services/fit test/features/dive_import/data/services/fit
git commit -m "feat(fit): extract gas mixes from dive_gas messages"
```

---

### Task 5: `FitTankExtractor` — tanks + pressure series from msgs 319/323

**Files:**
- Create: `lib/features/dive_import/data/services/fit/fit_tank_extractor.dart`
- Test: `test/features/dive_import/data/services/fit/fit_tank_extractor_test.dart`

**Interfaces:**
- Produces:
  - `class FitTank { final int sensorId; final int order; final double? startPressureBar; final double? endPressureBar; final double? volumeUsedLiters; }`
  - `class FitTankPressureSample { final int sensorId; final int timestampMs; final double pressureBar; }`
  - `class FitTankData { final List<FitTank> tanks; final List<FitTankPressureSample> pressures; int? orderForSensor(int sensorId); }`
  - `FitTankExtractor.extract(List<Message>) -> FitTankData`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_import/data/services/fit/fit_tank_extractor_test.dart
import 'package:fit_tool/fit_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_constants.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_tank_extractor.dart';

DataMessage tankSummary({
  required int sensor,
  required int startRaw,
  required int endRaw,
  required int volRaw,
}) {
  final def = DefinitionMessage(globalId: FitConstants.tankSummaryMsg, localId: 0)
    ..fieldDefinitions.addAll([
      FieldDefinition(id: 0, baseType: BaseType.uint32, size: 4),
      FieldDefinition(id: 1, baseType: BaseType.uint16, size: 2),
      FieldDefinition(id: 2, baseType: BaseType.uint16, size: 2),
      FieldDefinition(id: 3, baseType: BaseType.uint32, size: 4),
    ]);
  return GenericMessage(definitionMessage: def)
    ..setFieldValueByIndex(0, sensor)
    ..setFieldValueByIndex(1, startRaw)
    ..setFieldValueByIndex(2, endRaw)
    ..setFieldValueByIndex(3, volRaw);
}

DataMessage tankUpdate({
  required int sensor,
  required int tsRaw,
  required int pressureRaw,
}) {
  final def = DefinitionMessage(globalId: FitConstants.tankUpdateMsg, localId: 0)
    ..fieldDefinitions.addAll([
      FieldDefinition(id: 253, baseType: BaseType.uint32, size: 4),
      FieldDefinition(id: 0, baseType: BaseType.uint32, size: 4),
      FieldDefinition(id: 1, baseType: BaseType.uint16, size: 2),
    ]);
  return GenericMessage(definitionMessage: def)
    ..setFieldValueByIndex(253, tsRaw)
    ..setFieldValueByIndex(0, sensor)
    ..setFieldValueByIndex(1, pressureRaw);
}

void main() {
  test('builds a tank per sensor with scaled start/end/volume', () {
    // Bouchot 72: start 22125 -> 221.25 bar, end 8811 -> 88.11 bar,
    // volume 199350 -> 1993.5 L.
    final data = FitTankExtractor.extract([
      tankSummary(sensor: 2772884913, startRaw: 22125, endRaw: 8811, volRaw: 199350),
    ]);
    expect(data.tanks, hasLength(1));
    final t = data.tanks.single;
    expect(t.sensorId, 2772884913);
    expect(t.order, 0);
    expect(t.startPressureBar, closeTo(221.25, 1e-6));
    expect(t.endPressureBar, closeTo(88.11, 1e-6));
    expect(t.volumeUsedLiters, closeTo(1993.5, 1e-6));
  });

  test('maps each sensor to a stable tank order; pressures scaled to bar', () {
    final data = FitTankExtractor.extract([
      tankSummary(sensor: 100, startRaw: 20000, endRaw: 9000, volRaw: 100000),
      tankSummary(sensor: 200, startRaw: 21000, endRaw: 7000, volRaw: 120000),
      tankUpdate(sensor: 200, tsRaw: 1000, pressureRaw: 18000),
      tankUpdate(sensor: 100, tsRaw: 1000, pressureRaw: 19000),
    ]);
    expect(data.tanks, hasLength(2));
    expect(data.orderForSensor(100), 0);
    expect(data.orderForSensor(200), 1);
    final p = data.pressures.firstWhere((s) => s.sensorId == 200);
    expect(p.pressureBar, closeTo(180.0, 1e-6));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_import/data/services/fit/fit_tank_extractor_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/dive_import/data/services/fit/fit_tank_extractor.dart
import 'package:fit_tool/fit_tool.dart';
import 'fit_constants.dart';
import 'fit_message_access.dart';

class FitTank {
  const FitTank({
    required this.sensorId,
    required this.order,
    this.startPressureBar,
    this.endPressureBar,
    this.volumeUsedLiters,
  });

  final int sensorId;
  final int order;
  final double? startPressureBar;
  final double? endPressureBar;
  final double? volumeUsedLiters;
}

class FitTankPressureSample {
  const FitTankPressureSample({
    required this.sensorId,
    required this.timestampMs,
    required this.pressureBar,
  });

  final int sensorId;
  final int timestampMs;
  final double pressureBar;
}

class FitTankData {
  FitTankData(this.tanks, this.pressures);

  final List<FitTank> tanks;
  final List<FitTankPressureSample> pressures;

  int? orderForSensor(int sensorId) {
    for (final t in tanks) {
      if (t.sensorId == sensorId) return t.order;
    }
    return null;
  }
}

/// Extracts air-integration tanks (tank_summary, msg 323) and the pressure
/// time-series (tank_update, msg 319). fit_tool has no named class for these,
/// so they are read off GenericMessage by field number (see FitConstants).
class FitTankExtractor {
  const FitTankExtractor._();

  static FitTankData extract(List<Message> messages) {
    final summaries = FitMessageAccess.messagesWithGlobalId(
      messages,
      FitConstants.tankSummaryMsg,
    );
    final updates = FitMessageAccess.messagesWithGlobalId(
      messages,
      FitConstants.tankUpdateMsg,
    );

    // Assign a stable order per sensor in first-seen order across summaries.
    final orderBySensor = <int, int>{};
    final tanks = <FitTank>[];
    for (final m in summaries) {
      final sensor = FitMessageAccess.rawNum(m, FitConstants.tsSensor)?.toInt();
      if (sensor == null) continue;
      final order = orderBySensor.putIfAbsent(sensor, () => orderBySensor.length);
      tanks.add(
        FitTank(
          sensorId: sensor,
          order: order,
          startPressureBar: _scaled(m, FitConstants.tsStartPressure,
              FitConstants.pressureScaleBar),
          endPressureBar: _scaled(m, FitConstants.tsEndPressure,
              FitConstants.pressureScaleBar),
          volumeUsedLiters: _scaled(m, FitConstants.tsVolumeUsed,
              FitConstants.volumeScaleLiters),
        ),
      );
    }

    final pressures = <FitTankPressureSample>[];
    for (final m in updates) {
      final sensor = FitMessageAccess.rawNum(m, FitConstants.tuSensor)?.toInt();
      final pressure = _scaled(m, FitConstants.tuPressure,
          FitConstants.pressureScaleBar);
      final ts = FitMessageAccess.rawNum(m, FitConstants.tuTimestamp)?.toInt();
      if (sensor == null || pressure == null || ts == null) continue;
      // Register sensors that appear only in updates (no summary row).
      orderBySensor.putIfAbsent(sensor, () => orderBySensor.length);
      pressures.add(FitTankPressureSample(
        sensorId: sensor,
        timestampMs: ts,
        pressureBar: pressure,
      ));
    }

    return FitTankData(tanks, pressures);
  }

  static double? _scaled(DataMessage m, int fieldId, double scale) {
    final raw = FitMessageAccess.rawNum(m, fieldId);
    return raw == null ? null : raw.toDouble() / scale;
  }
}
```

> EXECUTION NOTE: the `tank_update` timestamp (field 253) is FIT-epoch *seconds*; the orchestrator (Task 9) converts to the same ms base it uses for record timestamps before merging into samples (Task 9 Step 3). Keep `timestampMs` as whatever base Task 9 expects — store raw seconds here and convert in Task 9, OR convert here consistently. Pick one and keep it consistent across Task 5 and Task 9.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_import/data/services/fit/fit_tank_extractor_test.dart`
Expected: PASS

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_import/data/services/fit test/features/dive_import/data/services/fit
flutter analyze lib/features/dive_import/data/services/fit
git add lib/features/dive_import/data/services/fit test/features/dive_import/data/services/fit
git commit -m "feat(fit): extract tanks and pressure series from msgs 319/323"
```

---

### Task 6: `FitProfileExtractor` — samples with deco fields

**Files:**
- Create: `lib/features/dive_import/data/services/fit/fit_profile_extractor.dart`
- Test: `test/features/dive_import/data/services/fit/fit_profile_extractor_test.dart`

**Interfaces:**
- Produces: `class FitSample { final int timestampMs; final double depth; final double? temperature; final int? heartRate; final double? ceiling; final int? ndlSeconds; final int? ttsSeconds; final double? cns; }`; `FitProfileExtractor.extract(List<RecordMessage>) -> List<FitSample>` (records lacking depth skipped).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_import/data/services/fit/fit_profile_extractor_test.dart
import 'package:fit_tool/fit_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_profile_extractor.dart';

void main() {
  test('extracts depth + deco fields, skips depthless records', () {
    final r1 = RecordMessage()
      ..timestamp = 1000
      ..depth = 24.257
      ..temperature = 23
      ..nextStopDepth = 6.0
      ..timeToSurface = 480
      ..ndlTime = 0
      ..cnsLoad = 15;
    final r2 = RecordMessage()..timestamp = 2000; // no depth -> skipped

    final samples = FitProfileExtractor.extract([r1, r2]);

    expect(samples, hasLength(1));
    final s = samples.single;
    expect(s.depth, closeTo(24.257, 1e-6));
    expect(s.ceiling, 6.0);
    expect(s.ttsSeconds, 480);
    expect(s.ndlSeconds, 0);
    expect(s.cns, 15);
  });
}
```

> EXECUTION NOTE: `RecordMessage` getters used (`nextStopDepth`, `timeToSurface`, `ndlTime`, `cnsLoad`, `temperature`, `heartRate`, `depth`, `timestamp`) are confirmed present in fit_tool 1.0.5 `record_message.dart`. `ceiling` = `nextStopDepth`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_import/data/services/fit/fit_profile_extractor_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/dive_import/data/services/fit/fit_profile_extractor.dart
import 'package:fit_tool/fit_tool.dart';

class FitSample {
  const FitSample({
    required this.timestampMs,
    required this.depth,
    this.temperature,
    this.heartRate,
    this.ceiling,
    this.ndlSeconds,
    this.ttsSeconds,
    this.cns,
  });

  final int timestampMs;
  final double depth;
  final double? temperature;
  final int? heartRate;
  final double? ceiling; // meters (record.nextStopDepth)
  final int? ndlSeconds; // record.ndlTime
  final int? ttsSeconds; // record.timeToSurface
  final double? cns; // percent (record.cnsLoad)
}

/// Extracts per-sample dive profile data, including the Garmin-recorded deco
/// values (ceiling/TTS/NDL/CNS). These are imported as recorded, never
/// recomputed. Records without depth are skipped.
class FitProfileExtractor {
  const FitProfileExtractor._();

  static List<FitSample> extract(List<RecordMessage> records) {
    final samples = <FitSample>[];
    for (final r in records) {
      final depth = r.depth;
      final ts = r.timestamp;
      if (depth == null || ts == null) continue;
      samples.add(FitSample(
        timestampMs: ts,
        depth: depth,
        temperature: r.temperature?.toDouble(),
        heartRate: r.heartRate,
        ceiling: r.nextStopDepth,
        ndlSeconds: r.ndlTime,
        ttsSeconds: r.timeToSurface,
        cns: r.cnsLoad?.toDouble(),
      ));
    }
    return samples;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_import/data/services/fit/fit_profile_extractor_test.dart`
Expected: PASS

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_import/data/services/fit test/features/dive_import/data/services/fit
flutter analyze lib/features/dive_import/data/services/fit
git add lib/features/dive_import/data/services/fit test/features/dive_import/data/services/fit
git commit -m "feat(fit): extract profile samples with recorded deco fields"
```

---

### Task 7: `FitSummaryExtractor` — summary/session/settings

**Files:**
- Create: `lib/features/dive_import/data/services/fit/fit_summary_extractor.dart`
- Test: `test/features/dive_import/data/services/fit/fit_summary_extractor_test.dart`

**Interfaces:**
- Produces: `class FitSummary { int? diveNumber; Duration? bottomTime; Duration? surfaceInterval; double? cnsStart; double? cnsEnd; double? otu; double? entryLat; double? entryLong; String? waterType; double? waterDensity; String? decoModel; int? gfLow; int? gfHigh; }`; `FitSummaryExtractor.extract({DiveSummaryMessage?, SessionMessage?, DiveSettingsMessage?}) -> FitSummary`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_import/data/services/fit/fit_summary_extractor_test.dart
import 'package:fit_tool/fit_tool.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_summary_extractor.dart';

void main() {
  test('extracts dive number, bottom time, SI, CNS/OTU, GPS, water type, GF', () {
    final summary = DiveSummaryMessage()
      ..diveNumber = 92
      ..bottomTime = 5168.781
      ..surfaceInterval = 167491
      ..startCns = 0
      ..endCns = 32
      ..o2Toxicity = 90;
    final session = SessionMessage()
      ..startPositionLat = 427345071 // semicircles -> ~35.815 N
      ..startPositionLong = 172412425; // ~14.451 E
    final settings = DiveSettingsMessage()
      ..waterType = WaterType.salt
      ..gfLow = 50
      ..gfHigh = 85
      ..model = TissueModelType.zhl16c;

    final s = FitSummaryExtractor.extract(
      summary: summary,
      session: session,
      settings: settings,
    );

    expect(s.diveNumber, 92);
    expect(s.bottomTime, const Duration(seconds: 5168));
    expect(s.surfaceInterval, const Duration(seconds: 167491));
    expect(s.cnsEnd, 32);
    expect(s.otu, 90);
    expect(s.entryLat, closeTo(35.815, 0.01));
    expect(s.entryLong, closeTo(14.451, 0.01));
    expect(s.waterType, 'salt');
    expect(s.gfLow, 50);
    expect(s.gfHigh, 85);
  });
}
```

> EXECUTION NOTE: confirm fit_tool getter/enum names: `DiveSummaryMessage` (`diveNumber`, `bottomTime`, `surfaceInterval`, `startCns`, `endCns`, `o2Toxicity`), `SessionMessage` (`startPositionLat`/`Long` — already used in current parser as degrees? Verify whether fit_tool returns DEGREES or SEMICIRCLES: the existing `fit_parser_service.dart` reads `session.startPositionLat` directly as the GPS value, so fit_tool likely already converts to degrees. If so, DROP the semicircle conversion and assert the degree value fit_tool returns; if it returns raw semicircles, apply `FitConstants.semicircleToDegrees`.), `DiveSettingsMessage` (`waterType`, `waterDensity`, `gfLow`, `gfHigh`, `model`). Map `WaterType.salt/fresh/brackish` enum -> lowercase name string. Map `model` enum -> `'zhl_16c'` string for `decoAlgorithm`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_import/data/services/fit/fit_summary_extractor_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/features/dive_import/data/services/fit/fit_summary_extractor.dart
import 'package:fit_tool/fit_tool.dart';

class FitSummary {
  FitSummary({
    this.diveNumber,
    this.bottomTime,
    this.surfaceInterval,
    this.cnsStart,
    this.cnsEnd,
    this.otu,
    this.entryLat,
    this.entryLong,
    this.waterType,
    this.waterDensity,
    this.decoModel,
    this.gfLow,
    this.gfHigh,
  });

  final int? diveNumber;
  final Duration? bottomTime;
  final Duration? surfaceInterval;
  final double? cnsStart;
  final double? cnsEnd;
  final double? otu;
  final double? entryLat;
  final double? entryLong;
  final String? waterType;
  final double? waterDensity;
  final String? decoModel;
  final int? gfLow;
  final int? gfHigh;
}

/// Extracts dive-level fields from `dive_summary` (msg 268), `session`
/// (msg 18) and `dive_settings` (msg 258).
class FitSummaryExtractor {
  const FitSummaryExtractor._();

  static FitSummary extract({
    DiveSummaryMessage? summary,
    SessionMessage? session,
    DiveSettingsMessage? settings,
  }) {
    Duration? secs(num? v) => v == null ? null : Duration(seconds: v.round());
    return FitSummary(
      diveNumber: summary?.diveNumber,
      bottomTime: secs(summary?.bottomTime),
      surfaceInterval: secs(summary?.surfaceInterval),
      cnsStart: summary?.startCns?.toDouble(),
      cnsEnd: summary?.endCns?.toDouble(),
      otu: summary?.o2Toxicity?.toDouble(),
      entryLat: session?.startPositionLat,
      entryLong: session?.startPositionLong,
      waterType: settings?.waterType?.name,
      waterDensity: settings?.waterDensity,
      decoModel: settings?.model == null ? null : 'zhl_16c',
      gfLow: settings?.gfLow,
      gfHigh: settings?.gfHigh,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_import/data/services/fit/fit_summary_extractor_test.dart`
Expected: PASS

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_import/data/services/fit test/features/dive_import/data/services/fit
flutter analyze lib/features/dive_import/data/services/fit
git add lib/features/dive_import/data/services/fit test/features/dive_import/data/services/fit
git commit -m "feat(fit): extract dive summary/session/settings fields"
```

---

## Phase 3 — Model, orchestrator, payload

### Task 8: Extend `ImportedDive` model

**Files:**
- Modify: `lib/features/dive_import/domain/entities/imported_dive.dart`
- Test: `test/features/dive_import/domain/entities/imported_dive_test.dart` (add cases)

**Interfaces:**
- Produces: `ImportedTank`, `ImportedTankPressureSample`, extended `ImportedDive` and `ImportedProfileSample` with the new fields below.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_import/domain/entities/imported_dive_test.dart (add)
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';

void main() {
  test('ImportedDive carries enriched fields', () {
    const dive = ImportedDive(
      sourceId: 'garmin-1-2',
      sourceUuid: 'garmin-1-2',
      source: ImportSource.garmin,
      startTime: null,
      endTime: null,
      maxDepth: 34.2,
      diveNumber: 92,
      bottomTimeSeconds: 5168,
      surfaceIntervalSeconds: 167491,
      cnsEnd: 32,
      otu: 90,
      waterType: 'salt',
      decoModel: 'zhl_16c',
      gfLow: 50,
      gfHigh: 85,
      computerModel: 'Descent Mk3i',
      tanks: [
        ImportedTank(order: 0, startPressureBar: 221.25, endPressureBar: 88.11,
            o2Percent: 30, hePercent: 0),
      ],
      profile: [
        ImportedProfileSample(
          timeSeconds: 0, depth: 1.6, ceiling: 0, ndlSeconds: 0,
          tankPressures: [ImportedTankPressureSample(tankIndex: 0, pressureBar: 221.25)],
        ),
      ],
    );
    expect(dive.diveNumber, 92);
    expect(dive.tanks.single.startPressureBar, 221.25);
    expect(dive.profile.single.tankPressures!.single.pressureBar, 221.25);
  });
}
```

> NOTE: `startTime`/`endTime` become nullable here only if the existing model allows it; if they must stay required `DateTime`, keep them required in the test (pass concrete DateTimes). Match the existing required/optional shape — do not loosen required fields unnecessarily.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_import/domain/entities/imported_dive_test.dart`
Expected: FAIL — new fields/classes do not exist.

- [ ] **Step 3: Write minimal implementation**

Add to `imported_dive.dart` (extend the existing classes; keep all current fields and `props`):

```dart
class ImportedTank extends Equatable {
  const ImportedTank({
    required this.order,
    this.startPressureBar,
    this.endPressureBar,
    this.volumeUsedLiters,
    this.o2Percent,
    this.hePercent,
  });

  final int order;
  final double? startPressureBar;
  final double? endPressureBar;
  final double? volumeUsedLiters;
  final double? o2Percent;
  final double? hePercent;

  @override
  List<Object?> get props =>
      [order, startPressureBar, endPressureBar, volumeUsedLiters, o2Percent, hePercent];
}

class ImportedTankPressureSample extends Equatable {
  const ImportedTankPressureSample({
    required this.tankIndex,
    required this.pressureBar,
  });

  final int tankIndex;
  final double pressureBar;

  @override
  List<Object?> get props => [tankIndex, pressureBar];
}
```

Add these fields to `ImportedDive` (with constructor params + `props`): `final String? sourceUuid; final int? diveNumber; final int? bottomTimeSeconds; final int? surfaceIntervalSeconds; final double? cnsStart; final double? cnsEnd; final double? otu; final String? waterType; final String? decoModel; final int? gfLow; final int? gfHigh; final String? computerModel; final String? computerSerial; final String? computerFirmware; final double? exitLatitude; final double? exitLongitude; final List<ImportedTank> tanks;` (default `const []`).

Add to `ImportedProfileSample` (with params + `props`): `final double? cns; final int? ndlSeconds; final int? ttsSeconds; final double? ceiling; final List<ImportedTankPressureSample>? tankPressures;`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_import/domain/entities/imported_dive_test.dart`
Expected: PASS

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_import/domain/entities test/features/dive_import/domain/entities
flutter analyze lib/features/dive_import/domain/entities
git add lib/features/dive_import/domain/entities test/features/dive_import/domain/entities
git commit -m "feat(fit): extend ImportedDive with tanks/deco/summary fields"
```

---

### Task 9: Rewrite `FitParserService` as orchestrator (+ merge tank pressures into samples)

**Files:**
- Modify: `lib/features/dive_import/data/services/fit_parser_service.dart`
- Test: `test/features/dive_import/data/services/fit_parser_service_test.dart` (extend the existing synthetic-FIT tests)

**Interfaces:**
- Consumes: all extractors from Phase 1–2; `ImportedDive` from Task 8.
- Produces: enriched `ImportedDive` from `parseFitFile`.

**Tank-pressure → sample merge (the key logic):** the importer reads per-sample tank pressure from each profile point's `allTankPressures`. FIT `tank_update` is a separate, sparser series, so the orchestrator merges each pressure sample onto the profile sample at the same whole-second offset from dive start (nearest within ±2 s), tagged with the sensor's tank order.

- [ ] **Step 1: Write the failing test** (extend existing file)

```dart
// test/features/dive_import/data/services/fit_parser_service_test.dart (add)
test('enriched parse surfaces tanks, gas, deco, dive number, GPS', () async {
  // buildTestDiveFitFile is the existing synthetic builder. Extend it (or add
  // buildRichDiveFitFile) to also append: DiveSummaryMessage(diveNumber:73,
  // bottomTime, surfaceInterval, endCns, o2Toxicity), DiveSettingsMessage
  // (waterType:salt, gfLow:50, gfHigh:85), DiveGasMessage(o2:28), a
  // tank_summary GenericMessage, and records with nextStopDepth/ndlTime.
  final bytes = buildRichDiveFitFile();
  final dive = await const FitParserService().parseFitFile(bytes);

  expect(dive, isNotNull);
  expect(dive!.diveNumber, 73);
  expect(dive.waterType, 'salt');
  expect(dive.gfLow, 50);
  expect(dive.tanks, isNotEmpty);
  expect(dive.tanks.first.startPressureBar, isNotNull);
  expect(dive.profile.any((s) => s.ceiling != null), isTrue);
  expect(dive.sourceUuid, dive.sourceId);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_import/data/services/fit_parser_service_test.dart`
Expected: FAIL — orchestrator doesn't populate the new fields yet.

- [ ] **Step 3: Rewrite `parseFitFile`** to: collect messages once; find session/fileId/activity/diveSummary/diveSettings; run `FitGasExtractor`, `FitTankExtractor`, `FitProfileExtractor`, `FitSummaryExtractor`, `FitTimeResolver`, `FitDeviceMapper`; merge tank pressures into samples by second; build the enriched `ImportedDive` (set `sourceUuid = sourceId`, map gases→tanks by order, set computer model from `FitDeviceMapper`). Keep the existing non-dive/corrupt/empty guards. Preserve `_buildProfile`'s depth/temp/HR and add ceiling/ndl/tts/cns + `tankPressures`.

Merge helper (real code to include):

```dart
// Inside FitParserService: attach tank pressures to samples by whole-second.
List<ImportedProfileSample> _mergeTankPressures(
  List<ImportedProfileSample> samples,
  FitTankData tankData,
  int startMs,
) {
  if (tankData.pressures.isEmpty) return samples;
  // Bucket pressures by (second-from-start, tankIndex) -> pressureBar.
  final byKey = <int, List<ImportedTankPressureSample>>{};
  for (final p in tankData.pressures) {
    final order = tankData.orderForSensor(p.sensorId);
    if (order == null) continue;
    final sec = ((p.timestampMs - startMs) / 1000).round();
    (byKey[sec] ??= []).add(
      ImportedTankPressureSample(tankIndex: order, pressureBar: p.pressureBar),
    );
  }
  return samples.map((s) {
    final tp = byKey[s.timeSeconds];
    return tp == null ? s : s.copyWith(tankPressures: tp);
  }).toList();
}
```

> NOTE: `ImportedProfileSample` needs a `copyWith` for `tankPressures` (add it in Task 8 if absent). Keep the `timestampMs`/`startMs` base consistent with Task 5 (resolve the Task 5 note here).

- [ ] **Step 4: Run tests to verify they pass** (existing + new)

Run: `flutter test test/features/dive_import/data/services/fit_parser_service_test.dart`
Expected: PASS (all existing cases still green + new case)

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_import/data/services test/features/dive_import/data/services
flutter analyze lib/features/dive_import
git add lib/features/dive_import/data/services test/features/dive_import/data/services
git commit -m "feat(fit): orchestrate extractors into enriched ImportedDive"
```

---

### Task 10: `FitImportParser` emits the UDDF-shaped payload

**Files:**
- Modify: `lib/features/universal_import/data/parsers/fit_import_parser.dart`
- Test: `test/features/universal_import/data/parsers/fit_import_parser_test.dart` (new)

**Interfaces:**
- Consumes: enriched `ImportedDive`.
- Produces: `ImportPayload` whose dive map carries the keys `UddfEntityImporter` reads: `dateTime, duration` (=bottomTime Duration), `runtime` (=elapsed Duration), `maxDepth, avgDepth, waterTemp, waterType, diveNumber, surfaceInterval` (Duration), `decoAlgorithm, gradientFactorLow, gradientFactorHigh, diveComputerModel/Serial/Firmware, cnsEnd, otu, sourceUuid, latitude, longitude`, `tanks` (list of maps with `startPressure/endPressure/gasMix/order`), and `profile` points with `timestamp, depth, temperature, heartRate, cns, ndl, tts, ceiling, allTankPressures`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/universal_import/data/parsers/fit_import_parser_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/fit_import_parser.dart';
// Use the same synthetic builder as the parser-service test (buildRichDiveFitFile).

void main() {
  test('emits UDDF-shaped payload with tanks, deco, gps, sourceUuid', () async {
    final payload = await const FitImportParser().parse(buildRichDiveFitFile());
    final dives = payload.entities[ImportEntityType.dives]!;
    final d = dives.single;

    expect(d['diveNumber'], isNotNull);
    expect(d['waterType'], 'salt');
    expect(d['surfaceInterval'], isA<Duration>());
    expect(d['duration'], isA<Duration>()); // bottom time
    expect(d['runtime'], isA<Duration>());  // total elapsed
    expect(d['sourceUuid'], d['sourceId']);
    expect(d['tanks'], isA<List<Map<String, dynamic>>>());
    expect((d['tanks'] as List).first['startPressure'], isNotNull);
    final profile = d['profile'] as List<Map<String, dynamic>>;
    expect(profile.any((p) => p['ceiling'] != null), isTrue);
    expect(profile.any((p) => p['allTankPressures'] != null), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/universal_import/data/parsers/fit_import_parser_test.dart`
Expected: FAIL — parser still emits the minimal payload.

- [ ] **Step 3: Rewrite `parse()`** to build the dive map from the enriched `ImportedDive`. Real mapping (key lines):

```dart
final diveData = <String, dynamic>{
  'dateTime': dive.startTime,
  'maxDepth': dive.maxDepth,
  'avgDepth': dive.avgDepth,
  'duration': dive.bottomTimeSeconds != null
      ? Duration(seconds: dive.bottomTimeSeconds!)
      : dive.duration, // bottom time; fall back to elapsed
  'runtime': dive.duration, // total elapsed
  'waterTemp': dive.minTemperature,
  'sourceId': dive.sourceId,
  'sourceUuid': dive.sourceUuid ?? dive.sourceId,
};
if (dive.diveNumber != null) diveData['diveNumber'] = dive.diveNumber;
if (dive.surfaceIntervalSeconds != null) {
  diveData['surfaceInterval'] = Duration(seconds: dive.surfaceIntervalSeconds!);
}
if (dive.waterType != null) diveData['waterType'] = dive.waterType;
if (dive.decoModel != null) diveData['decoAlgorithm'] = dive.decoModel;
if (dive.gfLow != null) diveData['gradientFactorLow'] = dive.gfLow;
if (dive.gfHigh != null) diveData['gradientFactorHigh'] = dive.gfHigh;
if (dive.cnsEnd != null) diveData['cnsEnd'] = dive.cnsEnd;
if (dive.otu != null) diveData['otu'] = dive.otu;
if (dive.computerModel != null) diveData['diveComputerModel'] = dive.computerModel;
if (dive.computerSerial != null) diveData['diveComputerSerial'] = dive.computerSerial;
if (dive.computerFirmware != null) {
  diveData['diveComputerFirmware'] = dive.computerFirmware;
}
if (dive.latitude != null && dive.longitude != null) {
  diveData['latitude'] = dive.latitude;
  diveData['longitude'] = dive.longitude;
}
if (dive.exitLatitude != null && dive.exitLongitude != null) {
  diveData['exitLatitude'] = dive.exitLatitude;
  diveData['exitLongitude'] = dive.exitLongitude;
}
if (dive.tanks.isNotEmpty) {
  diveData['tanks'] = dive.tanks
      .map((t) => <String, dynamic>{
            'order': t.order,
            'startPressure': t.startPressureBar,
            'endPressure': t.endPressureBar,
            if (t.o2Percent != null || t.hePercent != null)
              'gasMix': GasMix(o2: t.o2Percent ?? 21.0, he: t.hePercent ?? 0.0),
          })
      .toList();
}
if (dive.profile.isNotEmpty) {
  diveData['profile'] = dive.profile.map((s) {
    final point = <String, dynamic>{'timestamp': s.timeSeconds, 'depth': s.depth};
    if (s.temperature != null) point['temperature'] = s.temperature;
    if (s.heartRate != null) point['heartRate'] = s.heartRate;
    if (s.cns != null) point['cns'] = s.cns;
    if (s.ndlSeconds != null) point['ndl'] = s.ndlSeconds;
    if (s.ttsSeconds != null) point['tts'] = s.ttsSeconds;
    if (s.ceiling != null) point['ceiling'] = s.ceiling;
    if (s.tankPressures != null && s.tankPressures!.isNotEmpty) {
      point['allTankPressures'] = s.tankPressures!
          .map((tp) => <String, dynamic>{
                'tankIndex': tp.tankIndex,
                'pressure': tp.pressureBar,
              })
          .toList();
    }
    return point;
  }).toList();
}
```

> NOTE: import `GasMix` from its domain entity. `tanks`/`profile`/`allTankPressures` MUST be typed `List<Map<String, dynamic>>` (the importer casts to exactly that — see `uddf_entity_importer.dart:1543,1000,1661`); use `.cast<Map<String, dynamic>>()` or construct as such, or the runtime cast throws.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/universal_import/data/parsers/fit_import_parser_test.dart`
Expected: PASS

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/universal_import/data/parsers test/features/universal_import/data/parsers
flutter analyze lib/features/universal_import
git add lib/features/universal_import/data/parsers test/features/universal_import/data/parsers
git commit -m "feat(fit): emit UDDF-shaped payload with tanks/deco/gps/sourceUuid"
```

---

## Phase 4 — Importer persistence gap-fixes

### Task 11: Import the recorded `ceiling` into profile points

**Files:**
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart:1009` (profile mapping)
- Test: `test/features/dive_import/data/services/uddf_entity_importer_*_test.dart` (add a focused case or extend an existing importer test)

**Interfaces:**
- Consumes: `profile` point key `ceiling` (double). Produces: `DiveProfilePoint.ceiling` populated → persisted by `createDive`.

- [ ] **Step 1: Write the failing test** — import a payload whose profile point has `ceiling: 6.0`; assert the persisted dive's `profile.first.ceiling == 6.0`. (Use the existing importer test harness/in-memory DB; mirror an existing profile-assertion test.)

- [ ] **Step 2: Run it to verify it fails** (ceiling comes back null).

Run: `flutter test <the importer test file>`
Expected: FAIL — ceiling is null.

- [ ] **Step 3: Add one line** to the `DiveProfilePoint` mapping (after `ndl:`/`tts:` at ~line 1011):

```dart
                  ceiling: asDoubleOrNull(p['ceiling']),
```

- [ ] **Step 4: Run it to verify it passes.**

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_import/data/services test/features/dive_import
flutter analyze lib/features/dive_import
git add lib/features/dive_import
git commit -m "fix(import): persist recorded deco ceiling from profile points"
```

---

### Task 12: Persist entry/exit GPS on import (the FIT GPS fix)

**Files:**
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart` (the `Dive(...)` constructor, ~1135-1204)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (the `createDive` companion, ~674-754)
- Test: `test/features/dive_log/data/repositories/dive_repository_impl_test.dart` (createDive persists location) + importer test (lat/long → entryLocation)

**Interfaces:**
- Consumes: dive map keys `latitude`/`longitude`/`exitLatitude`/`exitLongitude`. Produces: `Dives.entryLatitude/entryLongitude/exitLatitude/exitLongitude` populated → dive becomes eligible for `getDivesNeedingSiteMatch`.

- [ ] **Step 1: Write the failing tests**

```dart
// dive_repository_impl_test.dart (add): createDive persists entryLocation.
test('createDive persists entryLocation to lat/long columns', () async {
  final dive = makeTestDive().copyWith(
    entryLocation: const GeoPoint(35.815, 14.451),
  );
  await repository.createDive(dive);
  final loaded = await repository.getDiveById(dive.id);
  expect(loaded!.entryLocation, isNotNull);
  expect(loaded.entryLocation!.latitude, closeTo(35.815, 1e-6));
});
```

```dart
// importer test (add): latitude/longitude in the dive map -> entryLocation.
test('import maps latitude/longitude to entryLocation', () async {
  // import a dives payload with {'latitude': 35.815, 'longitude': 14.451, ...}
  // then load the dive and assert entryLocation is set.
});
```

- [ ] **Step 2: Run them to verify they fail.**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_impl_test.dart`
Expected: FAIL — `entryLocation` is null after reload.

- [ ] **Step 3a: Persist location in `createDive`** — add to the `DivesCompanion` insert (after `surfacePressure:` ~line 704):

```dart
              entryLatitude: Value(dive.entryLocation?.latitude),
              entryLongitude: Value(dive.entryLocation?.longitude),
              exitLatitude: Value(dive.exitLocation?.latitude),
              exitLongitude: Value(dive.exitLocation?.longitude),
```

- [ ] **Step 3b: Set location on the Dive in the importer** — add to the `Dive(...)` constructor (after `altitude:` ~line 1184):

```dart
        entryLocation:
            asDoubleOrNull(diveData['latitude']) != null &&
                asDoubleOrNull(diveData['longitude']) != null
            ? GeoPoint(
                asDoubleOrNull(diveData['latitude'])!,
                asDoubleOrNull(diveData['longitude'])!,
              )
            : null,
        exitLocation:
            asDoubleOrNull(diveData['exitLatitude']) != null &&
                asDoubleOrNull(diveData['exitLongitude']) != null
            ? GeoPoint(
                asDoubleOrNull(diveData['exitLatitude'])!,
                asDoubleOrNull(diveData['exitLongitude'])!,
              )
            : null,
```

> NOTE: import `GeoPoint` (from `dive_site.dart`/the domain). Confirm the constructor is positional `GeoPoint(lat, lng)` (verified at `dive_repository_impl.dart:2202`).

- [ ] **Step 4: Run tests to verify they pass.**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_impl_test.dart`
Expected: PASS

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_import lib/features/dive_log test/features/dive_log test/features/dive_import
flutter analyze lib/features/dive_import lib/features/dive_log
git add lib/features/dive_import lib/features/dive_log test/features/dive_log test/features/dive_import
git commit -m "fix(import): persist entry/exit GPS so dives reach site matching"
```

---

## Phase 5 — GPS site-match wiring for dive-computer downloads (#310)

### Task 13: Surface the existing "Match Sites" affordance after a DC download

**Files:**
- Modify: the dive-computer post-download results widget (locate via `lib/features/dive_computer/presentation/` — the screen shown after a successful download, holding the imported dive IDs).
- Test: a widget test for that screen (mirror any existing download-results widget test).

**Interfaces:**
- Consumes: `eligibleImportedDivesProvider(ImportedDiveIds(importedDiveIds))` (from `lib/features/dive_sites/presentation/providers/site_match_review_notifier.dart`). Produces: a button → `context.push('/dives/match-sites', extra: ids)`.

- [ ] **Step 1: Write the failing widget test** — pump the download-results widget with ≥1 imported dive ID that has GPS but no site; assert a "Match Sites" button is shown. (FIT already gets this via `import_summary_step.dart`; this task is the DC parity for #310.)

- [ ] **Step 2: Run it to verify it fails.**

Run: `flutter test <the download-results widget test>`
Expected: FAIL — no Match Sites button.

- [ ] **Step 3: Add the affordance** — mirror `import_summary_step.dart:188-215` exactly:

```dart
Consumer(
  builder: (context, ref, _) {
    if (importedDiveIds.isEmpty) return const SizedBox.shrink();
    final eligible = ref.watch(
      eligibleImportedDivesProvider(ImportedDiveIds(importedDiveIds)),
    );
    return eligible.maybeWhen(
      data: (ids) => ids.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 12),
              child: FilledButton.icon(
                icon: const Icon(Icons.add_location_alt_outlined),
                label: Text(context.l10n.importSummary_matchSitesButton(ids.length)),
                onPressed: () => context.push('/dives/match-sites', extra: ids),
              ),
            ),
      orElse: () => const SizedBox.shrink(),
    );
  },
),
```

> NOTE: reuses the existing `importSummary_matchSitesButton` l10n string — no new strings. Confirm the download-results widget already has the list of imported dive IDs; if not, thread it through from the download provider (`download_providers.dart`).

- [ ] **Step 4: Run it to verify it passes.**

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_computer test/features/dive_computer
flutter analyze lib/features/dive_computer
git add lib/features/dive_computer test/features/dive_computer
git commit -m "feat(dc): offer site matching after dive-computer download (#310)"
```

---

## Phase 6 — End-to-end integration

### Task 14: Golden integration test (FIT → importer → DB)

**Files:**
- Test: `test/features/dive_import/fit_import_integration_test.dart` (new)

- [ ] **Step 1: Write the test** — build a rich synthetic Garmin FIT (multi-gas, deco samples, ≥1 tank_summary + tank_update, GPS, dive number, CNS/OTU), run `FitImportParser().parse(...)`, feed the payload through `UddfEntityImporter` (in-memory DB, mirror the existing importer test setup), then assert the persisted dive: `diveNumber`, `bottomTime != runtime`, `waterType == salt`, ≥1 tank with start/end pressure, ≥1 `TankPressureProfiles` row, profile points with `ceiling`/`ndl`/`tts`/`cns`, `entryLocation` set, and the `DiveDataSources` row carrying `cns`/`otu`. Finally assert the dive is returned by `getDivesNeedingSiteMatch` (GPS present, no site).

- [ ] **Step 2: Run it to verify it fails** (if any wiring is incomplete).

Run: `flutter test test/features/dive_import/fit_import_integration_test.dart`
Expected: FAIL initially if any gap remains; otherwise PASS.

- [ ] **Step 3: Fix any gaps** surfaced (e.g., a missing payload key or importer mapping). No new code if Phases 1–5 are complete.

- [ ] **Step 4: Run it to verify it passes.**

- [ ] **Step 5: Run the full affected suites, format, analyze, commit**

```bash
flutter test test/features/dive_import test/features/universal_import
dart format lib test
flutter analyze
git add test/features/dive_import
git commit -m "test(fit): end-to-end Garmin FIT import integration"
```

---

## Phase 7 — Optional realistic fixtures

### Task 15 (optional): Sanitized real-file golden test

**Files:**
- Create: `test/fixtures/fit/` with 1–2 sanitized real `.fit` files (serials zeroed); a golden test asserting the same fields as Task 14 against real firmware output.

- [ ] **Step 1:** Write a small sanitizer (scratchpad Python) that zeroes the `file_id`/`device_info` serial numbers (and recomputes the trailing CRC) on copies of the user's files from `/Users/ericgriffin/Desktop/Garmin_files`. Verify with `fitparse` that messages still decode and serials read 0.
- [ ] **Step 2:** Commit the sanitized fixtures + a golden test mirroring Task 14 but loading the real bytes. Assert tanks/deco/GPS/CNS extract correctly (cross-check expected values from the decode notes: Bouchot 72 start 221.25 bar / end 88.11 bar).
- [ ] **Step 3:** `flutter test test/features/dive_import/fit_real_fixture_test.dart`; format; analyze; commit.

> If sanitization proves fiddly (CRC/field-offset edits), keep coverage on the synthetic golden test (Task 14) and skip this task — note the gap rather than committing un-sanitized real serials.

---

## Self-Review (completed)

- **Spec coverage:** tank/AI (T5,8,9,10,14), gas (T4,9,10), deco ceiling/TTS/NDL (T6,9,10,11,14), CNS/OTU (T7,9,10,14), heart rate (T6,9,10), dive number (T7,9,10), bottom time≠runtime (T9,10,14), surface interval (T7,9,10), water type (T7,9,10), deco model/GF (T7,9,10), computer model (T3,9,10), timezone via local_timestamp (T2,9), sourceUuid fix (T8,9,10), GPS onto dive + match wiring (T12,13,14), reuse existing matcher (T13, no new matcher). All spec sections map to tasks.
- **Placeholder scan:** no "TBD"/"add error handling"-style steps; each code step shows real code. Library-API uncertainties are flagged as explicit EXECUTION NOTES with the file to verify against and the invariant the test pins — not placeholders.
- **Type consistency:** `ImportedTank`/`ImportedTankPressureSample`/`FitTankData.orderForSensor` names are consistent across T5/T8/T9; payload keys (`tanks`, `allTankPressures`/`tankIndex`/`pressure`, `ceiling`, `duration`=bottom, `runtime`=elapsed, `sourceUuid`) match exactly what `uddf_entity_importer.dart` reads (verified line refs).

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-06-22-garmin-fit-import.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
