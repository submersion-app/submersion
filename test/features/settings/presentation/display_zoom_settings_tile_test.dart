import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/theme/display_zoom.dart';
import 'package:submersion/features/settings/presentation/providers/display_zoom_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/display_zoom_settings_tile.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Future<ProviderContainer> _pumpTile(
  WidgetTester tester,
  Map<String, Object> initial,
) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: Scaffold(body: DisplayZoomSettingsTile()),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the current zoom as a percentage', (tester) async {
    await _pumpTile(tester, {'display_zoom': 0.85});

    expect(find.text('Display size'), findsOneWidget);
    expect(find.text('85%'), findsOneWidget);
  });

  testWidgets('hides the reset action at 100%', (tester) async {
    await _pumpTile(tester, {});

    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Reset'), findsNothing);
  });

  testWidgets('reset returns the zoom to 100%', (tester) async {
    final container = await _pumpTile(tester, {'display_zoom': 0.75});

    expect(find.text('Reset'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(
      container.read(displayZoomNotifierProvider),
      DisplayZoom.defaultValue,
    );
  });

  testWidgets('drags rescale live but only persist on release', (tester) async {
    final container = await _pumpTile(tester, {});
    final prefs = await SharedPreferences.getInstance();
    final slider = tester.widget<Slider>(find.byType(Slider));

    // Mid-drag: state moves so the app rescales, storage stays untouched.
    slider.onChanged!(0.8);
    await tester.pump();
    expect(container.read(displayZoomNotifierProvider), 0.8);
    expect(prefs.getDouble('display_zoom'), isNull);

    slider.onChanged!(0.75);
    await tester.pump();
    expect(container.read(displayZoomNotifierProvider), 0.75);
    expect(prefs.getDouble('display_zoom'), isNull);

    // Release commits once.
    slider.onChangeEnd!(0.75);
    await tester.pumpAndSettle();
    expect(prefs.getDouble('display_zoom'), 0.75);
  });

  testWidgets('the slider is configured for the supported range', (
    tester,
  ) async {
    await _pumpTile(tester, {});

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, DisplayZoom.min);
    expect(slider.max, DisplayZoom.max);
    expect(slider.divisions, DisplayZoom.divisions);
  });
}
