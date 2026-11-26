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

  testWidgets('fits a phone at text scale 1.3', (tester) async {
    tester.view.physicalSize = const Size(390, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester, withoutPhoto: 122);
    expect(tester.takeException(), isNull);
  });
}
