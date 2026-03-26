# Consolidation Comparison Card Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the side-by-side consolidation comparison card with a hybrid card that shows shared data once, overlays dive profiles, highlights only differences, and explains each action — shared across both dive computer download and file import flows.

**Architecture:** A normalized `IncomingDiveData` model bridges the two data sources (`DownloadedDive` and `Map<String, dynamic>`). A pure `compareForConsolidation()` function produces a `DiveComparisonResult` with same/diff fields. A reusable `DiveComparisonCard` `ConsumerWidget` renders the hybrid layout, used by both `SummaryStepWidget` (computer download) and `ImportDiveCard` (file import).

**Tech Stack:** Flutter, Riverpod, fl_chart, Drift (existing providers)

**Spec:** `docs/superpowers/specs/2026-03-20-consolidation-comparison-card-redesign.md`

---

### Task 1: IncomingDiveData Model

**Files:**
- Create: `lib/core/domain/models/incoming_dive_data.dart`
- Create: `test/core/domain/models/incoming_dive_data_test.dart`

- [ ] **Step 1: Write failing tests for `IncomingDiveData.fromDownloadedDive`**

```dart
// test/core/domain/models/incoming_dive_data_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/models/incoming_dive_data.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

void main() {
  group('IncomingDiveData.fromDownloadedDive', () {
    test('maps all fields from DownloadedDive and DiveComputer', () {
      final dive = DownloadedDive(
        startTime: DateTime(2026, 3, 19, 22, 23),
        durationSeconds: 60,
        maxDepth: 2.2,
        avgDepth: 1.5,
        minTemperature: 26.0,
        profile: [
          ProfileSample(timeSeconds: 0, depth: 0.0),
          ProfileSample(timeSeconds: 30, depth: 2.2),
          ProfileSample(timeSeconds: 60, depth: 0.0),
        ],
      );
      final computer = DiveComputer(
        id: 'c1',
        name: 'Eric',
        model: 'Teric',
        manufacturer: 'Shearwater',
        serialNumber: '2354046563',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = IncomingDiveData.fromDownloadedDive(
        dive,
        computer: computer,
      );

      expect(result.startTime, DateTime(2026, 3, 19, 22, 23));
      expect(result.maxDepth, 2.2);
      expect(result.avgDepth, 1.5);
      expect(result.durationSeconds, 60);
      expect(result.waterTemp, 26.0);
      expect(result.computerModel, 'Shearwater Teric');
      expect(result.computerSerial, '2354046563');
      expect(result.profile, hasLength(3));
      expect(result.profile[1].timestamp, 30);
      expect(result.profile[1].depth, 2.2);
    });

    test('handles null computer gracefully', () {
      final dive = DownloadedDive(
        startTime: DateTime(2026, 3, 19),
        durationSeconds: 120,
        maxDepth: 10.0,
        profile: const [],
      );

      final result = IncomingDiveData.fromDownloadedDive(dive);

      expect(result.computerModel, isNull);
      expect(result.computerSerial, isNull);
      expect(result.profile, isEmpty);
    });
  });

  group('IncomingDiveData.fromImportMap', () {
    test('maps all fields from import map', () {
      final data = <String, dynamic>{
        'dateTime': DateTime(2026, 3, 19, 22, 23),
        'maxDepth': 15.5,
        'avgDepth': 10.2,
        'runtime': const Duration(minutes: 45),
        'duration': const Duration(minutes: 42),
        'waterTemp': 24.0,
        'diveComputerModel': 'Teric',
        'diveComputerSerial': '12345',
        'siteName': 'Blue Hole',
      };

      final result = IncomingDiveData.fromImportMap(data);

      expect(result.startTime, DateTime(2026, 3, 19, 22, 23));
      expect(result.maxDepth, 15.5);
      expect(result.avgDepth, 10.2);
      expect(result.durationSeconds, 45 * 60); // prefers runtime
      expect(result.waterTemp, 24.0);
      expect(result.computerModel, 'Teric');
      expect(result.computerSerial, '12345');
      expect(result.siteName, 'Blue Hole');
    });

    test('falls back to duration when runtime is null', () {
      final data = <String, dynamic>{
        'dateTime': DateTime(2026, 3, 19),
        'maxDepth': 10.0,
        'duration': const Duration(minutes: 30),
      };

      final result = IncomingDiveData.fromImportMap(data);

      expect(result.durationSeconds, 30 * 60);
    });

    test('converts profile map list to DiveProfilePoint', () {
      final data = <String, dynamic>{
        'dateTime': DateTime(2026, 3, 19),
        'maxDepth': 10.0,
        'profile': [
          {'timestamp': 0, 'depth': 0.0},
          {'timestamp': 60, 'depth': 10.0},
        ],
      };

      final result = IncomingDiveData.fromImportMap(data);

      expect(result.profile, hasLength(2));
      expect(result.profile[0].timestamp, 0);
      expect(result.profile[1].depth, 10.0);
    });

    test('handles missing optional fields', () {
      final data = <String, dynamic>{
        'dateTime': DateTime(2026, 3, 19),
        'maxDepth': 5.0,
      };

      final result = IncomingDiveData.fromImportMap(data);

      expect(result.avgDepth, isNull);
      expect(result.waterTemp, isNull);
      expect(result.computerModel, isNull);
      expect(result.computerSerial, isNull);
      expect(result.siteName, isNull);
      expect(result.profile, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/domain/models/incoming_dive_data_test.dart`
