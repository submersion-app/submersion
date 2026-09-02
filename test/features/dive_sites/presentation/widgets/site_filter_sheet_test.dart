import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_filter_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Opens the sheet the way the site list does: as a modal bottom sheet handed
/// a [WidgetRef]. Going through a real route keeps "Apply"'s Navigator.pop
/// legitimate.
class _SheetLauncher extends ConsumerWidget {
  const _SheetLauncher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => SiteFilterSheet(ref: ref),
          ),
          child: const Text('open'),
        ),
      ),
    );
  }
}

Future<ProviderContainer> _container({
  required AppSettings settings,
  SiteFilterState filter = const SiteFilterState(),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      settingsProvider.overrideWith((ref) => MockSettingsNotifier(settings)),
      siteFilterProvider.overrideWith((ref) => filter),
    ],
  );
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      // Pinned so assertions on English labels ("Max", "Apply Filters") do not
      // depend on the host machine's locale, which flutter_test forwards.
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _SheetLauncher(),
    ),
  );
}

/// The sheet is taller than a default test window; its overflow is a layout
/// artifact of the surface size, not the behavior under test.
void _useTallSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(1000, 2200);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.toString().contains('overflowed')) return;
    originalOnError?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalOnError);
}

Future<void> _openSheet(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(_app(container));
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('depth filter unit handling (issue #1257)', () {
    testWidgets('suffixes the depth fields with the diver depth unit', (
      tester,
    ) async {
      _useTallSurface(tester);
      final container = await _container(
        settings: const AppSettings(depthUnit: DepthUnit.feet),
      );
      addTearDown(container.dispose);
      await _openSheet(tester, container);

      expect(find.text('ft'), findsNWidgets(2));
      expect(find.text('m'), findsNothing);
    });

    testWidgets('seeds the fields by converting the stored meter bounds', (
      tester,
    ) async {
      _useTallSurface(tester);
      final container = await _container(
        settings: const AppSettings(depthUnit: DepthUnit.feet),
        filter: const SiteFilterState(minDepth: 5, maxDepth: 30),
      );
      addTearDown(container.dispose);
      await _openSheet(tester, container);

      // 5 m -> 16.40 ft, 30 m -> 98.43 ft, rounded to whole units.
      expect(find.widgetWithText(TextField, '16'), findsOneWidget);
      expect(find.widgetWithText(TextField, '98'), findsOneWidget);
    });

    testWidgets('converts a depth typed in feet back to meters on apply', (
      tester,
    ) async {
      _useTallSurface(tester);
      final container = await _container(
        settings: const AppSettings(depthUnit: DepthUnit.feet),
      );
      addTearDown(container.dispose);
      await _openSheet(tester, container);

      await tester.enterText(find.widgetWithText(TextField, 'Max'), '100');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      // 100 ft -> 30.48 m, which is what the site query compares against.
      final applied = container.read(siteFilterProvider).maxDepth;
      expect(applied, isNotNull);
      expect(applied!, closeTo(30.48, 0.01));
    });

    testWidgets('leaves a metric diver typing meters untouched', (
      tester,
    ) async {
      _useTallSurface(tester);
      final container = await _container(settings: const AppSettings());
      addTearDown(container.dispose);
      await _openSheet(tester, container);

      await tester.enterText(find.widgetWithText(TextField, 'Max'), '30');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      expect(container.read(siteFilterProvider).maxDepth, closeTo(30, 0.001));
    });
  });
}
