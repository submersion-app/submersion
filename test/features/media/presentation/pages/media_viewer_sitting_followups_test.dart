import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/services/photo_edit_save_service.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/domain/value_objects/photo_tag_edits.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/pages/photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/photo_editing_providers.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/color_adjust_panel.dart';
import 'package:submersion/features/media/presentation/widgets/color_adjust/pick_white_hint.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import '../../../../helpers/test_database.dart';
import 'media_viewer_unlock_harness.dart';

/// A save that waits on [gate], then finds the photo gone.
class _GoneOnSave implements PhotoEditSaveService {
  final gate = Completer<void>();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      gate.future.then<Never>((_) => throw PhotoGoneError('p2'));
}

/// The photo viewer's sitting at its edges (issue #4527): Escape backing out
/// one step at a time, the people tag selection while the sitting follows
/// its photo, and a photo deleted while its save runs.
void main() {
  setUp(() async {
    await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await seedViewerData();
  });
  tearDown(tearDownTestDatabase);

  Future<void> escape(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settleViewer(tester);
  }

  testWidgets('Escape closes Pick white, then the colour panel, and keeps '
      'the sitting', (tester) async {
    await pumpViewer(tester);
    await tapUnlock(tester);
    photoController(
      tester,
    ).session!.set(photoColorField, const ColorAdjustment(warmth: 0.3));
    await tester.tap(find.byKey(const ValueKey('viewer_adjust_color')));
    await settleViewer(tester);
    await tester.tap(find.text('Pick white'));
    await settleViewer(tester);
    expect(find.byType(PickWhiteHint), findsOneWidget);

    await escape(tester);
    expect(find.byType(PickWhiteHint), findsNothing);
    expect(find.byType(ColorAdjustPanel), findsOneWidget);

    await escape(tester);
    expect(find.byType(ColorAdjustPanel), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(photoController(tester).isDirty, isTrue);
  });

  testWidgets('the colour panel is handed the held colour, so a released '
      'slider stays where it was let go', (tester) async {
    await pumpViewer(tester);
    await tapUnlock(tester);
    await tester.tap(find.byKey(const ValueKey('viewer_adjust_color')));
    await settleViewer(tester);

    const held = ColorAdjustment(warmth: 0.4);
    photoController(tester).session!.set(photoColorField, held);
    await settleViewer(tester);

    final panel = tester.widget<ColorAdjustPanel>(
      find.byType(ColorAdjustPanel),
    );
    expect(panel.item.colorAdjustment, held);
  });

  testWidgets('following the sitting\'s photo keeps the selected tag', (
    tester,
  ) async {
    await pumpViewerApp(
      tester,
      const PhotoViewerPage(diveId: 'd1', initialMediaId: 'p2'),
    );
    await tapUnlock(tester);
    final now = DateTime(2024, 1, 10);
    photoController(tester).session!.set(
      photoPeopleField,
      PersonTagEdits(
        added: [
          MediaPersonChip(
            tag: MediaPersonTag(
              id: 'held-ann',
              mediaId: 'p2',
              buddyId: 'b1',
              box: const FaceBox(x: 0.4, y: 0.4, width: 0.2, height: 0.2),
              createdAt: now,
              updatedAt: now,
            ),
            buddyName: 'Ann',
          ),
        ],
      ),
    );
    await tester.tap(find.byKey(const ValueKey('viewer_people')));
    await settleViewer(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ann'));
    await settleViewer(tester);
    bool annSelected() => tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Ann'))
        .selected;
    expect(annSelected(), isTrue);

    await tester.runAsync(() => MediaRepository().deleteMedia('p1'));
    await settleViewer(tester, rounds: 10);

    expect(annSelected(), isTrue);
  });

  testWidgets('a held untag the store has made moot leaves the sitting '
      'clean', (tester) async {
    await tester.runAsync(
      () => MediaSpeciesRepository().addTag(
        mediaId: 'p2',
        speciesId: 'sp_turtle',
      ),
    );
    await pumpViewer(tester);
    await tapUnlock(tester);
    final session = photoController(tester).session!;
    session.set(
      photoSpeciesField,
      session
          .valueOf(photoSpeciesField)
          .toggled(
            session.stored.species.single,
            tagged: false,
            stored: session.stored.species,
          ),
    );
    await settleViewer(tester);
    expect(photoController(tester).isDirty, isTrue);

    // Another device untags it too.
    await tester.runAsync(
      () => MediaSpeciesRepository().removeTag(
        mediaId: 'p2',
        speciesId: 'sp_turtle',
      ),
    );
    await settleViewer(tester, rounds: 10);

    expect(photoController(tester).isDirty, isFalse);
  });

  testWidgets('the photo deleted while its save runs: one message, and the '
      'sitting ends', (tester) async {
    final save = _GoneOnSave();
    await pumpViewerApp(
      tester,
      const PhotoViewerPage(diveId: 'd1', initialMediaId: 'p2'),
      overrides: [photoEditSaveServiceProvider.overrideWithValue(save)],
    );
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

    await tester.runAsync(() => MediaRepository().deleteMedia('p2'));
    await settleViewer(tester, rounds: 10);
    expect(
      find.text('This photo was removed. Your changes were not saved.'),
      findsNothing,
      reason: 'the save is still running',
    );

    save.gate.complete();
    await settleViewer(tester, rounds: 10);

    expect(
      find.text('This photo was removed. Your changes were not saved.'),
      findsOneWidget,
    );
    expect(
      find.text("Couldn't save your changes. Nothing was changed."),
      findsNothing,
    );
    expect(find.byType(RecordEditBar), findsNothing);
  });
}
