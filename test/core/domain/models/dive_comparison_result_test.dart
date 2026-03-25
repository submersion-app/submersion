import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/domain/models/dive_comparison_result.dart';
import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

// Helper to create a minimal Dive for testing.
Dive _makeDive({
  DateTime? entryTime,
  DateTime? dateTime,
  double? maxDepth,
  double? avgDepth,
  Duration? duration,
  Duration? runtime,
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
    runtime: runtime,
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
        runtime: const Duration(minutes: 45),
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

      expect(
        result.sameFields.map((f) => f.name),
        containsAll([
          'date/time',
          'max depth',
          'avg depth',
          'duration',
          'water temp',
        ]),
      );
      expect(result.diffFields.any((f) => f.name == 'computer'), isTrue);
    });

    test('fields differing beyond tolerance appear in diffFields', () {
      final existing = _makeDive(
        entryTime: DateTime(2026, 3, 19, 22, 23),
        maxDepth: 15.0,
        runtime: const Duration(minutes: 45),
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

    test('null on one side shows as diff', () {
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

      final tempDiff = result.diffFields.where((f) => f.name == 'water temp');
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
      expect(allNames, isNot(contains('water temp')));
      expect(allNames, isNot(contains('avg depth')));
    });
  });
}