Expected: compilation error — `IncomingDiveData` does not exist yet.

- [ ] **Step 3: Implement IncomingDiveData**

```dart
// lib/core/domain/models/incoming_dive_data.dart
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

/// Normalized representation of an incoming dive from any import source.
///
/// Bridges [DownloadedDive] (dive computer download) and the
/// `Map<String, dynamic>` format (file import) so comparison logic
/// and the [DiveComparisonCard] can work with a single type.
class IncomingDiveData {
  final DateTime? startTime;
  final double? maxDepth;
  final double? avgDepth;
  final int? durationSeconds;
  final double? waterTemp;
  final String? computerModel;
  final String? computerSerial;
  final List<DiveProfilePoint> profile;
  final String? siteName;

  const IncomingDiveData({
    this.startTime,
    this.maxDepth,
    this.avgDepth,
    this.durationSeconds,
    this.waterTemp,
    this.computerModel,
    this.computerSerial,
    this.profile = const [],
    this.siteName,
  });

  /// Create from a [DownloadedDive] (dive computer download flow).
  factory IncomingDiveData.fromDownloadedDive(
    DownloadedDive dive, {
    DiveComputer? computer,
  }) {
    return IncomingDiveData(
      startTime: dive.startTime,
      maxDepth: dive.maxDepth,
      avgDepth: dive.avgDepth,
      durationSeconds: dive.durationSeconds,
      waterTemp: dive.minTemperature,
      computerModel: computer?.fullName,
      computerSerial: computer?.serialNumber,
      profile: dive.profile
          .map(
            (s) => DiveProfilePoint(
              timestamp: s.timeSeconds,
              depth: s.depth,
            ),
          )
          .toList(),
    );
  }

  /// Create from an import map (file import flow).
  ///
  /// Prefers `runtime` over `duration` for the duration field.
  /// Computer fields use `diveComputerModel` / `diveComputerSerial` keys
  /// (only populated by UDDF parsers).
  factory IncomingDiveData.fromImportMap(Map<String, dynamic> data) {
    final runtime = data['runtime'] as Duration?;
    final duration = data['duration'] as Duration?;
    final effectiveDuration = runtime ?? duration;

    final profileMaps = data['profile'] as List?;
    final profile = profileMaps
            ?.map(
              (p) => DiveProfilePoint(
                timestamp: (p as Map)['timestamp'] as int,
                depth: (p['depth'] as num).toDouble(),
              ),
            )
            .toList() ??
        const [];

    return IncomingDiveData(
      startTime: data['dateTime'] as DateTime?,
      maxDepth: (data['maxDepth'] as num?)?.toDouble(),
      avgDepth: (data['avgDepth'] as num?)?.toDouble(),
      durationSeconds: effectiveDuration?.inSeconds,
      waterTemp: (data['waterTemp'] as num?)?.toDouble(),
      computerModel: data['diveComputerModel'] as String?,
      computerSerial: data['diveComputerSerial'] as String?,
      siteName: data['siteName'] as String?,
      profile: profile,
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/domain/models/incoming_dive_data_test.dart`
Expected: All 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/domain/models/incoming_dive_data.dart test/core/domain/models/incoming_dive_data_test.dart
git commit -m "feat: add IncomingDiveData normalization model with factory constructors"
```

---

### Task 2: DiveComparisonResult and compareForConsolidation()

**Files:**
- Create: `lib/core/domain/models/dive_comparison_result.dart`
- Create: `test/core/domain/models/dive_comparison_result_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/core/domain/models/dive_comparison_result_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/models/dive_comparison_result.dart';
import 'package:submersion/core/models/incoming_dive_data.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

// Helper to create a minimal Dive for testing.
Dive _makeDive({
  DateTime? entryTime,
  DateTime? dateTime,
  double? maxDepth,
  double? avgDepth,
  Duration? duration,
  double? waterTemp,
  String? diveComputerModel,
  String? diveComputerSerial,
}) {
  final now = DateTime.now();
  return Dive(
    id: 'test-id',
    dateTime: dateTime ?? now,
    entryTime: entryTime,
    maxDepth: maxDepth,
    avgDepth: avgDepth,
    duration: duration,
    waterTemp: waterTemp,
    diveComputerModel: diveComputerModel,
    diveComputerSerial: diveComputerSerial,
    tanks: const [],
    profile: const [],
    equipment: const [],
    notes: '',
    photoIds: const [],
    sightings: const [],
    diveTypeId: '',
    weights: const [],
    tags: const [],
    customFields: const [],
  );
}

