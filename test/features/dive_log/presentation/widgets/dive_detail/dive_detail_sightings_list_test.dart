import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_sightings_list.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_sighting_row.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_app.dart';

/// A long species list on the dive page (issue #5067).
List<Sighting> _sightings(int n) => [
  for (var i = 0; i < n; i++)
    Sighting(
      id: 's$i',
      diveId: 'd1',
      speciesId: 'sp$i',
      speciesName: 'Species $i',
      speciesCategory: SpeciesCategory.fish,
    ),
];

Future<void> _pump(
  WidgetTester tester,
  List<Sighting> sightings, {
  double width = 400,
  double height = 2400,
  void Function(Sighting)? onOpen,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: await getBaseOverrides(),
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              DiveSightingsList(
                sightings: sightings,
                photoCounts: const {},
                onOpen: onOpen ?? (_) {},
                onOpenPhotos: (_) {},
              ),
              // The cards below Marine life, so a fold cannot clamp the
              // scroll offset back onto the list.
              const SizedBox(height: 3000),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a short list shows every species and no toggle', (tester) async {
    await _pump(tester, _sightings(kSightingsCollapseAbove));

    expect(
      find.byType(DiveSightingRow),
      findsNWidgets(kSightingsCollapseAbove),
    );
    expect(find.textContaining('Show all'), findsNothing);
    expect(find.text('Show fewer'), findsNothing);
  });

  testWidgets('a long list shows the first few until Show all is tapped', (
    tester,
  ) async {
    await _pump(tester, _sightings(14));

    expect(
      find.byType(DiveSightingRow),
      findsNWidgets(kSightingsCollapsedCount),
    );
    expect(find.text('Species 0'), findsOneWidget);
    expect(
      find.text('Species ${kSightingsCollapsedCount - 1}'),
      findsOneWidget,
    );
    expect(find.text('Species $kSightingsCollapsedCount'), findsNothing);

    await tester.tap(find.text('Show all (14)'));
    await tester.pumpAndSettle();
    expect(find.byType(DiveSightingRow), findsNWidgets(14));
    expect(find.text('Species 13'), findsOneWidget);

    await tester.tap(find.text('Show fewer'));
    await tester.pumpAndSettle();
    expect(
      find.byType(DiveSightingRow),
      findsNWidgets(kSightingsCollapsedCount),
    );
  });

  testWidgets('a row still opens its species', (tester) async {
    Sighting? opened;
    await _pump(tester, _sightings(3), onOpen: (s) => opened = s);

    await tester.tap(find.text('Species 1'));
    expect(opened?.speciesId, 'sp1');
  });

  testWidgets('a wide card lays the species out in two columns', (
    tester,
  ) async {
    await _pump(tester, _sightings(4), width: 900);

    final first = tester.getTopLeft(find.text('Species 0'));
    final second = tester.getTopLeft(find.text('Species 1'));
    final third = tester.getTopLeft(find.text('Species 2'));
    expect(second.dy, first.dy);
    expect(second.dx, greaterThan(first.dx));
    expect(third.dx, first.dx);
    expect(third.dy, greaterThan(first.dy));
  });

  testWidgets('a fractional width still fits two columns', (tester) async {
    await _pump(tester, _sightings(2), width: 731.3);

    final first = tester.getTopLeft(find.text('Species 0'));
    final second = tester.getTopLeft(find.text('Species 1'));
    expect(second.dy, first.dy);
  });

  testWidgets('Show fewer at the foot of a long list keeps the toggle in '
      'view', (tester) async {
    await _pump(tester, _sightings(40), height: 600);

    await tester.tap(find.text('Show all (40)'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Show fewer'), 200);
    await tester.tap(find.text('Show fewer'));
    await tester.pumpAndSettle();

    final toggle = tester.getRect(find.text('Show all (40)'));
    expect(toggle.top, greaterThanOrEqualTo(0));
    expect(toggle.bottom, lessThanOrEqualTo(600));
  });

  testWidgets('a phone-width card keeps one column', (tester) async {
    await _pump(tester, _sightings(4), width: 400);

    final first = tester.getTopLeft(find.text('Species 0'));
    final second = tester.getTopLeft(find.text('Species 1'));
    expect(second.dx, first.dx);
    expect(second.dy, greaterThan(first.dy));
  });

  testWidgets('rows are compact', (tester) async {
    await _pump(tester, _sightings(1));

    // 52 px before issue #5067; a 30-species dive was a 1,600 px card.
    expect(tester.getSize(find.byType(DiveSightingRow)).height, 40);
  });
}
