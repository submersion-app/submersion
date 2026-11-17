import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/change_log/presentation/change_log_labels.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_color_adjustment_repository.dart';
import 'package:submersion/features/media/data/repositories/media_people_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/repositories/site_attachment_repository.dart';
import 'package:submersion/features/media/data/services/photo_edit_save_service.dart';
import 'package:submersion/features/media/data/services/photo_record_reader.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/domain/value_objects/photo_tag_edits.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/editing/photo_held_writes.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/photo_editing_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../data/repositories/species_photo_fixtures.dart';
import 'media_viewer_unlock_harness.dart';

/// A save service whose every write fails.
class _FailingSave implements PhotoEditSaveService {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<Never>.error(StateError('the database is gone'));
}

/// The photo viewer's sitting end to end (issue #4527, plan 10).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await seedViewerData();
    await insertTestSighting(id: 'sg1', diveId: 'd1', speciesId: 'sp_turtle');
  });
  tearDown(tearDownTestDatabase);

  Future<List<Override>> asDiver() async {
    final diver = MockCurrentDiverIdNotifier();
    await diver.setCurrentDiver('me');
    return [currentDiverIdProvider.overrideWith((ref) => diver)];
  }

  Future<void> pump(
    WidgetTester tester, {
    List<Override> extra = const [],
  }) async {
    final items = await tester.runAsync(() => storedMedia(['p1', 'p2']));
    final diver = (await tester.runAsync(asDiver))!;
    await pumpViewerApp(
      tester,
      MediaViewerPage(mediaList: items!, initialMediaId: 'p2'),
      overrides: [...diver, ...extra],
    );
  }

  /// Tags the turtle, Ann without a spot, pins 2:00 and warms the colour,
  /// all through the viewer's own controls.
  Future<void> changeEverything(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('viewer_species')));
    await settleViewer(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Turtle'));
    await settleViewer(tester);
    await tester.tapAt(const Offset(640, 20));
    await settleViewer(tester);

    await tester.tap(find.byKey(const ValueKey('viewer_people')));
    await settleViewer(tester);
    await tester.tap(find.text('Tag without a spot'));
    await settleViewer(tester);
    await tester.tap(find.text('Ann'));
    await settleViewer(tester);
    // The offer to add Ann to the dive sits over tag mode's bar.
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .removeCurrentSnackBar();
    await settleViewer(tester);
    await tester.tap(find.text('Done').last);
    await settleViewer(tester);

    await tester.tap(find.byIcon(Icons.timer_off_outlined));
    await settleViewer(tester);
    await tester.enterText(find.byType(TextField), '2:00');
    await tester.tap(find.text('Save').last);
    await settleViewer(tester);

    await tester.tap(find.byKey(const ValueKey('viewer_adjust_color')));
    await settleViewer(tester);
    final slider = find.byKey(const Key('color_slider_warmth'));
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.up();
    await settleViewer(tester);
  }

  Future<List<Map<String, Object?>>> labelled() async {
    await ChangeLogRepository().settleAll();
    final rows = await db
        .customSelect(
          'SELECT label, root_table, root_id FROM change_log_operations '
          'WHERE label IS NOT NULL',
        )
        .get();
    return [for (final row in rows) row.data];
  }

  testWidgets('a change of every kind: one History entry under the dive, '
      '"Edited photo: Color, People, Species, Time in dive"', (tester) async {
    await pump(tester);
    await tapUnlock(tester);
    await changeEverything(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(RecordEditBar),
        matching: find.text('Save'),
      ),
    );
    await settleViewer(tester, rounds: 12);

    final ops = (await tester.runAsync(labelled))!;
    expect(ops, hasLength(1));
    expect(ops.single['label'], 'record_edit:media:color,people,species,time');
    expect(ops.single['root_table'], 'dives');
    expect(ops.single['root_id'], 'd1');
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(
      changeLogStoredLabel(l10n, ops.single['label']! as String),
      'Edited photo: Color, People, Species, Time in dive',
    );
    final saved = (await tester.runAsync(
      () => MediaRepository().getMediaById('p2'),
    ))!;
    expect(saved.manualElapsedSeconds, 120);
    expect(saved.colorAdjustment!.warmth, greaterThan(0));
  });

  testWidgets('Cancel after a change of every kind: every table as it was', (
    tester,
  ) async {
    await pump(tester);
    final mark = (await tester.runAsync(() => eventCount(db)))!;
    await tapUnlock(tester);
    await changeEverything(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(RecordEditBar),
        matching: find.text('Cancel'),
      ),
    );
    await settleViewer(tester);
    await tester.tap(find.text('Discard'));
    await settleViewer(tester);

    expect(find.byType(RecordEditBar), findsNothing);
    expect((await tester.runAsync(() => eventCount(db)))!, mark);
  });

  test('reverting the entry puts back the tags, the pin, the shift, the '
      'colour, the sighting and the dive buddy', () async {
    final media = MediaRepository();
    final reader = PhotoRecordReader(
      media: media,
      species: MediaSpeciesRepository(),
      people: MediaPeopleRepository(),
      tags: TagLinkRepository(TagScope.media),
    );
    final colors = MediaColorAdjustmentRepository();
    final service = PhotoEditSaveService(
      reader: reader,
      tagging: SpeciesTaggingService(
        tags: MediaSpeciesRepository(),
        media: media,
        species: SpeciesRepository(),
      ),
      people: MediaPeopleRepository(),
      media: media,
      colors: colors,
      attachments: SiteAttachmentRepository(),
      dives: DiveRepository(),
      tags: TagLinkRepository(TagScope.media),
    );
    await insertTestSpecies(id: 'sp_ray', name: 'Ray');
    final before = (await reader.read('p2', diverId: 'me'))!;
    final sitting = EditSession<PhotoRecord>(before);
    addTearDown(sitting.dispose);
    sitting
      ..set(
        photoSpeciesField,
        SpeciesTagEdits.none.toggled(
          const SpeciesTagChip(
            speciesId: 'sp_ray',
            storedName: 'Ray',
            category: SpeciesCategory.fish,
            isBuiltIn: false,
          ),
          tagged: true,
          stored: const [],
        ),
      )
      ..set(
        photoPeopleField,
        PersonTagEdits.none.add(
          MediaPersonChip(
            tag: MediaPersonTag(
              id: 'local',
              mediaId: 'p2',
              buddyId: 'b1',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
            ),
          ),
          stored: const [],
          isVideo: false,
        ),
      )
      ..set(photoPinField, 90)
      ..set(photoDiveShiftField, 30)
      ..set(photoColorField, const ColorAdjustment(warmth: 0.5));
    holdAddBuddyToDive(
      sitting,
      diveId: 'd1',
      buddyId: 'b1',
      repository: BuddyRepository(),
    );
    await ChangeLogRepository().settleAll();
    await db.customStatement('DELETE FROM change_log_operations');

    await service.save(
      mediaId: 'p2',
      diverId: 'me',
      apply: sitting.applyTo,
      changedCardIds: sitting.changedCardIds,
      alsoWrite: sitting.runHeldWrites,
      alsoWriteIsAChange: true,
    );
    final saved = (await reader.read('p2', diverId: 'me'))!;
    expect(saved.species, hasLength(1));
    expect(await SpeciesRepository().getSightingsForDive('d1'), hasLength(2));
    expect(await BuddyRepository().getBuddiesForDive('d1'), hasLength(1));

    final operationId = (await labelledOperationIds(db)).single;
    final revert = ChangeLogRevertService(afterDiveWrites: (_) {});
    await revert.execute(await revert.planOperation(operationId));

    final reverted = (await reader.read('p2', diverId: 'me'))!;
    expect(reverted.species, isEmpty);
    expect(reverted.people, isEmpty);
    expect(reverted.item.manualElapsedSeconds, isNull);
    expect(reverted.diveShiftSeconds, 0);
    expect(reverted.item.colorAdjustment, isNull);
    expect(await SpeciesRepository().getSightingsForDive('d1'), hasLength(1));
    expect(await BuddyRepository().getBuddiesForDive('d1'), isEmpty);
  });

  testWidgets('a Save that fails: nothing written, still unlocked, the '
      'changes shown', (tester) async {
    await pump(
      tester,
      extra: [photoEditSaveServiceProvider.overrideWithValue(_FailingSave())],
    );
    final mark = (await tester.runAsync(() => eventCount(db)))!;
    await tapUnlock(tester);
    photoController(tester).session!.set(photoPinField, 120);
    await settleViewer(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(RecordEditBar),
        matching: find.text('Save'),
      ),
    );
    await settleViewer(tester);

    expect(
      find.text("Couldn't save your changes. Nothing was changed."),
      findsOneWidget,
    );
    expect(photoController(tester).isDirty, isTrue);
    expect(find.text('+2:00'), findsOneWidget);
    expect((await tester.runAsync(() => eventCount(db)))!, mark);
  });

  testWidgets('in imperial units the held time\'s depth follows the diver', (
    tester,
  ) async {
    await pump(
      tester,
      extra: [
        settingsProvider.overrideWith(
          (ref) => MockSettingsNotifier(
            const AppSettings(depthUnit: DepthUnit.feet),
          ),
        ),
      ],
    );
    await tapUnlock(tester);

    await tester.tap(find.byIcon(Icons.timer_off_outlined));
    await settleViewer(tester);
    await tester.enterText(find.byType(TextField), '2:00');
    await tester.tap(find.text('Save').last);
    await settleViewer(tester);

    expect(find.text('+2:00'), findsOneWidget);
    expect(find.text('39.4ft'), findsOneWidget);
  });
}

/// The ids of the operations a sitting labelled.
Future<List<String>> labelledOperationIds(AppDatabase db) async {
  await ChangeLogRepository().settleAll();
  final rows = await db
      .customSelect(
        'SELECT id FROM change_log_operations WHERE label IS NOT NULL',
      )
      .get();
  return [for (final row in rows) row.read<String>('id')];
}
