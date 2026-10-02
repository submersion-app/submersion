import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

final _filter = StateProvider<DiveFilterState>(
  (ref) => const DiveFilterState(
    waterTypes: [WaterType.salt],
    siteIds: ['s1', 's2'],
    minWaterTemp: 10,
  ),
);

void main() {
  final en = AppLocalizationsEn();

  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<void> open(
    WidgetTester tester, {
    List<Species> species = const [],
  }) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides.cast(),
          allSpeciesProvider.overrideWith((ref) async => species),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        DiveFilterSheet(ref: ref, filterProvider: _filter),
                  ),
                  child: const Text('Open filter'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open filter'));
    await tester.pumpAndSettle();
  }

  /// The sheet's ListView builds lazily, so scroll a deep target into the
  /// tree before touching it (the interactions test's pattern).
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    final scrollable = find.byType(Scrollable).first;
    // Back to the top first: a target may sit above the section revealed
    // last, and the lazy list only holds what is near the viewport. Jump
    // rather than drag: a downward drag at the top dismisses the sheet.
    if (finder.evaluate().isEmpty) {
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
    }
    for (var i = 0; i < 12 && finder.evaluate().isEmpty; i++) {
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(finder, findsWidgets);
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
  }

  testWidgets('shows the new sections seeded from the filter', (tester) async {
    await open(tester);
    for (final title in [
      en.diveLog_filter_sectionWaterTempUnit('°C'),
      en.diveLog_filter_sectionVisibilityUnit('m'),
      en.diveLog_filter_sectionWaterType,
      en.diveLog_filter_sectionSpecies,
    ]) {
      await reveal(tester, find.text(title));
      expect(find.text(title), findsOneWidget, reason: title);
    }
    final salt = find.widgetWithText(FilterChip, en.enum_waterType_salt);
    await reveal(tester, salt);
    expect(tester.widget<FilterChip>(salt).selected, isTrue);
  });

  testWidgets('applying writes the axes and preserves siteIds', (tester) async {
    await open(tester);
    final fresh = find.widgetWithText(FilterChip, en.enum_waterType_fresh);
    await reveal(tester, fresh);
    await tester.tap(fresh);
    await tester.pumpAndSettle();
    final vis = find.byKey(const ValueKey('filter-visibility-min'));
    await reveal(tester, vis);
    await tester.enterText(vis, '20');
    final temp = find.byKey(const ValueKey('filter-water-temp-max'));
    await reveal(tester, temp);
    await tester.enterText(temp, '25');
    await tester.tap(find.text(en.diveLog_filter_apply));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.text('Open filter')),
    );
    final f = container.read(_filter);
    expect(f.waterTypes, [WaterType.salt, WaterType.fresh]);
    expect(f.minVisibility, 20);
    expect(f.minWaterTemp, 10);
    expect(f.maxWaterTemp, 25);
    expect(f.siteIds, ['s1', 's2']);
  });

  testWidgets('emptying a bound and applying clears it', (tester) async {
    // Apply writes through copyWith, which reads null as "keep". Without
    // the bound's clear flag the seeded 10 would survive an emptied field.
    await open(tester);
    final min = find.byKey(const ValueKey('filter-water-temp-min'));
    await reveal(tester, min);
    await tester.enterText(min, '');
    await tester.tap(find.text(en.diveLog_filter_apply));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.text('Open filter')),
    );
    expect(container.read(_filter).minWaterTemp, isNull);
  });

  testWidgets('picking a species clears the search for the next one', (
    tester,
  ) async {
    await open(
      tester,
      species: const [
        Species(
          id: 'sp-turtle',
          commonName: 'Green Turtle',
          category: SpeciesCategory.turtle,
        ),
      ],
    );
    final search = find.widgetWithText(
      TextField,
      en.diveLog_filter_speciesSearchHint,
    );
    await reveal(tester, search);
    await tester.enterText(search, 'tur');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Green Turtle').last);
    await tester.pumpAndSettle();
    // The pick is a chip now; the field is empty and ready for another.
    expect(find.widgetWithText(InputChip, 'Green Turtle'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == en.diveLog_filter_speciesSearchHint,
      ),
    );
    expect(field.controller!.text, isEmpty);
  });
}