void main() {
  group('compareForConsolidation', () {
    test('all fields same within tolerance produces all-same result', () {
      final existing = _makeDive(
        entryTime: DateTime(2026, 3, 19, 22, 23, 0),
        maxDepth: 15.0,
        avgDepth: 10.0,
        duration: const Duration(minutes: 45),
        waterTemp: 26.0,
        diveComputerModel: 'Teric',
        diveComputerSerial: '111',
      );
      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 3, 19, 22, 23, 30), // 30s diff, within 60s
        maxDepth: 15.3, // 0.3m diff, within 0.5m
        avgDepth: 10.4, // 0.4m diff, within 0.5m
        durationSeconds: 45 * 60 + 50, // 50s diff, within 60s
        waterTemp: 26.5, // 0.5C diff, within 1.0C
        computerModel: 'Teric',
        computerSerial: '222',
      );

      final result = compareForConsolidation(existing, incoming);

      // Time, depth, avgDepth, duration, temp should all be "same"
      expect(result.sameFields.map((f) => f.name), containsAll([
        'date/time', 'max depth', 'avg depth', 'duration', 'water temp',
      ]));
      // Computer always in diff (different serials by definition)
      expect(result.diffFields.any((f) => f.name == 'computer'), isTrue);
    });

    test('fields differing beyond tolerance appear in diffFields', () {
      final existing = _makeDive(
        entryTime: DateTime(2026, 3, 19, 22, 23),
        maxDepth: 15.0,
        duration: const Duration(minutes: 45),
      );
      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 3, 19, 22, 23),
        maxDepth: 16.0, // 1.0m diff, > 0.5m tolerance
        durationSeconds: 45 * 60 + 120, // 120s diff, > 60s tolerance
        computerModel: 'Teric',
        computerSerial: '222',
      );

      final result = compareForConsolidation(existing, incoming);

      final diffNames = result.diffFields.map((f) => f.name).toList();
      expect(diffNames, contains('max depth'));
      expect(diffNames, contains('duration'));
    });

    test('null on one side shows as diff with "not recorded"', () {
      final existing = _makeDive(
        entryTime: DateTime(2026, 3, 19, 22, 23),
        maxDepth: 15.0,
        waterTemp: 26.0,
      );
      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 3, 19, 22, 23),
        maxDepth: 15.0,
        waterTemp: null, // missing
        computerModel: 'Teric',
        computerSerial: '222',
      );

      final result = compareForConsolidation(existing, incoming);

      final tempDiff = result.diffFields.where(
        (f) => f.name == 'water temp',
      );
      expect(tempDiff, hasLength(1));
      expect(tempDiff.first.incomingRaw, isNull);
    });

    test('both null on a field excludes it from same and diff', () {
      final existing = _makeDive(
        entryTime: DateTime(2026, 3, 19, 22, 23),
        maxDepth: 15.0,
      );
      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 3, 19, 22, 23),
        maxDepth: 15.0,
        computerModel: 'Teric',
        computerSerial: '222',
      );

      final result = compareForConsolidation(existing, incoming);

      final allNames = [
        ...result.sameFields.map((f) => f.name),
        ...result.diffFields.map((f) => f.name),
      ];
      // waterTemp, avgDepth, duration all null on both sides
      expect(allNames, isNot(contains('water temp')));
      expect(allNames, isNot(contains('avg depth')));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/domain/models/dive_comparison_result_test.dart`
Expected: compilation error — `DiveComparisonResult` and `compareForConsolidation` do not exist.

- [ ] **Step 3: Implement DiveComparisonResult and compareForConsolidation**

```dart
// lib/core/domain/models/dive_comparison_result.dart
import 'package:submersion/core/models/incoming_dive_data.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The type of field being compared, used for unit-aware formatting.
enum ComparisonFieldType { dateTime, depth, duration, temperature, text }

/// A field that matched within tolerance.
class SameField {
  final String name;
  final ComparisonFieldType type;
  final double? rawValue;

  const SameField({required this.name, required this.type, this.rawValue});
}

/// A field that differed beyond tolerance.
class DiffField {
  final String name;
  final ComparisonFieldType type;

  /// Raw existing value, or null if the existing dive lacks this field.
  final double? existingRaw;

  /// Raw incoming value, or null if the incoming dive lacks this field.
  final double? incomingRaw;

  /// Pre-formatted text values (for non-numeric fields like computer, date/time).
  final String? existingText;
  final String? incomingText;

  /// Raw numeric delta (incoming - existing), null if non-numeric or missing.
  final double? delta;

  const DiffField({
    required this.name,
    required this.type,
    this.existingRaw,
    this.incomingRaw,
    this.existingText,
    this.incomingText,
    this.delta,
  });
}

/// Result of comparing an existing [Dive] with an [IncomingDiveData].
class DiveComparisonResult {
  final List<SameField> sameFields;
  final List<DiffField> diffFields;

  const DiveComparisonResult({
    required this.sameFields,
    required this.diffFields,
  });
}

