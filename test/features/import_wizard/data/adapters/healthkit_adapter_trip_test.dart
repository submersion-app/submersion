import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_import/domain/services/imported_dive_converter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/import_wizard/data/adapters/healthkit_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';

import 'healthkit_adapter_test.mocks.dart';

// An Apple Watch start is the diver's wall clock stored as UTC (#2811).
final _start = DateTime.utc(2026, 11, 8, 9, 30);
const _diverId = 'diver-1';

ImportedDive _workout() => ImportedDive(
  sourceId: 'healthkit-workout-1',
  source: ImportSource.appleWatch,
  startTime: _start,
  endTime: _start.add(const Duration(minutes: 42)),
  maxDepth: 18.5,
  profile: const [],
);

/// A HealthKit dive joins the trip whose dates cover it, as a dive computer
/// download and a file import do (issue #3022).
void main() {
  late MockDiveRepository repo;

  setUp(() {
    repo = MockDiveRepository();
    when(repo.createDive(any)).thenAnswer(
      (invocation) async => invocation.positionalArguments.first as Dive,
    );
  });

  Future<({int imported, Dive saved})> importOne({
    Future<String?> Function(DateTime diveStart, String? diverId)? resolver,
  }) async {
    final adapter = HealthKitAdapter(
      healthService: MockHealthImportService(),
      diveMatcher: MockDiveMatcher(),
      converter: const ImportedDiveConverter(),
      diveRepository: repo,
      diverId: _diverId,
      tripForImports: resolver,
    );
    adapter.setParsedDives([_workout()]);
    final result = await adapter.performImport(await adapter.buildBundle(), {
      ImportEntityType.dives: {0},
    }, {});
    final saved = verify(repo.createDive(captureAny)).captured.single as Dive;
    return (
      imported: result.importedCounts[ImportEntityType.dives] ?? 0,
      saved: saved,
    );
  }

  test('a dive inside a trip\'s dates joins that trip', () async {
    final asked = <(DateTime, String?)>[];
    final result = await importOne(
      resolver: (start, diverId) async {
        asked.add((start, diverId));
        return 'maldives';
      },
    );

    expect(result.saved.tripId, 'maldives');
    expect(asked, [(_start, _diverId)]);
  });

  test('a dive no trip covers joins none', () async {
    final result = await importOne(resolver: (_, _) async => null);

    expect(result.saved.tripId, isNull);
  });

  test('a failed trip lookup still imports the dive, with no trip', () async {
    final result = await importOne(
      resolver: (_, _) async => throw StateError('trips unavailable'),
    );

    expect(result.imported, 1);
    expect(result.saved.tripId, isNull);
  });

  test('without a resolver the dive joins no trip', () async {
    final result = await importOne();

    expect(result.imported, 1);
    expect(result.saved.tripId, isNull);
  });
}
