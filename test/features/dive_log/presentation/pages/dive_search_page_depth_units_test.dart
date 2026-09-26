import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_search_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// Regression coverage for #2412: the Advanced Search depth fields showed a
/// literal "m" and stored the typed number as metres whatever the diver's
/// depth unit, unlike the quick filter sheet.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<List<Override>> overridesFor(
    DepthUnit unit, {
    DiveFilterState? filter,
  }) async {
    final base = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(AppSettings(depthUnit: unit)),
    );
    return [
      ...base,
      if (filter != null) diveFilterProvider.overrideWith((ref) => filter),
    ];
  }

  /// The min and max depth fields, in that order. The duration fields share
  /// the Min/Max labels, so match on the depth fields' prefix icon.
  Finder depthFields() => find.byWidgetPredicate(
    (w) =>
        w is TextField &&
        w.decoration?.prefixIcon is Icon &&
        (w.decoration!.prefixIcon! as Icon).icon == Icons.arrow_downward,
  );

  TextField depthField(WidgetTester tester, int index) =>
      tester.widget<TextField>(depthFields().at(index));

  Future<void> openConditions(WidgetTester tester) async {
    await tester.tap(find.text('Conditions'));
    await tester.pumpAndSettle();
  }

  testWidgets('depth heading and fields show feet for a feet diver', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overridesFor(DepthUnit.feet),
        child: const DiveSearchPage(),
      ),
    );
    await tester.pumpAndSettle();
    await openConditions(tester);

    expect(find.text('Depth Range (ft)'), findsOneWidget);
    expect(depthFields(), findsNWidgets(2));
    expect(depthField(tester, 0).decoration?.suffixText, 'ft');
    expect(depthField(tester, 1).decoration?.suffixText, 'ft');
  });

  testWidgets('an existing metre bound is shown converted to feet', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overridesFor(
          DepthUnit.feet,
          // Conditions auto-expands because a depth bound is set.
          filter: const DiveFilterState(minDepth: 30.48, maxDepth: 30),
        ),
        child: const DiveSearchPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(depthField(tester, 0).controller?.text, '100');
    // 30 m is 98.43 ft, rounded to whole feet like the quick sheet.
    expect(depthField(tester, 1).controller?.text, '98');
  });

  group('applying', () {
    GoRouter buildRouter() => GoRouter(
      initialLocation: '/dives/search',
      routes: [
        GoRoute(
          path: '/dives',
          builder: (_, _) => const Scaffold(body: Text('dive list')),
          routes: [
            GoRoute(path: 'search', builder: (_, _) => const DiveSearchPage()),
          ],
        ),
      ],
    );

    Future<DiveFilterState> typeMinDepthAndApply(
      WidgetTester tester,
      DepthUnit unit,
      String entered,
    ) async {
      await tester.pumpWidget(
        testAppRouter(
          locale: const Locale('en'),
          router: buildRouter(),
          overrides: await overridesFor(unit),
        ),
      );
      await tester.pumpAndSettle();
      await openConditions(tester);

      await tester.enterText(depthFields().at(0), entered);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      return container.read(diveFilterProvider);
    }

    testWidgets('a feet diver typing 100 stores about 30.48 m', (tester) async {
      final filter = await typeMinDepthAndApply(tester, DepthUnit.feet, '100');
      expect(filter.minDepth, closeTo(30.48, 0.001));
      expect(find.text('dive list'), findsOneWidget);
    });

    testWidgets('a metre diver typing 30 still stores 30 m', (tester) async {
      final filter = await typeMinDepthAndApply(tester, DepthUnit.meters, '30');
      expect(filter.minDepth, 30);
    });
  });
}
