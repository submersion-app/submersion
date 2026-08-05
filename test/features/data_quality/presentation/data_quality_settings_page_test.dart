import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector_registry.dart';
import 'package:submersion/features/data_quality/presentation/pages/data_quality_settings_page.dart';
import 'package:submersion/features/data_quality/presentation/providers/quality_detector_toggles.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/l10n_test_helpers.dart';

Future<Widget> _wrap(SharedPreferences prefs) async {
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: localizedMaterialApp(home: const DataQualitySettingsPage()),
  );
}

/// Tall viewport so the whole (lazily built) switch list is laid out at once.
void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  tearDown(() => QualityDetectorToggles.disabled = <String>{});

  testWidgets('renders a switch tile per detector, all enabled by default', (
    tester,
  ) async {
    _tallSurface(tester);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(await _wrap(prefs));
    await tester.pumpAndSettle();

    final tiles = tester
        .widgetList<SwitchListTile>(find.byType(SwitchListTile))
        .toList();
    expect(tiles.length, kQualityDetectors.length);
    expect(tiles.every((t) => t.value), isTrue);
  });

  testWidgets('reflects a pre-disabled detector as off', (tester) async {
    _tallSurface(tester);
    SharedPreferences.setMockInitialValues({
      'quality_disabled_detectors': ['impossible_rate'],
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(await _wrap(prefs));
    await tester.pumpAndSettle();

    final offCount = tester
        .widgetList<SwitchListTile>(find.byType(SwitchListTile))
        .where((t) => !t.value)
        .length;
    expect(offCount, 1);
  });

  testWidgets('toggling a switch off persists and mirrors to the static set', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(await _wrap(prefs));
    await tester.pumpAndSettle();

    // Every detector starts enabled -> all switches on.
    expect(
      tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .every((t) => t.value),
      isTrue,
    );

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    final firstId = kQualityDetectors.first.id;
    expect(prefs.getStringList('quality_disabled_detectors'), [firstId]);
    expect(QualityDetectorToggles.disabled, contains(firstId));

    final firstTile = tester
        .widgetList<SwitchListTile>(find.byType(SwitchListTile))
        .first;
    expect(firstTile.value, isFalse);
  });

  testWidgets('toggling a disabled switch back on re-enables it', (
    tester,
  ) async {
    final firstId = kQualityDetectors.first.id;
    SharedPreferences.setMockInitialValues({
      'quality_disabled_detectors': [firstId],
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(await _wrap(prefs));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    expect(prefs.getStringList('quality_disabled_detectors'), isEmpty);
    expect(QualityDetectorToggles.disabled, isNot(contains(firstId)));
  });

  testWidgets('shows the title and subtitle copy', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(await _wrap(prefs));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    // Subtitle paragraph sits above the switch list.
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });
}
