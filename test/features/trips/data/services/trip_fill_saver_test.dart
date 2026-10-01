import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/data/services/trip_fill_passport_copy.dart';
import 'package:submersion/features/trips/data/services/trip_fill_saver.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late TripCylinderRepository repo;
  late TripFillSaver saver;
  late TripCylinder a;
  late TripCylinder b;
  final at = DateTime.utc(2026, 3, 9, 8);

  setUp(() async {
    await setUpTestDatabase();
    repo = TripCylinderRepository();
    saver = TripFillSaver(repository: repo, copier: TripFillPassportCopier());
    final now = DateTime.now();
    final tripId = (await TripRepository().createTrip(
      Trip(
        id: '',
        name: 'Bonaire',
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 14),
        createdAt: now,
        updatedAt: now,
      ),
    )).id;
    TripCylinder slot(String label, int order) => TripCylinder(
      id: '',
      tripId: tripId,
      label: label,
      sortOrder: order,
      createdAt: at,
      updatedAt: at,
    );
    a = await repo.createCylinder(slot('A', 0));
    b = await repo.createCylinder(slot('B', 1));
  });
  tearDown(tearDownTestDatabase);

  TripCylinderEvent draft(String slotId, double pressure) => TripCylinderEvent(
    id: '',
    tripCylinderId: slotId,
    kind: TripCylinderEventKind.fill,
    occurredAt: at,
    pressure: pressure,
    createdAt: at,
    updatedAt: at,
  );

  test('a second write updates the first fill, never doubles it', () async {
    final first = await saver.writeFills([draft(a.id, 200)]);
    final second = await saver.writeFills([draft(a.id, 210)]);

    final stored = await repo.getEventsForCylinder(a.id);
    expect(stored, hasLength(1));
    expect(stored.single.pressure, 210);
    expect(second.single.id, first.single.id);
  });

  test('new fills come back in the order they were given', () async {
    final written = await saver.writeFills([
      draft(b.id, 200),
      draft(a.id, 190),
    ]);
    expect(written.map((e) => e.tripCylinderId), [b.id, a.id]);
  });

  test('a slot left out of a later write loses its fill and copy', () async {
    final first = await saver.writeFills([draft(a.id, 200), draft(b.id, 200)]);
    final aFill = first.firstWhere((e) => e.tripCylinderId == a.id);
    final fills = CylinderFillRepository();
    await fills.create(
      CylinderFill(
        id: tripFillPassportCopyId(aFill.id),
        passportId: 'passport-1',
        filledAt: DateTime(2026, 3, 9, 8),
        o2Percent: 21,
        createdAt: at,
        updatedAt: at,
      ),
    );

    await saver.writeFills([draft(b.id, 205)]);

    expect(await repo.getEventsForCylinder(a.id), isEmpty);
    expect(await fills.getById(tripFillPassportCopyId(aFill.id)), isNull);
    expect((await repo.getEventsForCylinder(b.id)).single.pressure, 205);
  });

  test('an edit is written in place', () async {
    final created = (await saver.writeFills([draft(a.id, 200)])).single;
    await saver.writeEdit(created.copyWith(pressure: 180.0));
    expect((await repo.getEventsForCylinder(a.id)).single.pressure, 180);
  });

  test('passport copies skip fills whose slot is unknown', () async {
    final recording = _RecordingCopier();
    final recordingSaver = TripFillSaver(repository: repo, copier: recording);
    final created = await recordingSaver.writeFills([draft(a.id, 200)]);
    await recordingSaver.copyToPassports(created, const {});
    expect(recording.saved, isEmpty);

    await recordingSaver.copyToPassports(created, {a.id: a});
    expect(recording.saved, [created.single.id]);
  });

  test('a fill deleted before the retry is written again, not lost', () async {
    final first = (await saver.writeFills([draft(a.id, 200)])).single;
    await repo.deleteEvent(first.id);

    final again = (await saver.writeFills([draft(a.id, 210)])).single;
    final stored = await repo.getEventsForCylinder(a.id);
    expect(stored.single.id, again.id);
    expect(stored.single.pressure, 210);
  });
}

/// Records which fills reached the passport step.
class _RecordingCopier extends TripFillPassportCopier {
  final saved = <String>[];

  @override
  Future<void> afterSave(
    TripCylinderEvent event,
    TripCylinder slot, {
    String? diverId,
    String? stationName,
    bool stationResolved = true,
  }) async {
    saved.add(event.id);
  }
}
