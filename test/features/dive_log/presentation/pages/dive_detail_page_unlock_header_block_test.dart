import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_hero_header.dart';
import 'package:submersion/features/dive_log/presentation/widgets/planned_dive_banner.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';

import '../../../../helpers/test_database.dart';
import 'dive_detail_page_unlock_harness.dart';

/// The dive page's header block as a card: framed and penciled when the
/// page offers editing, drawn from the sitting, and with nothing that
/// writes while locked (issue #4527, plan 4).
void main() {
  final headed = dive.copyWith(name: 'Morning drift', maxDepth: 18);

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  RecordEditController<Dive> controllerOf(WidgetTester tester) =>
      RecordEditScope.maybeOf<Dive>(
        tester.element(find.byType(RecordCardFrame<Dive>).first),
      )!;

  Finder pencil() => find.descendant(
    of: find.byType(DiveHeroHeader),
    matching: find.byType(RecordPencilDisc),
  );
  testWidgets('locked: no pencil', (tester) async {
    await pumpPage(tester, stored: headed);

    expect(pencil(), findsNothing);
  });

  // The Add strip coming in under the bar moves the whole page down a page
  // that fits (#4566); the hero itself must not grow or shift sideways.
  testWidgets('unlocked: a pencil in the title row, and the hero keeps its '
      'size', (tester) async {
    await pumpPage(tester, stored: headed);
    final locked = tester.getRect(find.byType(DiveHeroHeader));

    await unlock(tester);

    expect(pencil(), findsOneWidget);
    final unlocked = tester.getRect(find.byType(DiveHeroHeader));
    expect(unlocked.size, locked.size);
    expect(unlocked.left, locked.left);
  });

  testWidgets('the pencil opens the header card where it sits', (tester) async {
    await pumpPage(tester, stored: headed);
    await unlock(tester);
    final top = tester.getTopLeft(find.byType(DiveHeroHeader)).dy;

    await tester.tap(pencil());
    await settle(tester);

    expect(find.byType(DiveHeaderCardEditor), findsOneWidget);
    expect(find.byType(DiveHeroHeader), findsNothing);
    expect(
      tester
          .getTopLeft(
            find
                .ancestor(
                  of: find.byType(DiveHeaderCardEditor),
                  matching: find.byType(Card),
                )
                .first,
          )
          .dy,
      closeTo(top, 1),
    );
  });

  testWidgets('after Done the hero shows the sitting\'s values', (
    tester,
  ) async {
    await pumpPage(tester, stored: headed);
    await unlock(tester);
    await tester.tap(pencil());
    await settle(tester);

    controllerOf(tester).session!.set(diveNameField, 'Evening drift');
    await tester.tap(find.text('Done'));
    await settle(tester);

    expect(
      find.descendant(
        of: find.byType(DiveHeroHeader),
        matching: find.text('Evening drift'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a changed max depth shows over the viewed source; an '
      'untouched one follows it', (tester) async {
    const units = UnitFormatter(AppSettings());
    final sources = [
      DiveDataSource(
        id: 'first',
        diveId: dive.id,
        isPrimary: true,
        maxDepth: 18,
        waterTemp: 25,
        importedAt: DateTime(2023),
        createdAt: DateTime(2023),
      ),
      DiveDataSource(
        id: 'second',
        diveId: dive.id,
        isPrimary: false,
        maxDepth: 30,
        waterTemp: 22,
        importedAt: DateTime(2023),
        createdAt: DateTime(2023),
      ),
    ];
    await pumpPage(
      tester,
      stored: headed.copyWith(waterTemp: 25),
      sources: sources,
      extra: [
        activeDiveSourceProvider(dive.id).overrideWith((ref) => 'second'),
      ],
    );
    Finder hero(String text) => find.descendant(
      of: find.byType(DiveHeroHeader),
      matching: find.textContaining(text),
    );
    expect(hero(units.formatDepth(30)), findsOneWidget);

    await unlock(tester);
    controllerOf(tester).session!.set(diveMaxDepthField, 20.0);
    await settle(tester);

    expect(hero(units.formatDepth(20)), findsOneWidget);
    expect(hero(units.formatTemperature(22)), findsOneWidget);
  });

  testWidgets('dive types changed on Details redraw the closed header', (
    tester,
  ) async {
    await pumpPage(tester, stored: headed.copyWith(diveTypeIds: ['shore']));
    await unlock(tester);

    controllerOf(
      tester,
    ).session!.set(diveTypeIdsField, <String>['shore', 'night']);
    await settle(tester);

    expect(
      find.descendant(
        of: find.byType(DiveHeroHeader),
        matching: find.textContaining('Night'),
      ),
      findsWidgets,
    );
  });

  testWidgets('the banners follow the stored dive during a sitting', (
    tester,
  ) async {
    await pumpPage(tester, stored: headed);
    await unlock(tester);

    controllerOf(tester).session!.set(divePlannedField, true);
    await settle(tester);

    expect(find.byType(PlannedDiveBanner), findsNothing);
  });

  group('favourite', () {
    testWidgets('editing offered: the bar shows it as a state, with no '
        'button', (tester) async {
      await pumpPage(
        tester,
        stored: headed.copyWith(isFavorite: true),
        size: const Size(900, 1000),
      );

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byIcon(Icons.favorite),
          matching: find.byType(IconButton),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'editing offered on a phone: a state in the bar, no item in the menu',
      (tester) async {
        await pumpPage(
          tester,
          stored: headed.copyWith(isFavorite: true),
          size: const Size(560, 1000),
        );

        // PR review: with no menu item, the bar is the one place a phone
        // shows that the dive is a favourite.
        expect(find.byIcon(Icons.favorite), findsOneWidget);
        expect(
          find.ancestor(
            of: find.byIcon(Icons.favorite),
            matching: find.byType(IconButton),
          ),
          findsNothing,
        );

        await tester.tap(find.byIcon(Icons.more_vert));
        await settle(tester);

        expect(find.text('Remove from Favorites'), findsNothing);
      },
    );
  });

  testWidgets('a header changed in a sitting is saved as the header card', (
    tester,
  ) async {
    final page = await pumpPage(tester, stored: headed);
    await unlock(tester);
    await tester.tap(pencil());
    await settle(tester);

    controllerOf(tester).session!.set(diveNameField, 'Evening drift');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(page.save.calls.single.cards, [diveHeaderCardId]);
    expect(page.save.calls.single.merged.name, 'Evening drift');
  });

  testWidgets('locked, the planned banner cannot mark as logged; unlocked it '
      'can', (tester) async {
    await pumpPage(tester, stored: dive.copyWith(isPlanned: true));
    TextButton mark() => tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Mark as logged'),
    );
    expect(mark().onPressed, isNull);
    expect(find.byTooltip('Unlock to use this'), findsOneWidget);

    await unlock(tester);
    expect(mark().onPressed, isNotNull);
  });
}