/// Compare an existing dive with incoming data, classifying each field
/// as same (within tolerance) or different.
///
/// Tolerances: time 60s, depth 0.5m, temperature 1.0C, duration 60s.
DiveComparisonResult compareForConsolidation(
  Dive existing,
  IncomingDiveData incoming,
) {
  final same = <SameField>[];
  final diff = <DiffField>[];

  // --- Time ---
  final existingTime = existing.effectiveEntryTime;
  final incomingTime = incoming.startTime;
  if (incomingTime != null) {
    final diffSec = existingTime.difference(incomingTime).inSeconds.abs();
    if (diffSec <= 60) {
      same.add(SameField(
        name: 'date/time',
        type: ComparisonFieldType.dateTime,
      ));
    } else {
      diff.add(DiffField(
        name: 'date/time',
        type: ComparisonFieldType.dateTime,
        existingText: _formatDateTime(existingTime),
        incomingText: _formatDateTime(incomingTime),
      ));
    }
  }

  // --- Max Depth ---
  _compareNumeric(
    name: 'max depth',
    type: ComparisonFieldType.depth,
    existingVal: existing.maxDepth,
    incomingVal: incoming.maxDepth,
    tolerance: 0.5,
    same: same,
    diff: diff,
  );

  // --- Avg Depth ---
  _compareNumeric(
    name: 'avg depth',
    type: ComparisonFieldType.depth,
    existingVal: existing.avgDepth,
    incomingVal: incoming.avgDepth,
    tolerance: 0.5,
    same: same,
    diff: diff,
  );

  // --- Duration ---
  _compareNumeric(
    name: 'duration',
    type: ComparisonFieldType.duration,
    existingVal: existing.duration?.inSeconds.toDouble(),
    incomingVal: incoming.durationSeconds?.toDouble(),
    tolerance: 60,
    same: same,
    diff: diff,
  );

  // --- Water Temp ---
  _compareNumeric(
    name: 'water temp',
    type: ComparisonFieldType.temperature,
    existingVal: existing.waterTemp,
    incomingVal: incoming.waterTemp,
    tolerance: 1.0,
    same: same,
    diff: diff,
  );

  // --- Computer (always diff — different devices by definition) ---
  diff.add(DiffField(
    name: 'computer',
    type: ComparisonFieldType.text,
    existingText: _formatComputer(
      existing.diveComputerModel,
      existing.diveComputerSerial,
    ),
    incomingText: _formatComputer(
      incoming.computerModel,
      incoming.computerSerial,
    ),
  ));

  return DiveComparisonResult(sameFields: same, diffFields: diff);
}

void _compareNumeric({
  required String name,
  required ComparisonFieldType type,
  required double? existingVal,
  required double? incomingVal,
  required double tolerance,
  required List<SameField> same,
  required List<DiffField> diff,
}) {
  // Both null — skip entirely.
  if (existingVal == null && incomingVal == null) return;

  // One null — always a diff.
  if (existingVal == null || incomingVal == null) {
    diff.add(DiffField(
      name: name,
      type: type,
      existingRaw: existingVal,
      incomingRaw: incomingVal,
    ));
    return;
  }

  final delta = incomingVal - existingVal;
  if (delta.abs() <= tolerance) {
    same.add(SameField(name: name, type: type, rawValue: existingVal));
  } else {
    diff.add(DiffField(
      name: name,
      type: type,
      existingRaw: existingVal,
      incomingRaw: incomingVal,
      delta: delta,
    ));
  }
}

