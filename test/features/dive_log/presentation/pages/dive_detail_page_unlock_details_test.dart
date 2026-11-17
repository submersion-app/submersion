import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/courses/presentation/widgets/course_picker.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/visibility_input_mode_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_visibility_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/suggested_text_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_entry.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_date_stretch.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// A device that cannot store which visibility input was used last.
class _FailingMode extends VisibilityInputModeNotifier {
  _FailingMode(super.prefs);

  @override
  Future<void> remember(VisibilityInputMode mode) async =>
      throw StateError('the preference could not be written');
}

/// The Details card on the unlocked dive page, saved through the page
/// (issue #4527).
void main() {
  final l = AppLocalizationsEn();
  final epoch = DateTime(2024);
  final trip = Trip(
    id: 'trip',
    name: 'Red Sea North',
    startDate: DateTime(2023, 1, 1),
    endDate: DateTime(2023, 1, 7),
    createdAt: epoch,
    updatedAt: epoch,
  );
  final center = DiveCenter(
    id: 'center',
    name: 'Blue Hole Divers',
    createdAt: epoch,
    updatedAt: epoch,
  );
  const saltSite = DiveSite(
    id: 'site',
    name: 'Blue Hole',
    waterType: WaterType.salt,
  );
  // On a trip, at a center, at a site with a water type and none of its
  // own, with a measured visibility.
  final rich = dive.copyWith(
    trip: trip,
    tripId: trip.id,
    diveCenter: center,
    site: saltSite,
    diveOperator: 'Emperor Divers',
    visibilityMeters: 12,
    diveTypeIds: const ['wreck', 'night'],
  );
  const visible = {DiveDetailSectionId.details, DiveDetailSectionId.notes};
  const tall = Size(700, 3400);
  const saveFailed = "Couldn't save your changes. Nothing was changed.";

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  RecordEditController<Dive> controller(WidgetTester tester) => tester
      .widget<RecordEditScope<Dive>>(find.byType(RecordEditScope<Dive>))
      .notifier!;

  Future<void> openDetails(WidgetTester tester) async {
    await unlock(tester);
    await tester.tap(find.byTooltip('Edit Details'));
    await settle(tester);
  }

  /// The field of the operator row, which keeps its field mounted.
  final operatorField = find.descendant(
    of: find.byType(SuggestedTextRow).first,
    matching: find.byType(TextFormField),
  );

  final visibilityField = find.descendant(
    of: find.byType(DiveVisibilityRow),
    matching: find.byType(TextFormField),
  );

  /// Opens the Precise visibility row and types [text] a character at a
  /// time, as a diver does.
  Future<void> typeVisibility(WidgetTester tester, String text) async {
    if (visibilityField.evaluate().isEmpty) {
      await tester.tap(find.text(l.diveLog_edit_label_visibility));
      await settle(tester);
    }
    for (var end = 1; end <= text.length; end++) {
      await tester.enterText(visibilityField, text.substring(0, end));
      await tester.pump();
    }
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await settle(tester);
  }

  testWidgets('unlocked, Details has a pencil', (tester) async {
    await pumpPage(tester, visible: visible, size: tall);
    await unlock(tester);

    expect(find.byTooltip('Edit Details'), findsOneWidget);
  });

  testWidgets('hidden by the diver, Details is offered in the strip', (
    tester,
  ) async {
    await pumpPage(
      tester,
      visible: const {DiveDetailSectionId.notes},
      size: tall,
    );
    await unlock(tester);
    expect(find.byTooltip('Edit Details'), findsNothing);

    await tapStripChip(tester, DiveDetailSectionId.details.name);
    await settle(tester);

    expect(find.byType(DiveDetailsCardEditor), findsOneWidget);
  });

  testWidgets('opening and closing Details in imperial units leaves the '
      'sitting clean', (tester) async {
    final page = await pumpPage(
      tester,
      stored: rich,
      visible: visible,
      size: tall,
      imperial: true,
    );
    await openDetails(tester);

    // Into every field of the card that takes typing, one after another.
    for (var row = 0; row < 3; row++) {
      await tester.tap(
        find.descendant(
          of: find.byType(SuggestedTextRow).at(row),
          matching: find.byType(TextFormField),
        ),
      );
      await tester.pump();
    }
    await tester.tap(find.text(l.diveLog_edit_label_visibility));
    await settle(tester);
    await tester.tap(find.text('Done'));
    await settle(tester);

    expect(find.byType(DiveDetailsCardEditor), findsNothing);
    expect(action(tester, 'Save').onPressed, isNull);
    expect(page.save.calls, isEmpty);
  });

  testWidgets('a visibility typed digit by digit is saved, and one typed '
      'back is not', (tester) async {
    final page = await pumpPage(
      tester,
      stored: rich,
      visible: visible,
      size: tall,
      imperial: true,
    );
    await openDetails(tester);

    // 12 m shows as 39 ft.
    await typeVisibility(tester, '40');
    await save(tester);

    expect(page.save.calls.single.cards, ['details']);
    expect(
      page.save.calls.single.merged.visibilityMeters,
      closeTo(12.192, 1e-5),
    );

    // The dive now shows 40 ft. Typing that again is no change.
    await openDetails(tester);
    await typeVisibility(tester, '40');

    expect(action(tester, 'Save').onPressed, isNull);
  });

  testWidgets('unreadable visibility: Done and Save both refuse', (
    tester,
  ) async {
    final page = await pumpPage(
      tester,
      stored: rich,
      visible: visible,
      size: tall,
    );
    await openDetails(tester);
    await tester.enterText(operatorField, 'Aggressor');
    await typeVisibility(tester, '1x');

    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.byType(DiveDetailsCardEditor), findsOneWidget);

    await save(tester);
    expect(page.save.calls, isEmpty);
    expect(find.text(l.recordEdit_fixInvalid), findsOneWidget);
    expect(find.byTooltip('Unlock to edit'), findsNothing);
  });

  testWidgets('clearing the trip saves a dive with no trip and no trip id', (
    tester,
  ) async {
    final page = await pumpPage(
      tester,
      stored: rich,
      visible: visible,
      size: tall,
    );
    await openDetails(tester);

    // The trip row's clear is the first on the card.
    await tester.tap(find.byIcon(Icons.clear).first);
    await settle(tester);
    await save(tester);

    final merged = page.save.calls.single.merged;
    expect(merged.trip, isNull);
    expect(merged.tripId, isNull);
    expect(merged.diveCenter?.id, 'center');
  });

  testWidgets('the site\'s water type is not saved by editing something '
      'else', (tester) async {
    final page = await pumpPage(
      tester,
      stored: rich,
      visible: visible,
      size: tall,
    );
    await openDetails(tester);
    // The row shows the site's water type, as the read card does.
    expect(find.text(l.enum_waterType_salt), findsOneWidget);

    await tester.enterText(operatorField, 'Aggressor');
    await tester.pump();
    await save(tester);

    final merged = page.save.calls.single.merged;
    expect(merged.diveOperator, 'Aggressor');
    expect(merged.waterType, isNull);
  });

  testWidgets('a trip whose dates the save moved is named afterwards', (
    tester,
  ) async {
    final page = await pumpPage(
      tester,
      stored: rich,
      visible: visible,
      size: tall,
    );
    page.save.tripDateStretches = [
      TripDateStretch(
        tripId: 'trip',
        tripName: 'Red Sea North',
        priorStart: DateTime(2023, 1, 3),
        priorEnd: DateTime(2023, 1, 7),
        start: DateTime(2023, 1, 1),
        end: DateTime(2023, 1, 7),
      ),
    ];
    await openDetails(tester);
    await tester.enterText(operatorField, 'Aggressor');
    await tester.pump();

    await save(tester);

    expect(find.textContaining('Red Sea North now runs'), findsOneWidget);
    expect(find.byTooltip('Unlock to edit'), findsOneWidget);
  });

  testWidgets('a save that moved no trip says nothing about one', (
    tester,
  ) async {
    await pumpPage(tester, stored: rich, visible: visible, size: tall);
    await openDetails(tester);
    await tester.enterText(operatorField, 'Aggressor');
    await tester.pump();

    await save(tester);

    expect(find.textContaining('now runs'), findsNothing);
  });

  testWidgets('changing courses reads the dive\'s courses again', (
    tester,
  ) async {
    Course course(String id) => Course(
      id: id,
      diverId: 'me',
      name: 'Course $id',
      agency: 'padi',
      startDate: epoch,
      createdAt: epoch,
      updatedAt: epoch,
    );
    var reads = 0;
    await pumpPage(
      tester,
      stored: rich.copyWith(courseIds: const ['c1']),
      visible: visible,
      size: tall,
      extra: [
        coursesForDiveProvider(dive.id).overrideWith((ref) async {
          reads++;
          return [course('c1')];
        }),
      ],
    );
    await openDetails(tester);
    tester
        .widget<CourseMultiSelectField>(find.byType(CourseMultiSelectField))
        .onChanged(['c1', 'c2']);
    await tester.pump();
    final before = reads;

    await save(tester);

    expect(reads, greaterThan(before));
  });

  testWidgets('a save that left the courses alone does not read them '
      'again', (tester) async {
    var reads = 0;
    await pumpPage(
      tester,
      stored: rich.copyWith(courseIds: const ['c1']),
      visible: visible,
      size: tall,
      extra: [
        coursesForDiveProvider(dive.id).overrideWith((ref) async {
          reads++;
          return const <Course>[];
        }),
      ],
    );
    await openDetails(tester);
    await tester.enterText(operatorField, 'Aggressor');
    await tester.pump();
    final before = reads;

    await save(tester);

    expect(reads, before);
  });

  group('the remembered visibility input', () {
    VisibilityInputMode remembered(WidgetTester tester) =>
        ProviderScope.containerOf(
          tester.element(find.byType(DiveDetailPage)),
        ).read(visibilityInputModeProvider);

    testWidgets('a new visibility is remembered as the input mode', (
      tester,
    ) async {
      final page = await pumpPage(tester, visible: visible, size: tall);
      expect(remembered(tester), VisibilityInputMode.precise);
      await openDetails(tester);
      await tester.tap(find.text(l.diveLog_edit_visibility_modeRange));
      await settle(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Good'));
      await settle(tester);

      await save(tester);

      expect(
        StoredVisibility.of(page.save.calls.single.merged).range,
        VisibilityScale.tropical.rangeFor(VisibilityBand.good),
      );
      expect(remembered(tester), VisibilityInputMode.range);
    });

    testWidgets('a save that left the visibility alone remembers nothing', (
      tester,
    ) async {
      final good = VisibilityScale.tropical.rangeFor(VisibilityBand.good);
      await pumpPage(
        tester,
        stored: rich.copyWith(
          visibilityMeters: null,
          clearVisibilityMeters: true,
          visibilityMinMeters: good.minM,
          visibilityMaxMeters: good.maxM,
        ),
        visible: visible,
        size: tall,
      );
      await openDetails(tester);
      await tester.enterText(operatorField, 'Aggressor');
      await tester.pump();

      await save(tester);

      expect(remembered(tester), VisibilityInputMode.precise);
    });

    testWidgets('a device whose input mode cannot be read still saves', (
      tester,
    ) async {
      final page = await pumpPage(
        tester,
        visible: visible,
        size: tall,
        extra: [
          visibilityInputModeProvider.overrideWith(
            (ref) => throw StateError('no preferences on this device'),
          ),
        ],
      );
      await unlock(tester);
      await tester.tap(find.byTooltip('Edit Notes'));
      await settle(tester);
      controller(tester).session!.set(diveNotesField, 'Current');
      await settle(tester);

      await save(tester);

      expect(page.save.calls.single.merged.notes, 'Current');
      expect(find.text(saveFailed), findsNothing);
      expect(find.byTooltip('Unlock to edit'), findsOneWidget);
    });

    testWidgets('a mode that cannot be remembered is not a failed save', (
      tester,
    ) async {
      final page = await pumpPage(
        tester,
        visible: visible,
        size: tall,
        extra: [
          visibilityInputModeProvider.overrideWith(
            (ref) => _FailingMode(ref.watch(sharedPreferencesProvider)),
          ),
        ],
      );
      await openDetails(tester);
      await typeVisibility(tester, '15');

      await save(tester);

      expect(page.save.calls.single.merged.visibilityMeters, 15);
      expect(find.text(saveFailed), findsNothing);
      expect(find.byTooltip('Unlock to edit'), findsOneWidget);
    });
  });

  testWidgets('an exclusion switched on shows on the closed card, and after '
      'the save', (tester) async {
    final page = await pumpPage(tester, visible: visible, size: tall);
    await openDetails(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('dive-edit-exclude-from-stats')),
        matching: find.byType(Switch),
      ),
    );
    await settle(tester);

    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.text(l.diveLog_edit_summary_excluded), findsOneWidget);

    await save(tester);
    expect(page.save.calls.single.merged.excludedFromStats, isTrue);
    expect(find.text(l.diveLog_edit_summary_excluded), findsOneWidget);
  });

  testWidgets('two cards changed in one sitting are one save naming both', (
    tester,
  ) async {
    final page = await pumpPage(tester, visible: visible, size: tall);
    await openDetails(tester);
    await tester.enterText(operatorField, 'Aggressor');
    await tester.pump();
    controller(tester).session!.set(diveNotesField, 'Current');
    await settle(tester);

    await save(tester);

    expect(page.save.calls, hasLength(1));
    expect(page.save.calls.single.cards.toSet(), {'details', 'notes'});
  });

  testWidgets('Cancel after taking a suggested trip leaves the dive as it '
      'was', (tester) async {
    final page = await pumpPage(
      tester,
      visible: visible,
      size: tall,
      extra: [tripForDateProvider.overrideWith((ref, day) async => trip)],
    );
    await openDetails(tester);
    await tester.tap(find.text(l.diveLog_edit_tripUse));
    await settle(tester);
    expect(controller(tester).session!.working.tripId, 'trip');

    await tester.tap(find.text('Cancel'));
    await settle(tester);
    await tester.tap(find.text('Discard'));
    await settle(tester);

    expect(find.byTooltip('Unlock to edit'), findsOneWidget);
    expect(page.save.calls, isEmpty);
    expect(find.text('Red Sea North'), findsNothing);
  });
}
