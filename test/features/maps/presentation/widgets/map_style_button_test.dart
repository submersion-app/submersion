import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/features/maps/presentation/widgets/map_style_button.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  late MockSettingsNotifier notifier;

  Future<void> pumpButton(
    WidgetTester tester, {
    MapStyle initial = MapStyle.openStreetMap,
  }) async {
    notifier = MockSettingsNotifier(
      const AppSettings().copyWith(mapStyle: initial),
    );
    await tester.pumpWidget(
      // Pinned to English so the label finders are deterministic.
      testApp(
        locale: const Locale('en'),
        overrides: [settingsProvider.overrideWith((ref) => notifier)],
        child: const Align(
          alignment: Alignment.topRight,
          child: MapStyleButton(),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byType(MapStyleButton));
    await tester.pumpAndSettle();
  }

  CheckedPopupMenuItem<MapStyle> menuItem(WidgetTester tester, String label) {
    return tester.widget<CheckedPopupMenuItem<MapStyle>>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(CheckedPopupMenuItem<MapStyle>),
      ),
    );
  }

  testWidgets('shows a layers button labelled for screen readers', (
    tester,
  ) async {
    await pumpButton(tester);

    expect(find.byIcon(Icons.layers_outlined), findsOneWidget);
    // Same wording as the Settings > Appearance row it mirrors.
    expect(find.byTooltip('Map Style'), findsOneWidget);
  });

  testWidgets('opens a menu listing every map style', (tester) async {
    await pumpButton(tester);
    await openMenu(tester);

    expect(find.text('Street Map'), findsOneWidget);
    expect(find.text('Topographic'), findsOneWidget);
    expect(find.text('Satellite'), findsOneWidget);
    expect(
      find.byType(CheckedPopupMenuItem<MapStyle>),
      findsNWidgets(MapStyle.values.length),
    );
  });

  testWidgets('checks only the style currently in use', (tester) async {
    await pumpButton(tester, initial: MapStyle.openTopoMap);
    await openMenu(tester);

    expect(menuItem(tester, 'Topographic').checked, isTrue);
    expect(menuItem(tester, 'Street Map').checked, isFalse);
    expect(menuItem(tester, 'Satellite').checked, isFalse);
  });

  testWidgets('choosing a style saves it as the map style setting', (
    tester,
  ) async {
    await pumpButton(tester);
    await openMenu(tester);

    await tester.tap(find.text('Satellite'));
    await tester.pumpAndSettle();

    expect(notifier.state.mapStyle, MapStyle.esriSatellite);
    expect(find.text('Satellite'), findsNothing, reason: 'menu closes');
  });

  testWidgets('reopening after a change checks the new style', (tester) async {
    await pumpButton(tester);
    await openMenu(tester);
    await tester.tap(find.text('Topographic'));
    await tester.pumpAndSettle();

    await openMenu(tester);

    expect(menuItem(tester, 'Topographic').checked, isTrue);
    expect(menuItem(tester, 'Street Map').checked, isFalse);
  });
}
