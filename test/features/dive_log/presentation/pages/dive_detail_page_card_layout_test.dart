import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/widgets/responsive_section_pair.dart';

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
  });
}
