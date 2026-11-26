import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/seen_species_filter.dart';
import 'package:submersion/features/marine_life/domain/species_grouping.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_browse_controls.dart';

import '../../../../helpers/test_app.dart';

Future<void> _pump(
  WidgetTester tester, {
  int withoutPhoto = 0,
  bool filterOn = false,
  ValueChanged<bool>? onFilter,
  SpeciesCategory? category,
  VoidCallback? onClearCategory,
}) => tester.pumpWidget(
  testApp(
    locale: const Locale('en'),
    child: SpeciesBrowseControls(
      summary: '60 species · 231 sightings',
      shortSummary: '60 species',
      groupBy: SpeciesGroupBy.category,
      grid: true,
      sort: SeenSpeciesSort.mostDives,
      withoutPhoto: withoutPhoto,
      noPhotoFilterOn: filterOn,
      category: category,
      onGroupBy: (_) {},
      onGrid: (_) {},
      onSort: (_) {},
      onNoPhotoFilter: onFilter ?? (_) {},
      onClearCategory: onClearCategory,
    ),
  ),
);

void main() {
  testWidgets('hides the no-photo chip at zero', (tester) async {
    await _pump(tester);
    expect(find.byType(FilterChip), findsNothing);
  });

  testWidgets('the chip counts species without a photo and toggles', (
    tester,
  ) async {
    bool? toggled;
    await _pump(tester, withoutPhoto: 12, onFilter: (v) => toggled = v);
    expect(find.text('12'), findsOneWidget);
    expect(find.byTooltip('12 without a photo'), findsOneWidget);
    await tester.tap(find.byType(FilterChip));
    expect(toggled, isTrue);
  });

  testWidgets('the chip stays while its filter is on, even at zero', (
    tester,
  ) async {
    bool? toggled;
    await _pump(tester, filterOn: true, onFilter: (v) => toggled = v);
    await tester.tap(find.byType(FilterChip));
    expect(toggled, isFalse);
  });

  testWidgets('the selected chip draws no checkmark over its icon', (
    tester,
  ) async {
    await _pump(tester, withoutPhoto: 3, filterOn: true);
    expect(
      tester.widget<FilterChip>(find.byType(FilterChip)).showCheckmark,
      isFalse,
    );
  });

  testWidgets('a chosen category shows as a chip that clears it', (
    tester,
  ) async {
    var cleared = false;
    await _pump(
      tester,
      category: SpeciesCategory.shark,
      onClearCategory: () => cleared = true,
    );
    expect(find.text('Shark'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    expect(cleared, isTrue);
  });

  // The narrow and large-text end: a small phone, German labels, a long
  // grouping name and a four-digit count must all still fit on one row.
  for (final (width, scale, locale) in [
    (390.0, 1.3, 'en'),
    (320.0, 1.0, 'en'),
    (320.0, 1.3, 'en'),
    (360.0, 1.3, 'de'),
    (390.0, 1.5, 'de'),
    (390.0, 2.0, 'en'),
  ]) {
    testWidgets('fits $width wide at text scale $scale ($locale)', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        testApp(
          locale: Locale(locale),
          child: SpeciesBrowseControls(
            summary: '1,234 species · 23,100 sightings',
            shortSummary: '1,234 species',
            groupBy: SpeciesGroupBy.firstSeen,
            grid: true,
            sort: SeenSpeciesSort.mostDives,
            withoutPhoto: 1122,
            noPhotoFilterOn: false,
            onGroupBy: (_) {},
            onGrid: (_) {},
            onSort: (_) {},
            onNoPhotoFilter: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      // The view toggle, last in the row, is fully on screen.
      final toggle = tester.getRect(
        find.byKey(const ValueKey('species_view_toggle')),
      );
      expect(toggle.right, lessThanOrEqualTo(width));
    });
  }

  testWidgets('a phone shows the short count line', (tester) async {
    tester.view.physicalSize = const Size(390, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, withoutPhoto: 22);
    expect(find.text('60 species'), findsOneWidget);
    expect(find.text('60 species · 231 sightings'), findsNothing);
  });

  testWidgets('a wide window shows the full count line', (tester) async {
    tester.view.physicalSize = const Size(1280, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester, withoutPhoto: 22);
    expect(find.text('60 species · 231 sightings'), findsOneWidget);
  });
}