String _formatDateTime(DateTime dt) {
  return '${dt.month}/${dt.day}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

String _formatComputer(String? model, String? serial) {
  final parts = <String>[];
  if (model != null) parts.add(model);
  if (serial != null) {
    final truncated = serial.length > 6 ? '...${serial.substring(serial.length - 6)}' : serial;
    parts.add(truncated);
  }
  return parts.isEmpty ? 'Unknown' : parts.join(' \u00b7 ');
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/domain/models/dive_comparison_result_test.dart`
Expected: All 4 tests pass.

- [ ] **Step 5: Run `dart format`**

Run: `dart format lib/core/domain/models/ test/core/domain/models/`

- [ ] **Step 6: Commit**

```bash
git add lib/core/domain/models/dive_comparison_result.dart test/core/domain/models/dive_comparison_result_test.dart
git commit -m "feat: add DiveComparisonResult and compareForConsolidation with tolerance-based field diffing"
```

---

### Task 3: OverlaidProfileChart Widget

**Files:**
- Create: `lib/core/presentation/widgets/overlaid_profile_chart.dart`

- [ ] **Step 1: Create the OverlaidProfileChart widget**

This is a visual widget — test manually rather than writing widget tests for chart rendering. Based on the existing `DiveProfileMiniChart` in `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart:3095-3152`.

```dart
// lib/core/presentation/widgets/overlaid_profile_chart.dart
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Renders two dive profiles overlaid on a single chart for comparison.
///
/// The existing dive profile is drawn as a solid line and the incoming
/// profile as a dashed line.  Both share the same axes so shape
/// differences are immediately visible.
///
/// If only one profile is present, renders a single-line chart.
/// If both are empty, shows a "No profile data" placeholder.
class OverlaidProfileChart extends StatelessWidget {
  final List<DiveProfilePoint> existingProfile;
  final List<DiveProfilePoint> incomingProfile;
  final String? existingLabel;
  final String? incomingLabel;
  final double height;

  const OverlaidProfileChart({
    super.key,
    this.existingProfile = const [],
    this.incomingProfile = const [],
    this.existingLabel,
    this.incomingLabel,
    this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (existingProfile.isEmpty && incomingProfile.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No profile data',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Compute shared axis bounds across both profiles.
    final allDepths = [
      ...existingProfile.map((p) => p.depth),
      ...incomingProfile.map((p) => p.depth),
    ];
    final allTimes = [
      ...existingProfile.map((p) => p.timestamp),
      ...incomingProfile.map((p) => p.timestamp),
    ];
    final maxDepth = allDepths.reduce(math.max) * 1.1;
    final maxTime = allTimes.reduce(math.max).toDouble();

    final existingColor = colorScheme.primary;
    final incomingColor = colorScheme.secondary;

    final bars = <LineChartBarData>[];

    if (existingProfile.isNotEmpty) {
      bars.add(LineChartBarData(
        spots: existingProfile
            .map((p) => FlSpot(p.timestamp.toDouble(), -p.depth))
            .toList(),
        isCurved: true,
        curveSmoothness: 0.3,
        color: existingColor,
        barWidth: 1.5,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: existingColor.withValues(alpha: 0.15),
        ),
      ));
    }

    if (incomingProfile.isNotEmpty) {
      bars.add(LineChartBarData(
        spots: incomingProfile
            .map((p) => FlSpot(p.timestamp.toDouble(), -p.depth))
            .toList(),
        isCurved: true,
        curveSmoothness: 0.3,
        color: incomingColor,
        barWidth: 1.5,
        isStrokeCapRound: true,
        dashArray: [4, 2],
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: incomingColor.withValues(alpha: 0.08),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: maxTime,
              minY: -maxDepth,
              maxY: 0,
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: bars,
            ),
          ),
        ),
        // Legend
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              if (existingProfile.isNotEmpty) ...[
                _LegendDot(color: existingColor),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    existingLabel ?? 'Existing',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (existingProfile.isNotEmpty && incomingProfile.isNotEmpty)
                const SizedBox(width: 16),
              if (incomingProfile.isNotEmpty) ...[
                _LegendDot(color: incomingColor, dashed: true),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    incomingLabel ?? 'Incoming',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final bool dashed;

  const _LegendDot({required this.color, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 3,
      decoration: BoxDecoration(
        color: dashed ? null : color,
        borderRadius: BorderRadius.circular(1.5),
        border: dashed ? Border.all(color: color, width: 1) : null,
      ),
    );
  }
}
```

- [ ] **Step 2: Run `dart format` and `flutter analyze`**

Run: `dart format lib/core/presentation/widgets/overlaid_profile_chart.dart && flutter analyze lib/core/presentation/widgets/overlaid_profile_chart.dart`

- [ ] **Step 3: Commit**

```bash
mkdir -p lib/core/presentation/widgets
git add lib/core/presentation/widgets/overlaid_profile_chart.dart
git commit -m "feat: add OverlaidProfileChart widget for two-profile comparison"
```

---

### Task 4: DiveComparisonCard Widget

**Files:**
- Create: `lib/core/presentation/widgets/dive_comparison_card.dart`

This is the main shared card used by both import flows. It is a `ConsumerWidget` that fetches the existing dive and profile via Riverpod providers.

- [ ] **Step 1: Create the DiveComparisonCard widget**

```dart
// lib/core/presentation/widgets/dive_comparison_card.dart
import 'package:flutter/material.dart';

import 'package:submersion/core/models/dive_comparison_result.dart';
import 'package:submersion/core/models/incoming_dive_data.dart';
import 'package:submersion/core/presentation/widgets/overlaid_profile_chart.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Shared comparison card for dive duplicate resolution.
///
/// Used by both the dive computer download flow ([SummaryStepWidget]) and the
/// file import flow ([ImportDiveCard]).  Fetches the existing dive and profile
/// from Riverpod providers and renders the hybrid comparison layout.
class DiveComparisonCard extends ConsumerWidget {
  final IncomingDiveData incoming;
  final String existingDiveId;
  final double matchScore;
  final String existingLabel;
  final String incomingLabel;
  final VoidCallback? onSkip;
  final VoidCallback? onImportAsNew;
  final VoidCallback? onConsolidate;

  const DiveComparisonCard({
    super.key,
    required this.incoming,
    required this.existingDiveId,
    required this.matchScore,
    this.existingLabel = 'Existing',
    this.incomingLabel = 'Downloaded',
    this.onSkip,
    this.onImportAsNew,
    this.onConsolidate,
  });

  Color _badgeColor(ColorScheme colorScheme) {
    if (matchScore >= 0.9) return colorScheme.primary;
    if (matchScore >= 0.7) return Colors.amber.shade700;
    return colorScheme.error;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    final existingAsync = ref.watch(diveProvider(existingDiveId));
    final profileAsync = ref.watch(diveProfileProvider(existingDiveId));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: existingAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, _) => const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Error loading dive data'),
        ),
        data: (existingDive) {
          if (existingDive == null) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Existing dive not found'),
            );
          }

          final comparison = compareForConsolidation(
            existingDive,
            incoming,
          );
          final existingProfile = profileAsync.valueOrNull ?? [];
          final diveNum = existingDive.diveNumber;
          final effectiveExistingLabel = diveNum != null
              ? '$existingLabel (#$diveNum)'
              : existingLabel;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Match Header
              _buildMatchHeader(
                context,
                comparison,
                effectiveExistingLabel,
                units,
              ),

              // 2. Overlaid Profiles
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: OverlaidProfileChart(
                  existingProfile: existingProfile,
                  incomingProfile: incoming.profile,
                  existingLabel: _computerLabel(
                    existingDive.diveComputerModel,
                    existingDive.diveComputerSerial,
                  ),
                  incomingLabel: _computerLabel(
                    incoming.computerModel,
                    incoming.computerSerial,
                  ),
                  height: 80,
                ),
              ),

              // 3. Same Fields Summary
              if (comparison.sameFields.isNotEmpty)
                _buildSameSummary(context, comparison, units),

              // 4. Differences Table
              _buildDiffTable(
                context,
                comparison,
                effectiveExistingLabel,
                units,
              ),

              // 5. Action Buttons
              _buildActionButtons(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMatchHeader(
    BuildContext context,
    DiveComparisonResult comparison,
    String label,
    UnitFormatter units,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final percent = (matchScore * 100).toStringAsFixed(0);

    // Gather shared data to display once.
    final sharedParts = <String>[];
    for (final f in comparison.sameFields) {
      if (f.name == 'date/time' || f.name == 'max depth') {
        sharedParts.add(_formatFieldValue(f.type, f.rawValue, units));
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _badgeColor(colorScheme),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$percent%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              sharedParts.isNotEmpty
                  ? sharedParts.join(' \u00b7 ')
                  : 'Potential match',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSameSummary(
    BuildContext context,
    DiveComparisonResult comparison,
    UnitFormatter units,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final fieldNames = comparison.sameFields.map((f) => f.name).toList();
    final summary = fieldNames.join(', ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.check, size: 14, color: Colors.green.shade600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Same: $summary',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffTable(
    BuildContext context,
    DiveComparisonResult comparison,
    String existingLabel,
    UnitFormatter units,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DIFFERENCES',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          // Column headers
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text('',
                    style: theme.textTheme.labelSmall),
              ),
              Expanded(
                child: Text(
                  existingLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  incomingLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Divider(height: 1, color: colorScheme.outlineVariant),
          const SizedBox(height: 4),
          // Diff rows
          ...comparison.diffFields.map(
            (field) => _buildDiffRow(context, field, units),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffRow(
    BuildContext context,
    DiffField field,
    UnitFormatter units,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Format values using UnitFormatter for unit-aware display.
    final existingStr = field.existingText ??
        (field.existingRaw != null
            ? _formatFieldValue(field.type, field.existingRaw, units)
            : null);
    final incomingStr = field.incomingText ??
        (field.incomingRaw != null
            ? _formatFieldValue(field.type, field.incomingRaw, units)
            : null);

    String formatValue(String? value) => value ?? 'not recorded';
    final hasExisting = existingStr != null;
    final hasIncoming = incomingStr != null;
    final isChanged = hasExisting && hasIncoming && field.name != 'computer';

    // Format incoming value with delta.
    String incomingDisplay = formatValue(incomingStr);
    if (field.delta != null && field.delta != 0) {
      final sign = field.delta! > 0 ? '+' : '';
      if (field.type == ComparisonFieldType.duration) {
        final deltaSec = field.delta!.round();
        final deltaMin = deltaSec ~/ 60;
        final remSec = deltaSec.abs() % 60;
        final deltaStr = deltaMin != 0
            ? '$sign${deltaMin}m${remSec > 0 ? ' ${remSec}s' : ''}'
            : '$sign${deltaSec}s';
        incomingDisplay = '$incomingStr ($deltaStr)';
      } else {
        incomingDisplay =
            '$incomingStr ($sign${field.delta!.toStringAsFixed(1)})';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              field.name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              formatValue(existingStr),
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              incomingDisplay,
              style: theme.textTheme.bodySmall?.copyWith(
                color: !hasIncoming
                    ? colorScheme.onSurfaceVariant
                    : (isChanged ? Colors.amber.shade700 : null),
                fontStyle: !hasIncoming
                    ? FontStyle.italic
                    : null,
                fontWeight: isChanged ? FontWeight.w500 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Skip
          _ActionButton(
            label: 'Skip',
            subtitle: 'Discard this download',
            onPressed: onSkip,
            style: _ActionButtonStyle.text,
          ),
          const SizedBox(width: 8),
          // Import as New
          _ActionButton(
            label: 'Import as New',
            subtitle: 'Save as separate dive',
            onPressed: onImportAsNew,
            style: _ActionButtonStyle.outlined,
          ),
          const SizedBox(width: 8),
          // Consolidate
          _ActionButton(
            label: 'Consolidate',
            subtitle: 'Add as 2nd computer reading',
            onPressed: onConsolidate,
            style: _ActionButtonStyle.filledTonal,
          ),
        ],
      ),
    );
  }

  /// Format a raw field value using UnitFormatter for unit-aware display.
  static String _formatFieldValue(
    ComparisonFieldType type,
    double? rawValue,
    UnitFormatter units,
  ) {
    if (rawValue == null) return '--';
    switch (type) {
      case ComparisonFieldType.depth:
        return units.formatDepth(rawValue);
      case ComparisonFieldType.temperature:
        return units.formatTemperature(rawValue);
      case ComparisonFieldType.duration:
        return '${(rawValue / 60).round()} min';
      case ComparisonFieldType.dateTime:
      case ComparisonFieldType.text:
        return rawValue.toString();
    }
  }

  String _computerLabel(String? model, String? serial) {
    final parts = <String>[];
    if (model != null) parts.add(model);
    if (serial != null) {
      final truncated = serial.length > 6
          ? '...${serial.substring(serial.length - 6)}'
          : serial;
      parts.add(truncated);
    }
    return parts.isEmpty ? 'Unknown' : parts.join(' \u00b7 ');
  }
}

enum _ActionButtonStyle { text, outlined, filledTonal }

class _ActionButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final VoidCallback? onPressed;
  final _ActionButtonStyle style;

  const _ActionButton({
    required this.label,
    required this.subtitle,
    this.onPressed,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          subtitle,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );

    switch (style) {
      case _ActionButtonStyle.text:
        return TextButton(onPressed: onPressed, child: child);
      case _ActionButtonStyle.outlined:
        return OutlinedButton(onPressed: onPressed, child: child);
      case _ActionButtonStyle.filledTonal:
        return FilledButton.tonal(onPressed: onPressed, child: child);
    }
  }
}
```

- [ ] **Step 2: Run `dart format` and `flutter analyze`**

Run: `dart format lib/core/presentation/widgets/dive_comparison_card.dart && flutter analyze lib/core/presentation/widgets/dive_comparison_card.dart`

- [ ] **Step 3: Commit**

```bash
git add lib/core/presentation/widgets/dive_comparison_card.dart
git commit -m "feat: add DiveComparisonCard shared widget with hybrid comparison layout"
```

---

### Task 5: Integrate into SummaryStepWidget (Dive Computer Download)

**Files:**
- Modify: `lib/features/dive_computer/presentation/widgets/summary_step_widget.dart`

- [ ] **Step 1: Replace `_buildCandidateCard` and related methods**

In `summary_step_widget.dart`, replace the `_buildCandidateCard`, `_buildExistingDiveColumn`, and `_buildImportedDiveColumn` methods in `_buildConsolidationSection` with calls to `DiveComparisonCard`.

Replace the candidate mapping in `_buildConsolidationSection` (the `...candidates.map(...)` block) with:

```dart
...candidates.map(
  (candidate) => DiveComparisonCard(
    incoming: IncomingDiveData.fromDownloadedDive(
      candidate.dive,
      computer: computer,
    ),
    existingDiveId: candidate.matchedDiveId,
    matchScore: candidate.matchScore,
    incomingLabel: 'Downloaded',
    onSkip: () => notifier.skipConsolidation(candidate),
    onImportAsNew: () async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await notifier.importCandidateAsNew(candidate);
        messenger.showSnackBar(
          const SnackBar(content: Text('Imported as separate dive.')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    },
    onConsolidate: () async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await notifier.consolidateDive(candidate);
        messenger.showSnackBar(
          const SnackBar(content: Text('Dive consolidated successfully.')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Consolidation failed: $e')),
        );
      }
    },
  ),
),
```

Then remove the now-unused methods: `_buildCandidateCard`, `_buildImportedDiveColumn`, `_buildExistingDiveColumn`.

Add imports at the top:

```dart
import 'package:submersion/core/models/incoming_dive_data.dart';
import 'package:submersion/core/presentation/widgets/dive_comparison_card.dart';
```

Remove imports that are no longer needed (e.g., `dive_profile_chart.dart`, `dive.dart as domain`).

- [ ] **Step 2: Run `dart format` and `flutter analyze`**

Run: `dart format lib/features/dive_computer/presentation/widgets/summary_step_widget.dart && flutter analyze lib/features/dive_computer/presentation/widgets/summary_step_widget.dart`

- [ ] **Step 3: Test manually**

Run: `flutter run -d macos`
Test: Download dives from a computer that produces a duplicate match. Verify:
- Match percentage badge shows with correct color
- Overlaid profiles render on one chart with two colors
- Same fields summary shows with green check
- Differences table only shows fields that differ
- Action buttons have subtitles
- Skip/Import as New/Consolidate still function correctly

- [ ] **Step 4: Commit**

```bash
git add lib/features/dive_computer/presentation/widgets/summary_step_widget.dart
git commit -m "feat: replace side-by-side comparison with DiveComparisonCard in computer download flow"
```

---

### Task 6: Integrate into ImportDiveCard (File Import)

**Files:**
- Modify: `lib/features/universal_import/presentation/widgets/import_dive_card.dart`

- [ ] **Step 1: Convert to StatefulWidget and add expandable comparison**

Replace the `_buildResolutionRow` method with an expandable `DiveComparisonCard`. `ImportDiveCard` becomes a `StatefulWidget` to manage the expanded toggle.

Replace the entire class with:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/models/incoming_dive_data.dart';
import 'package:submersion/core/presentation/widgets/dive_comparison_card.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/universal_import/presentation/widgets/duplicate_badge.dart';

class ImportDiveCard extends StatefulWidget {
  const ImportDiveCard({
    super.key,
    required this.diveData,
    required this.index,
    required this.isSelected,
    required this.onToggle,
    this.matchResult,
    this.resolution,
    this.onResolutionChanged,
  });

  final Map<String, dynamic> diveData;
  final int index;
  final bool isSelected;
  final VoidCallback onToggle;
  final DiveMatchResult? matchResult;
  final DiveDuplicateResolution? resolution;
  final ValueChanged<DiveDuplicateResolution>? onResolutionChanged;

  @override
  State<ImportDiveCard> createState() => _ImportDiveCardState();
}

class _ImportDiveCardState extends State<ImportDiveCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final dateTime = widget.diveData['dateTime'] as DateTime?;
    final maxDepth = widget.diveData['maxDepth'] as double?;
    final duration = widget.diveData['duration'] as Duration?;
    final runtime = widget.diveData['runtime'] as Duration?;
    final siteName = widget.diveData['siteName'] as String?;
    final diveNumber = widget.diveData['diveNumber'] as int?;

    final dateStr = dateTime != null
        ? DateFormat('MMM d, y - HH:mm').format(dateTime)
        : context.l10n.universalImport_label_unknownDate;

    final depthStr = maxDepth != null ? '${maxDepth.toStringAsFixed(1)}m' : '';
    final durationMin = (runtime ?? duration)?.inMinutes;
    final durationStr = durationMin != null ? '${durationMin}min' : '';

    final title = diveNumber != null
        ? context.l10n.universalImport_label_diveNumber(diveNumber)
        : dateStr;
    final subtitle = diveNumber != null
        ? dateStr
        : [depthStr, durationStr, siteName ?? '']
            .where((s) => s.isNotEmpty)
            .join(' / ');

    final hasMatch = widget.matchResult != null &&
        widget.matchResult!.score >= 0.5;

    return Card(
      elevation: widget.isSelected ? 2 : 0,
      color: widget.isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: Column(
        children: [
          Semantics(
            button: true,
            label: context.l10n.universalImport_semantics_toggleSelection(
              title,
            ),
            child: InkWell(
              onTap: widget.onToggle,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildCheckbox(colorScheme),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.scuba_diving,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (diveNumber != null) ...[
                                const SizedBox(height: 2),
                                _buildMetrics(
                                  theme,
                                  depthStr,
                                  durationStr,
                                  siteName,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (widget.matchResult != null) ...[
                          const SizedBox(width: 8),
                          DuplicateBadge(
                            isProbable: widget.matchResult!.score >= 0.7,
                            label: context.l10n
                                .universalImport_label_percentMatch(
                              (widget.matchResult!.score * 100)
                                  .toStringAsFixed(0),
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Expand/collapse toggle for match comparison
                    if (hasMatch)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setState(
                            () => _isExpanded = !_isExpanded,
                          ),
                          icon: Icon(
                            _isExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 16,
                          ),
                          label: Text(
                            _isExpanded ? 'Hide comparison' : 'Compare dives',
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Expandable comparison card
          if (hasMatch && _isExpanded)
            Padding(
              padding: const EdgeInsets.only(
                left: 8,
                right: 8,
                bottom: 8,
              ),
              child: DiveComparisonCard(
                incoming: IncomingDiveData.fromImportMap(widget.diveData),
                existingDiveId: widget.matchResult!.diveId,
                matchScore: widget.matchResult!.score,
                incomingLabel: 'Imported',
                onSkip: () => widget.onResolutionChanged?.call(
                  DiveDuplicateResolution.skip,
                ),
                onImportAsNew: () => widget.onResolutionChanged?.call(
                  DiveDuplicateResolution.importAsNew,
                ),
                onConsolidate: () => widget.onResolutionChanged?.call(
                  DiveDuplicateResolution.consolidate,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCheckbox(ColorScheme colorScheme) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.isSelected ? colorScheme.primary : colorScheme.outline,
          width: 2,
        ),
        color: widget.isSelected ? colorScheme.primary : Colors.transparent,
      ),
      child: widget.isSelected
          ? Icon(Icons.check, size: 16, color: colorScheme.onPrimary)
          : null,
    );
  }

  Widget _buildMetrics(
    ThemeData theme,
    String depthStr,
    String durationStr,
    String? siteName,
  ) {
    final parts = [
      depthStr,
      durationStr,
      siteName ?? '',
    ].where((s) => s.isNotEmpty).join(' / ');

    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
```

- [ ] **Step 2: Run `dart format` and `flutter analyze`**

Run: `dart format lib/features/universal_import/presentation/widgets/import_dive_card.dart && flutter analyze lib/features/universal_import/presentation/widgets/import_dive_card.dart`

- [ ] **Step 3: Test manually**

Run: `flutter run -d macos`
Test: Import a Subsurface XML or UDDF file that contains dives already in the database. Verify:
- Duplicate badge still shows on matched cards
- "Compare dives" toggle button appears for matches >= 50%
- Expanding shows the full DiveComparisonCard with overlaid profiles
- Skip/Import as New/Consolidate buttons update the resolution
- Collapsing hides the card

- [ ] **Step 4: Commit**

```bash
git add lib/features/universal_import/presentation/widgets/import_dive_card.dart
git commit -m "feat: add expandable DiveComparisonCard to file import duplicate resolution"
```

---

### Task 7: Final Cleanup and Format

**Files:**
- All modified files

- [ ] **Step 1: Run full format and analyze**

Run: `dart format lib/ test/ && flutter analyze`

- [ ] **Step 2: Run all tests**

Run: `flutter test`
Expected: All tests pass (existing + new).

- [ ] **Step 3: Clean up unused code in summary_step_widget.dart**

Verify that the removed methods (`_buildCandidateCard`, `_buildExistingDiveColumn`, `_buildImportedDiveColumn`) are fully gone and no orphaned imports remain.

- [ ] **Step 4: Final commit if any cleanup was needed**

```bash
git add -A
git commit -m "chore: final cleanup and formatting for consolidation card redesign"
```
