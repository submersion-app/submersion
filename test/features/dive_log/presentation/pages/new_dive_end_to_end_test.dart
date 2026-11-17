import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive, Trip;
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/new_dive_request.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_notes_card_editor.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_new_dive_harness.dart';
import 'dive_detail_page_unlock_harness.dart';

/// A new dive saved by the real save service on the test database: nothing
/// is written before Save, Save writes one dive and one History entry, and a
/// Save that fails leaves nothing (issue #4527, plan 8).
void main() {
  late AppDatabase db;
  final changeLog = ChangeLogRepository();

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
  });
  tearDown(tearDownTestDatabase);

  Future<Map<String, int>> counts(WidgetTester tester) async {
    final result = await tester.runAsync(() async {
      await changeLog.settleAll();
      final out = <String, int>{};
      for (final table in [
        'dives',
        'dive_safety_findings',
        'tide_records',
        'media',
        'change_log_operations',
      ]) {
        final row = await db
            .customSelect('SELECT COUNT(*) AS n FROM $table')
            .getSingle();
        out[table] = row.read<int>('n');
      }
      return out;
    });
    return result!;
  }

  Future<List<Map<String, Object?>>> operations(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        await changeLog.settleAll();
        final rows = await db
            .customSelect('SELECT label, source FROM change_log_operations')
            .get();
        return [for (final r in rows) r.data];
      }))!;

  Future<void> typeNote(WidgetTester tester, String text) async {
    final field = find.descendant(
      of: find.byType(DiveNotesCardEditor),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await settle(tester);
  }

  /// Taps Save and lets the real write and its follow-up run.
  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await settle(tester);
    }
  }

  testWidgets('opening a new dive and cancelling writes nothing', (
    tester,
  ) async {
    final before = await counts(tester);
    final page = await pumpNewDivePage(tester, realSave: true);
    await typeNote(tester, 'Wall');
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    await tester.tap(find.text('Discard'));
    await settle(tester);

    expect(location(page.router), '/home');
    expect(await counts(tester), before);
  });

  testWidgets('Save writes one dive and one History entry', (tester) async {
    final page = await pumpNewDivePage(tester, realSave: true);
    final id = newDiveController(tester).session!.stored.id;
    await typeNote(tester, 'Wall');
    await save(tester);

    final notes = await tester.runAsync(
      () => db
          .customSelect(
            'SELECT notes FROM dives WHERE id = ?',
            variables: [Variable<String>(id)],
          )
          .getSingle(),
    );
    expect(notes!.read<String>('notes'), 'Wall');
    final ops = await operations(tester);
    expect(ops, hasLength(1));
    expect(
      ops.single['label'],
      RecordEditLabel.encode(table: 'dives', id: id, cardIds: ['notes']),
    );
    expect(location(page.router), '/dives/$id');
  });

  testWidgets('a Save that fails leaves nothing, and saves on the second try', (
    tester,
  ) async {
    final page = await pumpNewDivePage(tester, realSave: true);
    final session = newDiveController(tester).session!;
    await typeNote(tester, 'Wall');
    // A held write that throws inside the transaction, after the dive.
    session.holdChange(
      'boom',
      cardId: 'notes',
      write: () async => throw StateError('disk full'),
    );
    final before = await counts(tester);
    await save(tester);

    expect(await counts(tester), before);
    expect(newDiveController(tester).isUnlocked, isTrue);
    expect(location(page.router), '/home/new');

    newDiveController(tester).session!.releaseWrite('boom');
    await save(tester);
    expect((await counts(tester))['dives'], before['dives']! + 1);
    expect(location(page.router), startsWith('/dives/'));
  });

  testWidgets('a new dive on a trip stretches the trip to cover it', (
    tester,
  ) async {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    await tester.runAsync(
      () => TripRepository().createTrip(
        Trip(
          id: 'trip',
          name: 'Earlier',
          startDate: DateTime(2020, 1, 5),
          endDate: DateTime(2020, 1, 7),
          createdAt: epoch,
          updatedAt: epoch,
        ),
      ),
    );
    await pumpNewDivePage(
      tester,
      realSave: true,
      request: const NewDiveRequest(tripId: 'trip'),
    );
    await save(tester);

    final trip = await tester.runAsync(
      () => TripRepository().getTripById('trip'),
    );
    expect(trip!.endDate.year, greaterThan(2020));
  });
}
