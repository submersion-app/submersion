import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_altitude_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_site_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_hero_header.dart';
import 'package:submersion/features/dive_log/presentation/widgets/site_suggestion_card.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_suggestion_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/test_database.dart';
import '../support/fake_matching_service.dart';
import 'dive_detail_page_unlock_harness.dart';

/// The header block edited in place on the dive page, end to end: the
/// site and the values it sets on the other cards, the times, the planned
/// switch, favourite, and the suggestion, through one Save (issue #4527,
/// plan 4).
void main() {
  final entry = DateTime.utc(2023, 1, 1, 9, 42, 27);
  final exit = DateTime.utc(2023, 1, 1, 10, 34, 51);
  final headed = dive.copyWith(
    name: 'Morning drift',
    dateTime: entry,
    entryTime: entry,
    exitTime: exit,
    runtime: const Duration(minutes: 52, seconds: 24),
    maxDepth: 12.41,
    avgDepth: 8.37,
    waterTemp: 27.4,
    rating: 4,
  );
  const reef = DiveSite(
    id: 'reef',
    name: 'Reef',
    waterType: WaterType.salt,
    entryMethods: [EntryMethod.shore],
    altitude: 900,
  );

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  RecordEditController<Dive> controllerOf(WidgetTester tester) =>
      RecordEditScope.maybeOf<Dive>(
        tester.element(find.byType(SiteSuggestionCard).first),
      )!;

  Future<void> openHeader(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Edit Dive'));
    await settle(tester);
  }

  Future<void> done(WidgetTester tester) async {
    await tester.tap(find.text('Done'));
    await settle(tester);
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await settle(tester);
  }

  void assign(WidgetTester tester, DiveSite? site) => readDiveSiteAssigner(
    tester.element(find.byType(SiteSuggestionCard).first),
  )(controllerOf(tester).session!, site);

  testWidgets('the header has a pencil, and its editor opens where the hero '
      'was', (tester) async {
    await pumpPage(tester, stored: headed);
    await unlock(tester);
    final top = tester.getTopLeft(find.byType(DiveHeroHeader)).dy;

    await openHeader(tester);

    expect(find.byType(DiveHeaderCardEditor), findsOneWidget);
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

  testWidgets('opening and closing the header in imperial units leaves the '
      'sitting clean', (tester) async {
    await pumpPage(tester, stored: headed, imperial: true);
    await unlock(tester);
    await openHeader(tester);
    await done(tester);

    expect(action(tester, 'Save').onPressed, isNull);
  });

  testWidgets('a site picked in the header gives Details, Environment and '
      'Altitude their dots, and Save names all four', (tester) async {
    final page = await pumpPage(tester, stored: headed);
    await unlock(tester);
    await openHeader(tester);

    assign(tester, reef);
    await settle(tester);
    await done(tester);
    await save(tester);

    final call = page.save.calls.single;
    expect(call.cards.toSet(), {
      diveHeaderCardId,
      'details',
      'environment',
      'altitude',
    });
    expect(call.merged.site?.id, 'reef');
    expect(call.merged.waterType, WaterType.salt);
    expect(call.merged.entryMethod, EntryMethod.shore);
    expect(call.merged.altitude, 900);
  });

  testWidgets('the Altitude card a site brings waits for the header to '
      'close', (tester) async {
    await pumpPage(
      tester,
      stored: headed,
      size: const Size(700, 2400),
      visible: const {DiveDetailSectionId.altitude, DiveDetailSectionId.notes},
    );
    await unlock(tester);
    await openHeader(tester);

    assign(tester, reef);
    await settle(tester);

    expect(find.byType(DiveAltitudeSection), findsNothing);

    await done(tester);

    expect(find.byType(DiveAltitudeSection), findsOneWidget);
  });

  testWidgets('Cancel after picking a site leaves the dive as it was', (
    tester,
  ) async {
    final page = await pumpPage(tester, stored: headed);
    await unlock(tester);
    assign(tester, reef);
    await settle(tester);

    await tester.tap(find.text('Cancel'));
    await settle(tester);
    await tester.tap(find.text('Discard'));
    await settle(tester);

    expect(page.save.calls, isEmpty);
    expect(page.save.stored.site, isNull);
  });

  testWidgets('a runtime typed digit by digit is saved with the exit it '
      'moved', (tester) async {
    final page = await pumpPage(tester, stored: headed);
    await unlock(tester);
    await openHeader(tester);

    await tester.tap(find.text('52 min'));
    await tester.pump();
    for (final text in ['6', '60']) {
      await tester.enterText(find.byType(TextFormField).first, text);
      await tester.pump();
    }
    await done(tester);
    await save(tester);

    final merged = page.save.calls.single.merged;
    expect(merged.runtime, const Duration(hours: 1));
    expect(merged.exitTime, entry.add(const Duration(hours: 1)));
    expect(merged.entryTime, entry);
  });

  testWidgets('the planned switch turned on saves a plan with no number', (
    tester,
  ) async {
    final page = await pumpPage(tester, stored: headed);
    await unlock(tester);
    await openHeader(tester);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('dive_edit_planned_switch')),
        matching: find.byType(Switch),
      ),
    );
    await settle(tester);
    await done(tester);
    await save(tester);

    final merged = page.save.calls.single.merged;
    expect(merged.isPlanned, isTrue);
    expect(merged.diveNumber, isNull);
  });

  testWidgets('favourite set in the editor is saved, and the locked bar '
      'then shows it', (tester) async {
    final page = await pumpPage(
      tester,
      stored: headed,
      size: const Size(900, 1400),
    );
    await unlock(tester);
    await openHeader(tester);

    controllerOf(tester).session!.set(diveFavoriteField, true);
    await settle(tester);
    await done(tester);
    await save(tester);

    expect(page.save.calls.single.merged.isFavorite, isTrue);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  group('the site suggestion', () {
    late FakeMatchingService service;

    setUp(() => service = FakeMatchingService());

    testWidgets('dismissed and saved alone is one save of the header', (
      tester,
    ) async {
      final page = await pumpPage(
        tester,
        stored: headed,
        extra: [
          siteSuggestionForDiveProvider(dive.id).overrideWith(
            (ref) async => suggestionFor(service, status: ProposalStatus.none),
          ),
        ],
      );
      await unlock(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(SiteSuggestionCard),
          matching: find.byIcon(Icons.close),
        ),
      );
      await settle(tester);
      await save(tester);

      expect(page.save.calls.single.cards, [diveHeaderCardId]);
      expect(page.save.heldChangeFlags.single, isTrue);
    });

    testWidgets('choose nearby opens the site picker during a sitting', (
      tester,
    ) async {
      await pumpPage(
        tester,
        stored: headed,
        extra: [
          siteSuggestionForDiveProvider(dive.id).overrideWith(
            (ref) async => suggestionFor(
              service,
              status: ProposalStatus.review,
              candidates: const [
                MatchCandidateView(
                  id: 's1',
                  name: 'Blue Hole',
                  isExisting: true,
                  distanceMeters: 40,
                  location: GeoPoint(0, 0),
                ),
                MatchCandidateView(
                  id: 's2',
                  name: 'Blue Wall',
                  isExisting: true,
                  distanceMeters: 60,
                  location: GeoPoint(0, 0),
                ),
              ],
            ),
          ),
        ],
      );
      await unlock(tester);

      await tester.tap(find.textContaining('Choose'));
      await settle(tester);

      expect(find.byType(SitePickerSheet), findsOneWidget);
    });

    testWidgets('a locked page makes no write from the header block', (
      tester,
    ) async {
      final page = await pumpPage(
        tester,
        stored: headed.copyWith(isFavorite: true),
        size: const Size(900, 1400),
        extra: [
          siteSuggestionForDiveProvider(dive.id).overrideWith(
            (ref) async => suggestionFor(service, status: ProposalStatus.none),
          ),
        ],
      );

      for (final target in [
        find.byIcon(Icons.close),
        find.text('Create Site'),
        find.byIcon(Icons.favorite),
      ]) {
        await tester.tap(target.first, warnIfMissed: false);
        await settle(tester);
      }

      expect(page.save.calls, isEmpty);
      expect(service.created, isEmpty);
      expect(service.createdUnlinked, isEmpty);
      expect(find.byType(SiteSuggestionCard), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      final live = find.descendant(
        of: find.byType(SiteSuggestionCard),
        matching: find.byWidgetPredicate(
          (w) =>
              (w is ButtonStyleButton && w.onPressed != null) ||
              (w is IconButton && w.onPressed != null),
        ),
      );
      expect(live, findsNothing);
    });
  });

  testWidgets('a moved site refreshes what both sites have seen', (
    tester,
  ) async {
    final reads = <String, int>{};
    await pumpPage(
      tester,
      stored: headed.copyWith(
        site: const DiveSite(id: 'old', name: 'Old'),
      ),
      extra: [
        for (final id in ['old', 'reef'])
          siteSpottedSpeciesProvider(id).overrideWith((ref) async {
            reads[id] = (reads[id] ?? 0) + 1;
            return const [];
          }),
      ],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SiteSuggestionCard).first),
    );
    for (final id in ['old', 'reef']) {
      final sub = container.listen(siteSpottedSpeciesProvider(id), (_, _) {});
      addTearDown(sub.close);
    }
    await settle(tester);
    expect(reads, {'old': 1, 'reef': 1});

    await unlock(tester);
    assign(tester, reef);
    await settle(tester);
    await save(tester);

    expect(reads, {'old': 2, 'reef': 2});
  });
}
