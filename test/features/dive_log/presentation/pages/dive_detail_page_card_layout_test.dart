import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_details_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/responsive_section_pair.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import 'dive_detail_page_paired_harness.dart';

/// How paired cards share their row on the dive detail page (issue #4583):
/// both columns end level, the card after a pair can move up beside it, and
/// the pair holds together while its reads reload. Which sections pair is
/// covered by dive_detail_page_paired_sections_test.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Buddies + Signatures', () {
    // A reload driven by a dependency keeps the last answer: the dive has
    // buddies. Read as "still loading", the pair would come apart into two
    // full-width cards and form again once the read lands.
    testWidgets('the pair holds together while the buddies reload', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = Dive(
        id: 'buddies-reload',
        dateTime: DateTime(2026, 3, 15, 10, 0),
      );
      final reload = Completer<void>();
      await tester.pumpWidget(
        pairedDetailPage(
          dive: dive,
          settings: settingsWithVisibleSections([
            DiveDetailSectionId.buddies,
            DiveDetailSectionId.signatures,
          ]),
          extraOverrides: pairedRenderOverrides(
            dive.id,
            prefs,
            buddies: [pairedBuddy],
            reloadGate: () => reload.future,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ResponsiveSectionPair), findsOneWidget);

      ProviderScope.containerOf(
        tester.element(find.byType(DiveDetailPage)),
      ).read(reloadTrigger.notifier).bump();
      await tester.pump();

      expect(find.byType(ResponsiveSectionPair), findsOneWidget);

      reload.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ResponsiveSectionPair), findsOneWidget);
    });

    // Issue #4583: the shorter card left blank space under it before the
    // next card; now both columns end level.
    testWidgets('the two cards end level (wide pane)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dive = Dive(
        id: 'buddies-level',
        dateTime: DateTime(2026, 3, 15, 10, 0),
      );
      final settings = settingsWithVisibleSections([
        DiveDetailSectionId.buddies,
        DiveDetailSectionId.signatures,
      ]);

      await tester.pumpWidget(
        pairedDetailPage(
          dive: dive,
          settings: settings,
          extraOverrides: pairedRenderOverrides(
            dive.id,
            prefs,
            buddies: [pairedBuddy],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pair = find.byType(ResponsiveSectionPair);
      final middle = tester.getCenter(pair).dx;
      final bottoms = <bool, double>{};
      for (final card
          in find
              .descendant(of: pair, matching: find.byType(Card))
              .evaluate()) {
        final box = card.renderObject! as RenderBox;
        final rect = box.localToGlobal(Offset.zero) & box.size;
        final left = rect.center.dx < middle;
        bottoms[left] = math.max(bottoms[left] ?? 0, rect.bottom);
      }
      expect(bottoms.keys, containsAll([true, false]));
      expect(bottoms[true], bottoms[false]);
    });

    // Issue #4583: the card straight after a pair is laid out with it, so it
    // can move up under the shorter half; a full-width one never is.
    for (final (next, slots) in [
      (DiveDetailSectionId.notes, true),
      (DiveDetailSectionId.media, false),
    ]) {
      testWidgets(
        '${next.name} after the pair ${slots ? 'is' : 'is not'} laid out '
        'with it',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1000, 3000));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          final dive = Dive(
            id: 'buddies-slot-${next.name}',
            dateTime: DateTime(2026, 3, 15, 10, 0),
            notes: 'Calm water and good visibility.',
          );
          final settings = settingsWithVisibleSections([
            DiveDetailSectionId.buddies,
            DiveDetailSectionId.signatures,
            next,
          ]);

          await tester.pumpWidget(
            pairedDetailPage(
              dive: dive,
              settings: settings,
              extraOverrides: pairedRenderOverrides(
                dive.id,
                prefs,
                buddies: [pairedBuddy],
              ),
            ),
          );
          await tester.pumpAndSettle();

          final pair = find.byType(ResponsiveSectionPair);
          expect(pair, findsOneWidget);
          final inPair = find.descendant(
            of: pair,
            matching: find.byKey(ValueKey('diveSection_${next.name}')),
          );
          expect(inPair, slots ? findsOneWidget : findsNothing);
        },
      );
    }

    Future<void> pumpAfterPair(
      WidgetTester tester,
      Dive dive,
      List<DiveDetailSectionId> after,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        pairedDetailPage(
          dive: dive,
          // In this order, the rest hidden: the cards in [after] come
          // straight after the pair.
          settings: AppSettings(
            diveDetailSections: [
              for (final id in [
                DiveDetailSectionId.buddies,
                DiveDetailSectionId.signatures,
                ...after,
              ])
                DiveDetailSectionConfig(id: id, visible: true),
              for (final id in DiveDetailSectionId.values)
                if (id != DiveDetailSectionId.buddies &&
                    id != DiveDetailSectionId.signatures &&
                    !after.contains(id))
                  DiveDetailSectionConfig(id: id, visible: false),
            ],
          ),
          extraOverrides: pairedRenderOverrides(
            dive.id,
            prefs,
            buddies: [pairedBuddy],
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder buddiesPair() => find.byKey(
      ValueKey('diveSectionPair_${DiveDetailSectionId.buddies.name}'),
    );

    // A full-width card with nothing to show draws nothing, so the card after
    // it is the next card: Surface GPS on a dive with no position.
    testWidgets('an empty full-width card does not stop the next one', (
      tester,
    ) async {
      final dive = Dive(
        id: 'buddies-empty-gps',
        dateTime: DateTime(2026, 3, 15, 10, 0),
        notes: 'Calm water and good visibility.',
      );
      await pumpAfterPair(tester, dive, [
        DiveDetailSectionId.surfaceGps,
        DiveDetailSectionId.notes,
      ]);

      expect(
        find.descendant(
          of: buddiesPair(),
          matching: find.byKey(const ValueKey('diveSection_notes')),
        ),
        findsOneWidget,
      );
    });

    // A card that starts a pair of its own stays in that pair, and is drawn
    // once.
    testWidgets('the first half of the next pair is not its slot', (
      tester,
    ) async {
      final dive = Dive(
        id: 'buddies-then-details',
        dateTime: DateTime(2026, 3, 15, 10, 0),
        airTemp: 21,
      );
      await pumpAfterPair(tester, dive, [
        DiveDetailSectionId.details,
        DiveDetailSectionId.environment,
      ]);

      expect(find.byType(ResponsiveSectionPair), findsNWidgets(2));
      expect(find.byType(DiveDetailsSection), findsOneWidget);
      expect(
        find.descendant(
          of: buddiesPair(),
          matching: find.byType(DiveDetailsSection),
        ),
        findsNothing,
      );
    });
  });
}
