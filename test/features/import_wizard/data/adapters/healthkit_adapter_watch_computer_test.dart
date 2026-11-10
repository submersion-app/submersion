import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/features/dive_import/data/services/apple_watch_computer.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_import/domain/services/imported_dive_converter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/import_wizard/data/adapters/healthkit_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';

import 'healthkit_adapter_test.mocks.dart';

/// Records the Apple Watch lookups and attributions.
class _Computers extends Fake implements DiveComputerRepository {
  _Computers({this.fail = false});

  final bool fail;
  final registered = <(String, String?, String?)>[];
  final attributed = <(String, String)>[];

  @override
  Future<DiveComputer?> findOrRegisterImportedComputer({
    required String model,
    String? manufacturer,
    String? serialNumber,
    String? firmwareVersion,
    String? diverId,
  }) async {
    registered.add((model, manufacturer, diverId));
    if (fail) throw StateError('computers unavailable');
    return DiveComputer(
      id: 'watch-1',
      name: 'Apple Watch',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  @override
  Future<void> attributeDiveToComputer({
    required String diveId,
    required String computerId,
  }) async => attributed.add((diveId, computerId));
}

final _start = DateTime.utc(2026, 11, 8, 9, 30);
const _diverId = 'diver-1';

/// A dive imported from Apple Health (issue #637) belongs to the diver's
/// Apple Watch computer, under an id derived from its workout.
void main() {
  late MockDiveRepository repo;
  late _Computers computers;

  setUp(() {
    repo = MockDiveRepository();
    computers = _Computers();
    when(repo.createDive(any)).thenAnswer(
      (invocation) async => invocation.positionalArguments.first as Dive,
    );
  });

  Future<Dive> importOne({_Computers? using}) async {
    final adapter = HealthKitAdapter(
      healthService: MockHealthImportService(),
      diveMatcher: MockDiveMatcher(),
      converter: const ImportedDiveConverter(),
      diveRepository: repo,
      computerRepository: using ?? computers,
      diverId: _diverId,
    );
    adapter.setParsedDives([
      ImportedDive(
        sourceId: 'workout-uuid-1',
        source: ImportSource.appleWatch,
        startTime: _start,
        endTime: _start.add(const Duration(minutes: 42)),
        maxDepth: 18.5,
        profile: const [],
      ),
    ]);
    await adapter.performImport(await adapter.buildBundle(), {
      ImportEntityType.dives: {0},
    }, {});
    return verify(repo.createDive(captureAny)).captured.single as Dive;
  }

  test('the dive is attributed to the diver\'s Apple Watch computer', () async {
    final saved = await importOne();

    expect(computers.registered, [('Apple Watch', 'Apple', _diverId)]);
    expect(computers.attributed, [(saved.id, 'watch-1')]);
  });

  test('the dive id comes from the workout and the diver', () async {
    final saved = await importOne();

    expect(
      saved.id,
      healthDiveId(diverId: _diverId, workoutUuid: 'workout-uuid-1'),
    );
  });

  test('a failed computer lookup still imports the dive', () async {
    final failing = _Computers(fail: true);

    final saved = await importOne(using: failing);

    expect(saved.id, isNotEmpty);
    expect(failing.attributed, isEmpty);
  });
}
