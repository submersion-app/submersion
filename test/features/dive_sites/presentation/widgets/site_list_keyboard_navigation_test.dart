import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_grouping_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_content.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_tile.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/grouped_site_list_view.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

SiteWithDiveCount _site(String id, String name, {String? country}) =>
    SiteWithDiveCount(
      site: DiveSite(id: id, name: name, country: country),
      diveCount: 0,
    );

final _sites = [
  _site('au1', 'Cod Hole', country: 'Australia'),
  _site('au2', 'Osprey Reef', country: 'Australia'),
  _site('eg1', 'Blue Hole', country: 'Egypt'),
];

class _MockSiteListNotifier extends StateNotifier<AsyncValue<List<DiveSite>>>
    implements SiteListNotifier {
  _MockSiteListNotifier() : super(const AsyncValue.data(<DiveSite>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Phone width, so a move highlights and Enter opens through
/// [SiteListContent.onItemSelected].
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required List<String?> opened,
  SiteGroupBy groupBy = SiteGroupBy.location,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(500, 844);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        sortedSitesWithCountsProvider.overrideWithValue(
          AsyncValue.data(_sites),
        ),
        siteListNotifierProvider.overrideWith((ref) => _MockSiteListNotifier()),
        siteListViewModeProvider.overrideWith((ref) => ListViewMode.detailed),
        siteGroupByProvider.overrideWith((ref) => groupBy),
      ],
      child: SiteListContent(showAppBar: false, onItemSelected: opened.add),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(SiteListContent)),
  );
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Finder _header(String label) => find.widgetWithText(SiteCountryHeader, label);

void main() {
  testWidgets('arrows walk countries and sites; Left and Right fold them', (
    tester,
  ) async {
    final opened = <String?>[];
    final container = await _pump(tester, opened: opened);
    expect(find.byType(SiteListTile), findsNothing);

    // A click on the header opens Australia and puts the cursor on it.
    await tester.tap(_header('Australia'));
    await tester.pumpAndSettle();
    expect(find.byType(SiteListTile), findsNWidgets(2));

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(container.read(highlightedSiteIdProvider), 'au1');
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(container.read(highlightedSiteIdProvider), 'au2');

    // Left folds the country the site is in, leaving the cursor on it.
    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(find.byType(SiteListTile), findsNothing);

    // Down reaches the next country, Right opens it, Down enters it.
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('Blue Hole'), findsOneWidget);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(container.read(highlightedSiteIdProvider), 'eg1');

    expect(opened, isEmpty, reason: 'an arrow must not open a page');
    await _press(tester, LogicalKeyboardKey.enter);
    expect(opened, ['eg1']);
  });

  testWidgets('ungrouped, Down moves from the clicked site', (tester) async {
    final opened = <String?>[];
    final container = await _pump(
      tester,
      opened: opened,
      groupBy: SiteGroupBy.none,
    );

    await tester.tap(find.text('Cod Hole'));
    await tester.pumpAndSettle();
    await _press(tester, LogicalKeyboardKey.arrowDown);

    expect(container.read(highlightedSiteIdProvider), isNot('au1'));
    expect(container.read(highlightedSiteIdProvider), isNotNull);
    expect(opened, ['au1'], reason: 'only the click opened anything');
  });
}
