import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_import/data/services/additional_computer_writer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';

import '../../../../helpers/test_database.dart';

/// Fails the write for one computer model, as a codec refusal or a database
/// error would, and hands every other one to the real repository.
class _FailingForModel implements DiveRepository {
  _FailingForModel(this.model);

  final String model;
  final _real = DiveRepository();

  @override
  Future<void> saveAdditionalComputerReading({
    required DiveDataSourcesCompanion reading,
    required List<DiveProfilePoint> profile,
    List<ProfileEvent> events = const [],
  }) async {
    if (reading.computerModel.value == model) {
      throw StateError('unwritable $model');
    }
    return _real.saveAdditionalComputerReading(
      reading: reading,
      profile: profile,
      events: events,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  });

  tearDown(() async => tearDownTestDatabase());

  Map<String, dynamic> computer(String model) => {
    'diveComputerModel': model,
    'timeOffsetSeconds': 0,
    'profile': [
      {'timestamp': 0, 'depth': 0.0},
      {'timestamp': 600, 'depth': 30.0},
    ],
  };

  test('one unwritable computer does not cost the others', () async {
    // The dive is already committed when this runs, so a throw would abort
    // the rest of the logbook import. A further computer is best-effort.
    await AdditionalComputerWriter(
      diveRepository: _FailingForModel('Shearwater Teric'),
      tankPressureRepository: TankPressureRepository(),
    ).write(
      computers: [computer('Shearwater Teric'), computer('Suunto D5')],
      diveId: 'dive-1',
      entryTime: null,
      tankIds: const [],
      usedComputerIds: const [],
      computerIdFor: (_) => null,
      sourceFileName: 'log.ssrf',
      sourceFileFormat: 'subsurfaceXml',
      now: DateTime.utc(2025, 3, 10),
    );

    final rows = await db.select(db.diveDataSources).get();
    expect(rows.map((r) => r.computerModel), ['Suunto D5']);
  });
}
