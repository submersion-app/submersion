import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' hide DiveCenter;
import 'package:submersion/features/dive_centers/data/repositories/dive_center_gear_note_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_rental_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// A dive centre's rental notes are held in its page's sitting and written
/// at Save (issue #4527, phase 3).
void main() {
  late AppDatabase db;
  final notes = DiveCenterGearNoteRepository();

  Future<DiveCenter> centre() async =>
      (await DiveCenterRepository().getDiveCenterById('c1'))!;

  DiveCenterGearNote note(String id, String label) => DiveCenterGearNote(
    id: id,
    diveCenterId: 'c1',
    gearType: EquipmentType.bcd,
    label: label,
    verdict: RentalVerdict.worked,
    notedAt: DateTime.utc(2026),
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.diveCenters)
        .insert(
          const DiveCentersCompanion(
            id: Value('c1'),
            name: Value('Reef Divers'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('added, edited and removed notes are written at Save', () async {
    final kept = await notes.create(note('', 'blue 3'));
    final gone = await notes.create(note('', 'red 1'));
    final session = EditSession(await centre());
    addTearDown(session.dispose);
    await diveCenterRentalList.load(session);

    diveCenterRentalList.set(session, [
      kept.copyWith(label: 'blue 4'),
      note('n-new', 'green 2'),
    ]);
    expect(
      {for (final n in await notes.getForCenter('c1')) n.label},
      {'blue 3', 'red 1'},
    );
    await session.runHeldWrites();

    final stored = {for (final n in await notes.getForCenter('c1')) n.id: n};
    expect(stored[kept.id]!.label, 'blue 4');
    expect(stored['n-new']!.label, 'green 2');
    expect(stored.containsKey(gone.id), isFalse);
  });

  test('a note added underneath survives a save', () async {
    final session = EditSession(await centre());
    addTearDown(session.dispose);
    await diveCenterRentalList.load(session);
    diveCenterRentalList.set(session, [note('n-new', 'green 2')]);
    // Added from a dive's Details card meanwhile.
    await notes.create(note('', 'from a dive'));

    await session.runHeldWrites();

    expect(
      {for (final n in await notes.getForCenter('c1')) n.label},
      {'green 2', 'from a dive'},
    );
  });

  test('Cancel writes no note', () async {
    final session = EditSession(await centre());
    await diveCenterRentalList.load(session);
    diveCenterRentalList.set(session, [note('n-new', 'green 2')]);

    session.dispose();

    expect(await notes.getForCenter('c1'), isEmpty);
  });

  test('a note saved unchanged leaves the list as it was', () {
    final a = note('a', 'blue 3');
    final b = note('b', 'red 1');

    expect(rentalNotesAfter([a, b], (note: a, removed: false)), [a, b]);
    expect(
      rentalNotesAfter(
        [a, b],
        (note: a.copyWith(label: 'blue 4'), removed: false),
      ).map((n) => n.id),
      ['a', 'b'],
    );
    expect(rentalNotesAfter([a, b], (note: a, removed: true)), [b]);
    expect(
      rentalNotesAfter(
        [a],
        (note: note('c', 'new'), removed: false),
      ).map((n) => n.id),
      ['a', 'c'],
    );
  });
}
