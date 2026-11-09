import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/site_species_suggestion_chips.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/site_species_suggestions.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';

import '../../../../helpers/test_app.dart';

SiteSpeciesSummary _spotted(String name, int dives) => SiteSpeciesSummary(
  speciesId: 'id-$name',
  speciesName: name,
  category: SpeciesCategory.fish,
  sightingCount: dives,
  diveCount: dives,
);

SiteSpeciesEntry _expected(String name) => SiteSpeciesEntry(
  id: 'entry-$name',
  siteId: 'site-1',
  speciesId: 'id-$name',
  speciesName: name,
  category: SpeciesCategory.turtle,
  notes: '',
  createdAt: DateTime.utc(2026),
);

typedef _Key = ({String siteId, String? excludeDiveId});

Future<List<_Key>> _pump(
  WidgetTester tester, {
  required List<SiteSpeciesSummary> spotted,
  List<SiteSpeciesEntry> expected = const [],
  Set<String> logged = const {},
  void Function(SiteSpeciesSuggestion)? onAdd,
}) async {
  final keys = <_Key>[];
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        siteSpeciesSuggestionSourcesProvider.overrideWith((ref, key) async {
          keys.add(key);
          return (spotted: spotted, expected: expected);
        }),
      ],
      child: SingleChildScrollView(
        child: SiteSpeciesSuggestionChips(
          siteId: 'site-1',
          siteName: 'Blue Corner',
          excludeDiveId: 'dive-9',
          loggedSpeciesIds: logged,
          onAdd: onAdd ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return keys;
}

void main() {
  testWidgets('shows the site heading and one chip per suggestion', (
    tester,
  ) async {
    final keys = await _pump(
      tester,
      spotted: [_spotted('Moray', 2), _spotted('Blacktip', 5)],
      expected: [_expected('Manta')],
    );

    expect(keys, [(siteId: 'site-1', excludeDiveId: 'dive-9')]);
    expect(find.text('Suggested for Blue Corner'), findsOneWidget);
    final labels = tester
        .widgetList<ActionChip>(find.byType(ActionChip))
        .map(
          (chip) => switch (chip.label) {
            final Text text => text.data,
            _ => null,
          },
        )
        .toList();
    // Most dives first; the expected species follows with no number.
    expect(labels, ['Blacktip · 5', 'Moray · 2', null]);
    expect(find.text('Manta'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
  });

  testWidgets('orders expected species alphabetically', (tester) async {
    await _pump(
      tester,
      spotted: const [],
      expected: [_expected('Turtle'), _expected('Manta')],
    );

    final manta = tester.getTopLeft(find.text('Manta'));
    final turtle = tester.getTopLeft(find.text('Turtle'));
    expect(
      manta.dx < turtle.dx || manta.dy < turtle.dy,
      isTrue,
      reason: 'Manta sorts before Turtle',
    );
  });

  testWidgets('tapping a chip reports that suggestion', (tester) async {
    final added = <SiteSpeciesSuggestion>[];
    await _pump(
      tester,
      spotted: [_spotted('Blacktip', 5)],
      expected: [_expected('Manta')],
      onAdd: added.add,
    );

    await tester.tap(find.text('Blacktip · 5'));
    await tester.tap(find.text('Manta'));

    expect(added.map((s) => s.speciesId), ['id-Blacktip', 'id-Manta']);
    expect(added.last.isExpectedOnly, isTrue);
  });

  testWidgets('hides species already on the dive', (tester) async {
    await _pump(
      tester,
      spotted: [_spotted('Blacktip', 5), _spotted('Moray', 2)],
      logged: const {'id-Blacktip'},
    );

    expect(find.text('Blacktip · 5'), findsNothing);
    expect(find.text('Moray · 2'), findsOneWidget);
  });

  testWidgets('shows nothing when the site has no suggestions', (tester) async {
    await _pump(
      tester,
      spotted: [_spotted('Blacktip', 5)],
      logged: const {'id-Blacktip'},
    );

    expect(find.text('Suggested for Blue Corner'), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('shows the first eight, then expands and collapses', (
    tester,
  ) async {
    await _pump(
      tester,
      spotted: [for (var i = 1; i <= 10; i++) _spotted('Fish $i', 20 - i)],
    );

    expect(find.textContaining('Fish '), findsNWidgets(8));
    expect(find.text('Fish 9 · 11'), findsNothing);

    await tester.tap(find.text('Show all (10)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Fish '), findsNWidgets(10));

    await tester.tap(find.text('Show fewer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Fish '), findsNWidgets(8));
  });

  testWidgets('names the count and the expected list in tooltips', (
    tester,
  ) async {
    await _pump(
      tester,
      spotted: [_spotted('Blacktip', 1)],
      expected: [_expected('Manta')],
    );

    final tooltips = tester
        .widgetList<ActionChip>(find.byType(ActionChip))
        .map((chip) => chip.tooltip)
        .toList();
    expect(tooltips, [
      'Seen on 1 other dive here',
      "On this site's expected species list",
    ]);
  });
}
