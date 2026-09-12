import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_observation_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentObservationRepository repo;

  final reg = EquipmentItem(
    id: 'reg',
    name: 'Apeks XTX',
    type: EquipmentType.regulator,
    createdAt: DateTime.utc(2026),
  );
  final dive = domain.Dive(
    id: 'd1',
    diveNumber: 12,
    dateTime: DateTime.utc(2026, 9, 9, 10),
    exitTime: DateTime.utc(2026, 9, 9, 11),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentObservationRepository(
      db: db,
      syncRepository: SyncRepository(database: db),
    );
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'reg',
            name: 'Apeks XTX',
            type: 'regulator',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: 1000,
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'kept',
            name: 'Kept',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  Future<void> pumpAndOpen(WidgetTester tester, {domain.Dive? withDive}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          currentDiverIdProvider.overrideWith(
            (ref) => MockCurrentDiverIdNotifier(),
          ),
          // The raw id above is null; the validated one falls back to the
          // default diver, as the real provider does for a stale id.
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'kept'),
          equipmentObservationRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showEquipmentObservationSheet(
                  context,
                  equipment: reg,
                  dive: withDive,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('adds an issue with tags filtered to the item type', (
    tester,
  ) async {
    await pumpAndOpen(tester, withDive: dive);
    expect(find.text('Check-in: Apeks XTX'), findsOneWidget);
    expect(find.text('No check-ins on this dive yet.'), findsOneWidget);

    await tester.tap(find.text('Add check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue'));
    await tester.pumpAndSettle();
    // Regulator tags are offered; a drysuit tag is not.
    expect(find.text('Free flow'), findsOneWidget);
    expect(find.text('Neck seal leak'), findsNothing);
    expect(find.text('Other'), findsOneWidget);

    // Saving without a tag is refused.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Pick at least one tag for an issue'), findsOneWidget);

    await tester.tap(find.text('Free flow'));
    await tester.enterText(find.byType(TextField).last, 'At 30 m');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = await repo.getForEquipmentOnDive('reg', 'd1');
    expect(stored.single.issueTags, [ObservationTag.freeFlow]);
    expect(stored.single.note, 'At 30 m');
    expect(stored.single.observedAt, DateTime.utc(2026, 9, 9, 11));
    // Back on the list, the new row shows.
    expect(find.text('Free flow'), findsOneWidget);
  });

  testWidgets('a new check-in is saved under the validated diver', (
    tester,
  ) async {
    // The raw diver id can be stale (a deleted diver) or unset; the
    // validated one is what every diver-scoped read uses, so a check-in
    // saved under the raw id would drop out of this diver's list and export.
    await pumpAndOpen(tester, withDive: dive);
    await tester.tap(find.text('Add check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await repo.getForDive('d1')).single.diverId, 'kept');
  });

  testWidgets('a failed save says so and keeps the editor usable', (
    tester,
  ) async {
    // A concurrent sync can delete the item or dive mid-save. The diver has
    // to be told the check-in was not saved, and be able to try again.
    repo = _FailingRepository(
      db: db,
      syncRepository: SyncRepository(database: db),
    );
    await pumpAndOpen(tester, withDive: dive);
    await tester.tap(find.text('Add check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'not an escaped error');
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNotNull, reason: 'the editor is still open');
  });

  testWidgets('a double-tapped Save writes one check-in', (tester) async {
    await pumpAndOpen(tester, withDive: dive);
    await tester.tap(find.text('Add check-in'));
    await tester.pumpAndSettle();
    // Both taps land before the first save completes and closes the editor.
    await tester.tap(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(await repo.getForDive('d1'), hasLength(1));
  });

  testWidgets('an OK check needs no tag and edits in place', (tester) async {
    await pumpAndOpen(tester, withDive: dive);
    await tester.tap(find.text('Add check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await repo.getForDive('d1')).single.isIssue, isFalse);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'All good');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await repo.getForDive('d1')).single.note, 'All good');
  });

  testWidgets('an issue with only unknown tags can still be edited', (
    tester,
  ) async {
    // A newer peer's tags are not shown here. Requiring a tag before the
    // save would strand the row; the unknown ones still count as its tags.
    final created = await repo.create(
      equipmentId: 'reg',
      diveId: 'd1',
      observedAt: DateTime.utc(2026),
      status: ObservationStatus.issue,
    );
    await (db.update(
      db.equipmentObservations,
    )..where((t) => t.id.equals(created.id))).write(
      const EquipmentObservationsCompanion(issueTags: Value('["futureTag"]')),
    );
    await pumpAndOpen(tester, withDive: dive);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Checked again');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Pick at least one tag for an issue'), findsNothing);
    final saved = (await repo.getForDive('d1')).single;
    expect(saved.note, 'Checked again');
    expect(saved.unrecognizedTags, ['futureTag']);
  });

  testWidgets('delete asks first and then removes the row', (tester) async {
    await repo.create(
      equipmentId: 'reg',
      diveId: 'd1',
      observedAt: DateTime.utc(2026),
      status: ObservationStatus.ok,
    );
    await pumpAndOpen(tester, withDive: dive);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete this check-in?'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(await repo.getForDive('d1'), isEmpty);
  });

  testWidgets('without a dive the editor offers a bench default', (
    tester,
  ) async {
    await pumpAndOpen(tester);
    await tester.tap(find.text('Add check-in'));
    await tester.pumpAndSettle();
    expect(find.text('No dive (bench)'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await repo.getForEquipment('reg')).single.diveId, isNull);
  });

  testWidgets('a dive-linked check-in can go back to a bench note', (
    tester,
  ) async {
    // Off a dive, the editor must offer a way back to "no dive": the dive
    // picker's dismissal keeps the current dive, so it cannot clear one.
    await repo.create(
      equipmentId: 'reg',
      diveId: 'd1',
      observedAt: DateTime.utc(2026),
      status: ObservationStatus.ok,
    );
    await pumpAndOpen(tester);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('No dive (bench)'), findsNothing);
    await tester.tap(find.byTooltip('No dive (bench)'));
    await tester.pumpAndSettle();
    expect(find.text('No dive (bench)'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await repo.getForEquipment('reg')).single.diveId, isNull);
  });

  test('defaultObservedAt prefers exit time, then start plus runtime', () {
    expect(defaultObservedAt(dive), DateTime.utc(2026, 9, 9, 11));
    final noExit = domain.Dive(
      id: 'd2',
      dateTime: DateTime.utc(2026, 9, 9, 10),
      runtime: const Duration(minutes: 50),
    );
    expect(defaultObservedAt(noExit), DateTime.utc(2026, 9, 9, 10, 50));
    expect(
      defaultObservedAt(
        domain.Dive(id: 'd3', dateTime: DateTime.utc(2026, 9, 9, 10)),
      ),
      DateTime.utc(2026, 9, 9, 10),
    );
  });
}

class _FailingRepository extends EquipmentObservationRepository {
  _FailingRepository({super.db, super.syncRepository});

  @override
  Future<EquipmentObservation> create({
    required String equipmentId,
    String? diveId,
    String? diverId,
    required DateTime observedAt,
    required ObservationStatus status,
    List<ObservationTag> issueTags = const [],
    List<String> unrecognizedTags = const [],
    String note = '',
    DateTime? now,
  }) async {
    throw StateError('FOREIGN KEY constraint failed');
  }
}
