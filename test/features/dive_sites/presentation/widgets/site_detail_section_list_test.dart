import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/dive_detail_layout.dart';
import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/dive_log/presentation/widgets/responsive_section_pair.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_detail_section_list.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/section_fold.dart';

Widget _card(SiteDetailSectionId id) =>
    Card(child: SizedBox(height: 40, child: Text('CARD_${id.name}')));

Map<SiteDetailSectionId, WidgetBuilder?> _allCards() => {
  for (final id in SiteDetailSectionId.values) id: (_) => _card(id),
};

List<SiteDetailSectionConfig> _config({
  Set<SiteDetailSectionId> hidden = const {},
  Set<SiteDetailSectionId> expanded = const {},
  List<SiteDetailSectionId>? order,
}) => [
  for (final id in order ?? SiteDetailSectionId.values)
    SiteDetailSectionConfig(
      id: id,
      visible: !hidden.contains(id),
      expanded: expanded.contains(id),
    ),
];

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required List<SiteDetailSectionConfig> sections,
  Map<SiteDetailSectionId, WidgetBuilder?>? cards,
  DiveDetailLayout layout = DiveDetailLayout.detailed,
  void Function(SiteDetailSectionId id, bool expanded)? onFoldChanged,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, 4000);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SiteDetailSectionList(
            sections: sections,
            layout: layout,
            cards: cards ?? _allCards(),
            onFoldChanged: onFoldChanged ?? (id, expanded) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Rect _rectOf(WidgetTester tester, SiteDetailSectionId id) => tester.getRect(
  find.ancestor(of: find.text('CARD_${id.name}'), matching: find.byType(Card)),
);

void main() {
  group('detailed layout', () {
    testWidgets('renders the visible cards in the saved order', (tester) async {
      await _pump(
        tester,
        width: 600,
        sections: _config(order: SiteDetailSectionId.values.reversed.toList()),
      );

      expect(
        _rectOf(tester, SiteDetailSectionId.notes).top,
        lessThan(_rectOf(tester, SiteDetailSectionId.diveStatistics).top),
      );
    });

    testWidgets('a hidden card is not rendered', (tester) async {
      await _pump(
        tester,
        width: 600,
        sections: _config(hidden: {SiteDetailSectionId.notes}),
      );

      expect(find.text('CARD_notes'), findsNothing);
      expect(find.text('CARD_description'), findsOneWidget);
    });

    testWidgets('a card with nothing to show is skipped', (tester) async {
      await _pump(
        tester,
        width: 600,
        sections: _config(),
        cards: {..._allCards(), SiteDetailSectionId.altitude: null}
          ..remove(SiteDetailSectionId.tide),
      );

      expect(find.text('CARD_altitude'), findsNothing);
      expect(find.text('CARD_tide'), findsNothing);
      expect(find.text('CARD_depth'), findsOneWidget);
    });

    testWidgets('consecutive cards are 12px apart', (tester) async {
      await _pump(tester, width: 600, sections: _config());

      final description = _rectOf(tester, SiteDetailSectionId.description);
      final location = _rectOf(tester, SiteDetailSectionId.location);
      expect(location.top - description.bottom, kSiteDetailCardGap);
    });

    testWidgets('Difficulty and Rating sit side by side on a wide pane', (
      tester,
    ) async {
      await _pump(tester, width: 1400, sections: _config());

      final pair = find.ancestor(
        of: find.text('CARD_difficulty'),
        matching: find.byType(ResponsiveSectionPair),
      );
      expect(pair, findsOneWidget);
      expect(
        find.descendant(of: pair, matching: find.text('CARD_rating')),
        findsOneWidget,
      );
      final difficulty = _rectOf(tester, SiteDetailSectionId.difficulty);
      final rating = _rectOf(tester, SiteDetailSectionId.rating);
      expect(rating.top, difficulty.top);
      expect(difficulty.left, lessThan(rating.left));
    });

    testWidgets('the pair stacks on a narrow pane', (tester) async {
      await _pump(tester, width: 390, sections: _config());

      final difficulty = _rectOf(tester, SiteDetailSectionId.difficulty);
      final rating = _rectOf(tester, SiteDetailSectionId.rating);
      expect(rating.top, greaterThanOrEqualTo(difficulty.bottom));
    });

    testWidgets('a pair split by other cards forms at its first half', (
      tester,
    ) async {
      const tail = [
        SiteDetailSectionId.rating,
        SiteDetailSectionId.notes,
        SiteDetailSectionId.difficulty,
      ];
      await _pump(
        tester,
        width: 1400,
        sections: _config(
          order: [
            for (final id in SiteDetailSectionId.values)
              if (!tail.contains(id)) id,
            ...tail,
          ],
        ),
      );

      final difficulty = _rectOf(tester, SiteDetailSectionId.difficulty);
      final rating = _rectOf(tester, SiteDetailSectionId.rating);
      final notes = _rectOf(tester, SiteDetailSectionId.notes);
      expect(rating.top, difficulty.top);
      expect(difficulty.left, lessThan(rating.left));
      expect(notes.top, greaterThan(rating.bottom));
    });

    testWidgets('a pair with an empty half falls back to single cards', (
      tester,
    ) async {
      await _pump(
        tester,
        width: 1400,
        sections: _config(),
        cards: {
          ..._allCards(),
          SiteDetailSectionId.difficulty: null,
          SiteDetailSectionId.hazards: null,
        },
      );

      expect(find.byType(ResponsiveSectionPair), findsNothing);
      expect(find.text('CARD_rating'), findsOneWidget);
      expect(find.text('CARD_access'), findsOneWidget);
    });

    testWidgets('a hidden half does not pair', (tester) async {
      await _pump(
        tester,
        width: 1400,
        sections: _config(
          hidden: {SiteDetailSectionId.rating, SiteDetailSectionId.access},
        ),
      );

      expect(find.byType(ResponsiveSectionPair), findsNothing);
      expect(find.text('CARD_difficulty'), findsOneWidget);
    });
  });

  group('list layout', () {
    testWidgets('folds every card and builds none of them', (tester) async {
      await _pump(
        tester,
        width: 600,
        sections: _config(),
        layout: DiveDetailLayout.list,
      );

      expect(
        find.byType(SectionFold),
        findsNWidgets(SiteDetailSectionId.values.length),
      );
      expect(find.textContaining('CARD_'), findsNothing);
      expect(find.text('Notes'), findsOneWidget);
    });

    testWidgets('an unfolded card shows its content', (tester) async {
      await _pump(
        tester,
        width: 600,
        sections: _config(expanded: {SiteDetailSectionId.notes}),
        layout: DiveDetailLayout.list,
      );

      expect(find.text('CARD_notes'), findsOneWidget);
      expect(find.text('CARD_map'), findsNothing);
    });

    testWidgets('a folded card is never built', (tester) async {
      var builds = 0;
      await _pump(
        tester,
        width: 600,
        sections: _config(),
        cards: {
          ..._allCards(),
          SiteDetailSectionId.notes: (_) {
            builds++;
            return _card(SiteDetailSectionId.notes);
          },
        },
        layout: DiveDetailLayout.list,
      );

      expect(builds, 0);
    });

    testWidgets('tapping a header reports the new fold state', (tester) async {
      final calls = <(SiteDetailSectionId, bool)>[];
      await _pump(
        tester,
        width: 600,
        sections: _config(),
        layout: DiveDetailLayout.list,
        onFoldChanged: (id, expanded) => calls.add((id, expanded)),
      );

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      expect(calls, [(SiteDetailSectionId.notes, true)]);
    });

    testWidgets('never pairs cards', (tester) async {
      await _pump(
        tester,
        width: 1400,
        sections: _config(
          expanded: {
            SiteDetailSectionId.difficulty,
            SiteDetailSectionId.rating,
          },
        ),
        layout: DiveDetailLayout.list,
      );

      expect(find.byType(ResponsiveSectionPair), findsNothing);
      expect(find.text('CARD_difficulty'), findsOneWidget);
      expect(find.text('CARD_rating'), findsOneWidget);
    });

    testWidgets('a card with nothing to show gets no header', (tester) async {
      await _pump(
        tester,
        width: 600,
        sections: _config(),
        cards: {..._allCards(), SiteDetailSectionId.altitude: null},
        layout: DiveDetailLayout.list,
      );

      expect(find.text('Altitude'), findsNothing);
      expect(
        find.byType(SectionFold),
        findsNWidgets(SiteDetailSectionId.values.length - 1),
      );
    });
  });
}
