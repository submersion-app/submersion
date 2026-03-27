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
    bottomTime: duration,
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
  group('SameField', () {
    test('stores name, type, and rawValue', () {
      const field = SameField(
        name: 'max depth',
        type: ComparisonFieldType.depth,
        rawValue: 15.0,
      );

      expect(field.name, 'max depth');
      expect(field.type, ComparisonFieldType.depth);
      expect(field.rawValue, 15.0);
    });

    test('rawValue defaults to null', () {
      const field = SameField(
        name: 'date/time',
        type: ComparisonFieldType.dateTime,
      );

      expect(field.rawValue, isNull);
    });
  });

  group('DiffField', () {
    test('stores all numeric fields', () {
      const field = DiffField(
        name: 'max depth',
        type: ComparisonFieldType.depth,
        existingRaw: 15.0,
        incomingRaw: 17.0,
        delta: 2.0,
      );

      expect(field.name, 'max depth');
      expect(field.type, ComparisonFieldType.depth);
      expect(field.existingRaw, 15.0);
      expect(field.incomingRaw, 17.0);
      expect(field.delta, 2.0);
      expect(field.existingText, isNull);
      expect(field.incomingText, isNull);
    });

    test('stores text fields for non-numeric comparisons', () {
      const field = DiffField(
        name: 'computer',
        type: ComparisonFieldType.text,
        existingText: 'Teric',
        incomingText: 'Perdix',
      );

      expect(field.existingText, 'Teric');
      expect(field.incomingText, 'Perdix');
      expect(field.existingRaw, isNull);
      expect(field.incomingRaw, isNull);
      expect(field.delta, isNull);
    });
  });

  group('DiveComparisonResult', () {
    test('holds sameFields and diffFields lists', () {
      const result = DiveComparisonResult(
        sameFields: [SameField(name: 'a', type: ComparisonFieldType.text)],
        diffFields: [DiffField(name: 'b', type: ComparisonFieldType.text)],
      );

      expect(result.sameFields, hasLength(1));
      expect(result.diffFields, hasLength(1));
    });
  });

  group('ComparisonFieldType', () {
    test('has all expected values', () {
      expect(ComparisonFieldType.values, hasLength(5));
      expect(
        ComparisonFieldType.values,
        containsAll([
          ComparisonFieldType.dateTime,
          ComparisonFieldType.depth,
          ComparisonFieldType.duration,
          ComparisonFieldType.temperature,
          ComparisonFieldType.text,
        ]),
      );
    });
  });

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
        startTime: DateTime(2026, 3, 19, 22, 23, 30), // 30s, within 60s
        maxDepth: 15.3, // 0.3m, within 0.5m
        avgDepth: 10.4, // 0.4m, within 0.5m
        durationSeconds: 45 * 60 + 50, // 50s, within 60s
        waterTemp: 26.5, // 0.5C, within 1.0C
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
        maxDepth: 16.0, // 1.0m, > 0.5m tolerance
        durationSeconds: 45 * 60 + 120, // 120s, > 60s tolerance
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

    // --- Delta calculation tests ---

    test('diff fields include correct delta for numeric comparisons', () {
      final existing = _makeDive(
        entryTime: DateTime(2026, 3, 19, 10, 0),
        maxDepth: 20.0,
        avgDepth: 12.0,
      );
      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 3, 19, 10, 0),
        maxDepth: 22.5, // delta = +2.5
        avgDepth: 10.0, // delta = -2.0
      );

      final result = compareForConsolidation(existing, incoming);

      final maxDepthDiff = result.diffFields.firstWhere(
        (f) => f.name == 'max depth',
      );
      expect(maxDepthDiff.existingRaw, 20.0);
      expect(maxDepthDiff.incomingRaw, 22.5);
      expect(maxDepthDiff.delta, 2.5);

      final avgDepthDiff = result.diffFields.firstWhere(
        (f) => f.name == 'avg depth',
      );
      expect(avgDepthDiff.existingRaw, 12.0);
      expect(avgDepthDiff.incomingRaw, 10.0);
      expect(avgDepthDiff.delta, -2.0);
    });

    test('duration diff includes correct delta in seconds', () {
      final existing = _makeDive(
        entryTime: DateTime(2026, 3, 19, 10, 0),
        runtime: const Duration(minutes: 30),
      );
      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 3, 19, 10, 0),
        durationSeconds: 35 * 60, // 5 minutes more = 300s delta
      );

      final result = compareForConsolidation(existing, incoming);

      final durationDiff = result.diffFields.firstWhere(
        (f) => f.name == 'duration',
      );
      expect(durationDiff.existingRaw, 30 * 60.0);
      expect(durationDiff.incomingRaw, 35 * 60.0);
      expect(durationDiff.delta, 300.0);
      expect(durationDiff.type, ComparisonFieldType.duration);
    });

    test('water temp diff includes correct delta', () {
      final existing = _makeDive(
        entryTime: DateTime(2026, 3, 19, 10, 0),
        waterTemp: 20.0,
      );
      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 3, 19, 10, 0),
        waterTemp: 24.5, // delta = +4.5, well beyond 1.0C tolerance
      );

      final result = compareForConsolidation(existing, incoming);

      final tempDiff = result.diffFields.firstWhere(
        (f) => f.name == 'water temp',
      );
      expect(tempDiff.delta, 4.5);
      expect(tempDiff.type, ComparisonFieldType.temperature);
    });

    // --- Tolerance boundary tests ---

    test('depth exactly at 0.5m tolerance is classified as same', () {
      final existing = _makeDive(
        entryTime: DateTime(2026, 3, 19, 10, 0),
        maxDepth: 20.0,
      );
      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 3, 19, 10, 0),
        maxDepth: 20.5, // exactly 0.5m difference
      );

      final result = compareForConsolidation(existing, incoming);

      expect(result.sameFields.any((f) => f.name == 'max depth'), isTrue);
      expect(result.diffFields.any((f) => f.name == 'max depth'), isFalse);
    });

    test('depth just beyond 0.5m tolerance is classified as diff', () {
      final existing = _makeDive(
        entryTime: DateTime(2026, 3, 19, 10, 0),
        maxDepth: 20.0,
      );
      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 3, 19, 10, 0),
        maxDepth: 20.51, // 0.51m, just beyond tolerance
      );

      final result = compareForConsolidation(existing, incoming);

      expect(result.diffFields.any((f) => f.name == 'max depth'), isTrue);
      expect(result.sameFields.any((f) => f.name == 'max depth'), isFalse);
    });

    test('time exactly at 60s tolerance is classified as same', () {
      final existing = _makeDive(entryTime: DateTime(2026, 3, 19, 10, 0, 0));
      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 3, 19, 10, 1, 0), // exactly 60s
      );

      final result = compareForConsolidation(existing, incoming);

      expect(result.sameFields.any((f) => f.name == 'date/time'), isTrue);
      expect(result.diffFields.any((f) => f.name == 'date/time'), isFalse);
    });

    test('time just beyond 60s tolerance is classified as diff', () {
      final existing = _makeDive(entryTime: DateTime(2026, 3, 19, 10, 0, 0));
      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 3, 19, 10, 1, 1), // 61s
      );

      final result = compareForConsolidation(existing, incoming);

      expect(result.diffFields.any((f) => f.name == 'date/time'), isTrue);
      expect(result.sameFields.any((f) => f.name == 'date/time'), isFalse);
    });

    test('duration exactly at 60s tolerance is classified as same', () {
      final existing = _makeDive(
        entryTime: DateTime(2026, 3, 19, 10, 0),
        runtime: const Duration(minutes: 45),
      );
      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 3, 19, 10, 0),
        durationSeconds: 45 * 60 + 60, // exactly 60s difference
      );

      final result = compareForConsolidation(existing, incoming);

      expect(result.sameFields.any((f) => f.name == 'duration'), isTrue);
    });

    test('temperature exactly at 1.0C tolerance is classified as same', () {
      final existing = _makeDive(
        entryTime: DateTime(2026, 3, 19, 10, 0),
        waterTemp: 25.0,
      );
      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 3, 19, 10, 0),
        waterTemp: 26.0, // exactly 1.0C difference
      );

      final result = compareForConsolidation(existing, incoming);

      expect(result.sameFields.any((f) => f.name == 'water temp'), isTrue);
    });

    // --- SameField rawValue tests ---

    test('same numeric fields store rawValue from existing dive', () {
      final existing = _makeDive(
        entryTime: DateTime(2026, 3, 19, 10, 0),
        maxDepth: 15.0,
        avgDepth: 10.5,
        runtime: const Duration(minutes: 45),
        waterTemp: 26.0,
      );
      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 3, 19, 10, 0),
        maxDepth: 15.0,
        avgDepth: 10.5,
        durationSeconds: 45 * 60,
        waterTemp: 26.0,
      );

      final result = compareForConsolidation(existing, incoming);

      final maxDepthSame = result.sameFields.firstWhere(
        (f) => f.name == 'max depth',
      );
      expect(maxDepthSame.rawValue, 15.0);

      final avgDepthSame = result.sameFields.firstWhere(
        (f) => f.name == 'avg depth',
      );
      expect(avgDepthSame.rawValue, 10.5);

      final durationSame = result.sameFields.firstWhere(
        (f) => f.name == 'duration',
      );
      expect(durationSame.rawValue, 45 * 60.0);

      final tempSame = result.sameFields.firstWhere(
        (f) => f.name == 'water temp',
      );
      expect(tempSame.rawValue, 26.0);
    });

    // --- Null incoming time ---

    test('null incoming startTime skips date/time comparison entirely', () {
      final existing = _makeDive(entryTime: DateTime(2026, 3, 19, 10, 0));
      const incoming = IncomingDiveData(startTime: null);

      final result = compareForConsolidation(existing, incoming);

      final allNames = [
        ...result.sameFields.map((f) => f.name),
        ...result.diffFields.map((f) => f.name),
      ];
      expect(allNames, isNot(contains('date/time')));
    });

    // --- Null existing on one side for numeric fields ---

    test(
      'null existing with non-null incoming produces diff with null delta',
      () {
        final existing = _makeDive(
          entryTime: DateTime(2026, 3, 19, 10, 0),
          maxDepth: null,
        );
        final incoming = IncomingDiveData(
          startTime: DateTime(2026, 3, 19, 10, 0),
          maxDepth: 15.0,
        );

        final result = compareForConsolidation(existing, incoming);

        final maxDepthDiff = result.diffFields.firstWhere(
          (f) => f.name == 'max depth',
        );
        expect(maxDepthDiff.existingRaw, isNull);
        expect(maxDepthDiff.incomingRaw, 15.0);
        expect(maxDepthDiff.delta, isNull);
      },
    );

    // --- Date/time diff text formatting ---

    test('date/time diff includes formatted text for both sides', () {
      final existing = _makeDive(entryTime: DateTime(2026, 3, 19, 9, 5));
      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 3, 19, 10, 30),
      );

      final result = compareForConsolidation(existing, incoming);

      final timeDiff = result.diffFields.firstWhere(
        (f) => f.name == 'date/time',
      );
      expect(timeDiff.existingText, '3/19/2026 09:05');
      expect(timeDiff.incomingText, '3/19/2026 10:30');
      expect(timeDiff.type, ComparisonFieldType.dateTime);
    });

    // --- Computer comparison tests ---

    test('identical computer info produces same field', () {
      final existing = _makeDive(
        entryTime: DateTime(2026, 3, 19, 10, 0),
        diveComputerModel: 'Teric',
        diveComputerSerial: '12345',
      );
      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 3, 19, 10, 0),
        computerName: 'Teric',
        computerModel: 'Teric',
        computerSerial: '12345',
      );

      final result = compareForConsolidation(existing, incoming);

      expect(result.sameFields.any((f) => f.name == 'computer'), isTrue);
      expect(result.diffFields.any((f) => f.name == 'computer'), isFalse);
    });

    test('different computer serial produces diff with text', () {
      final existing = _makeDive(
        entryTime: DateTime(2026, 3, 19, 10, 0),
        diveComputerModel: 'Teric',
        diveComputerSerial: '12345',
      );
      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 3, 19, 10, 0),
        computerName: 'Teric',
        computerModel: 'Teric',
        computerSerial: '67890',
      );

      final result = compareForConsolidation(existing, incoming);

      final computerDiff = result.diffFields.firstWhere(
        (f) => f.name == 'computer',
      );
      expect(computerDiff.type, ComparisonFieldType.text);
      expect(computerDiff.existingText, contains('12345'));
      expect(computerDiff.incomingText, contains('67890'));
    });

    test('existingComputerName parameter overrides model for display', () {
      final existing = _makeDive(
        entryTime: DateTime(2026, 3, 19, 10, 0),
        diveComputerModel: 'Teric',
        diveComputerSerial: '12345',
      );
      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 3, 19, 10, 0),
        computerName: 'My Teric',
        computerModel: 'Teric',
        computerSerial: '12345',
      );

      // Without override -- existing uses model as name, incoming has distinct
      // name, so the formatted strings will differ.
      final resultWithout = compareForConsolidation(existing, incoming);
      // The existing formatted string uses diveComputerModel as both name and
      // model (deduped), so it is "Teric . S/N: 12345". The incoming has
      // name="My Teric", model="Teric", serial="12345".
      expect(resultWithout.diffFields.any((f) => f.name == 'computer'), isTrue);

      // With override matching the incoming name, they should align.
      final resultWith = compareForConsolidation(
        existing,
        incoming,
        existingComputerName: 'My Teric',
      );
      expect(resultWith.sameFields.any((f) => f.name == 'computer'), isTrue);
    });

    test('both computers null/empty produces same "Unknown" field', () {
      final existing = _makeDive(entryTime: DateTime(2026, 3, 19, 10, 0));
      const incoming = IncomingDiveData(startTime: null);

      final result = compareForConsolidation(existing, incoming);

      expect(result.sameFields.any((f) => f.name == 'computer'), isTrue);
    });

    test('computer with name only vs unknown produces diff', () {
      final existing = _makeDive(
        entryTime: DateTime(2026, 3, 19, 10, 0),
        diveComputerModel: 'Teric',
      );
      const incoming = IncomingDiveData(startTime: null);

      final result = compareForConsolidation(existing, incoming);

      final computerDiff = result.diffFields.firstWhere(
        (f) => f.name == 'computer',
      );
      expect(computerDiff.existingText, contains('Teric'));
      expect(computerDiff.incomingText, 'Unknown');
    });

    // --- Uses dateTime fallback when entryTime is null ---

    test('uses dateTime when entryTime is null (effectiveEntryTime)', () {
      final existing = _makeDive(
        dateTime: DateTime(2026, 3, 19, 10, 0, 0),
        entryTime: null,
      );
      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 3, 19, 10, 0, 30), // 30s within tolerance
      );

      final result = compareForConsolidation(existing, incoming);

      expect(result.sameFields.any((f) => f.name == 'date/time'), isTrue);
    });

    // --- All fields different produces comprehensive diff ---

    test('all fields different produces complete diff list', () {
      final existing = _makeDive(
        entryTime: DateTime(2026, 1, 1, 8, 0),
        maxDepth: 10.0,
        avgDepth: 5.0,
        runtime: const Duration(minutes: 30),
        waterTemp: 20.0,
        diveComputerModel: 'Perdix',
        diveComputerSerial: '111',
      );
      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 6, 15, 14, 0), // very different
        maxDepth: 40.0,
        avgDepth: 25.0,
        durationSeconds: 90 * 60,
        waterTemp: 5.0,
        computerName: 'Teric',
        computerModel: 'Teric',
        computerSerial: '999',
      );

      final result = compareForConsolidation(existing, incoming);

      final diffNames = result.diffFields.map((f) => f.name).toSet();
      expect(
        diffNames,
        containsAll([
          'date/time',
          'max depth',
          'avg depth',
          'duration',
          'water temp',
          'computer',
        ]),
      );
      expect(result.sameFields, isEmpty);
    });

    // --- Negative delta ---

    test('negative delta when incoming is less than existing', () {
      final existing = _makeDive(
        entryTime: DateTime(2026, 3, 19, 10, 0),
        maxDepth: 30.0,
      );
      final incoming = IncomingDiveData(
        startTime: DateTime(2026, 3, 19, 10, 0),
        maxDepth: 25.0,
      );

      final result = compareForConsolidation(existing, incoming);

      final maxDepthDiff = result.diffFields.firstWhere(
        (f) => f.name == 'max depth',
      );
      expect(maxDepthDiff.delta, -5.0);
    });
  });
}
