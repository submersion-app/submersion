import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/media/data/repositories/media_people_repository.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/widgets/media_viewer_toolbar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../../helpers/test_database.dart';
import 'people_tag_test_host.dart';

/// People tags in a photo's sitting (issue #4527): tagging, moving and
/// removing are held until Save, and so is the offer to add the buddy to
/// the dive.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await seedPeopleTagFixtures();
  });
  tearDown(tearDownTestDatabase);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  RecordEditController<PhotoRecord> controller(WidgetTester tester) =>
      RecordEditScope.maybeOf<PhotoRecord>(
        tester.element(find.byType(MediaViewerToolbar)),
      )!;

  /// Opens the viewer on `p1`, unlocks it and enters tag mode.
  Future<void> openTagging(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final shown = photoItem();
    await tester.runAsync(() async {
      await tester.pumpWidget(
        await peopleTagHost(
          MediaViewerPage(mediaList: [shown], initialMediaId: shown.id),
          overrides: overrides,
        ),
      );
    });
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('viewer_unlock')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('viewer_people')));
    await settle(tester);
  }

  /// The offer to add a buddy to the dive sits over tag mode's bar.
  Future<void> dismissOffer(WidgetTester tester) async {
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .removeCurrentSnackBar();
    await settle(tester);
  }

  Future<List<MediaPeopleData>> rows(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.mediaPeople).get()))!;

  testWidgets('a placed box is a held tag; its chip and box show; no row '
      'written', (tester) async {
    await openTagging(tester);

    await tester.tapAt(const Offset(600, 450));
    await settle(tester);
    await tester.tap(find.text('Alex'));
    await settle(tester);

    expect(await rows(tester), isEmpty);
    final people = controller(tester).session!.working.people;
    expect(people.single.tag.buddyId, 'alex');
    expect(people.single.tag.box, isNotNull);
    expect(find.widgetWithText(ChoiceChip, 'Alex'), findsOneWidget);
  });

  testWidgets('a held tag removed leaves the sitting clean', (tester) async {
    await openTagging(tester);
    await tester.tapAt(const Offset(600, 450));
    await settle(tester);
    await tester.tap(find.text('Alex'));
    await settle(tester);
    await dismissOffer(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Alex'));
    await settle(tester);
    await tester.tap(find.text('Remove tag'));
    await settle(tester);

    expect(controller(tester).isDirty, isFalse);
    expect(await rows(tester), isEmpty);
  });

  testWidgets('a stored tag re-assigned and removed in the sitting is held', (
    tester,
  ) async {
    await tester.runAsync(
      () => MediaPeopleRepository().addTag(
        mediaId: 'p1',
        buddyId: 'bea',
        box: const FaceBox(x: 0.4, y: 0.4, width: 0.2, height: 0.2),
      ),
    );
    await openTagging(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Bea'));
    await settle(tester);
    await tester.tap(find.text('Change person'));
    await settle(tester);
    await tester.tap(find.text('Alex'));
    await settle(tester);

    expect((await rows(tester)).single.buddyId, 'bea');
    expect(
      controller(tester).session!.working.people.single.tag.buddyId,
      'alex',
    );
    await dismissOffer(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Alex'));
    await settle(tester);
    await tester.tap(find.text('Remove tag'));
    await settle(tester);

    expect(await rows(tester), hasLength(1));
    expect(controller(tester).session!.working.people, isEmpty);
    expect(controller(tester).isDirty, isTrue);
  });

  testWidgets('the offer\'s Add is held; Save adds the buddy', (tester) async {
    await openTagging(tester);
    await tester.tapAt(const Offset(600, 450));
    await settle(tester);
    await tester.tap(find.text('Alex'));
    await settle(tester);

    expect(find.text("Add Alex to this dive's buddies?"), findsOneWidget);
    await tester.tap(find.text('Add'));
    await settle(tester);
    final buddies = BuddyRepository();
    expect(
      await tester.runAsync(() => buddies.getBuddiesForDive('d1')),
      isEmpty,
    );

    await tester.tap(find.text('Save'));
    await settle(tester);

    final onDive = (await tester.runAsync(
      () => buddies.getBuddiesForDive('d1'),
    ))!;
    expect(onDive.single.buddy.id, 'alex');
    expect((await rows(tester)).single.buddyId, 'alex');
  });

  testWidgets('the offer goes with the sitting: Save closes it, so a late '
      'Add cannot be lost', (tester) async {
    await openTagging(tester);
    await tester.tapAt(const Offset(600, 450));
    await settle(tester);
    await tester.tap(find.text('Alex'));
    await settle(tester);
    expect(find.text("Add Alex to this dive's buddies?"), findsOneWidget);

    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(controller(tester).isUnlocked, isFalse);
    expect(find.text("Add Alex to this dive's buddies?"), findsNothing);
  });

  testWidgets('a sitting that ends while the offer is being made: no offer '
      'is left behind', (tester) async {
    final buddies = _GatedBuddies();
    await openTagging(
      tester,
      overrides: [buddyRepositoryProvider.overrideWithValue(buddies)],
    );
    await tester.tapAt(const Offset(600, 450));
    await settle(tester);
    buddies.hold = true;
    await tester.tap(find.text('Alex'));
    await settle(tester);

    controller(tester).lock();
    await settle(tester);
    await tester.runAsync(() async => buddies.gate.complete());
    await settle(tester);

    expect(find.text("Add Alex to this dive's buddies?"), findsNothing);
  });

  testWidgets('Cancel after a held Add adds nothing', (tester) async {
    await openTagging(tester);
    await tester.tapAt(const Offset(600, 450));
    await settle(tester);
    await tester.tap(find.text('Alex'));
    await settle(tester);
    await tester.tap(find.text('Add'));
    await settle(tester);

    controller(tester).lock();
    await settle(tester);

    expect(
      await tester.runAsync(() => BuddyRepository().getBuddiesForDive('d1')),
      isEmpty,
    );
    expect(await rows(tester), isEmpty);
  });

  testWidgets('the picker answering after the sitting ended changes nothing', (
    tester,
  ) async {
    await openTagging(tester);
    await tester.tapAt(const Offset(600, 450));
    await settle(tester);
    expect(find.text('Who is this?'), findsOneWidget);

    controller(tester).lock();
    await tester.tap(find.text('Alex'));
    await settle(tester);

    expect(await rows(tester), isEmpty);
    expect(controller(tester).isUnlocked, isFalse);
  });
}

/// A buddy repository whose dive buddies read waits on [gate] once [hold]
/// is set, so a test can end the sitting while the offer is being made.
class _GatedBuddies extends BuddyRepository {
  final gate = Completer<void>();
  bool hold = false;

  @override
  Future<List<BuddyWithRole>> getBuddiesForDive(String diveId) async {
    if (hold) await gate.future;
    return super.getBuddiesForDive(diveId);
  }
}
