import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/surface_interval_tool/presentation/providers/surface_interval_providers.dart';
import 'package:submersion/features/surface_interval_tool/presentation/widgets/next_dive_input.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ProviderContainer> _pumpCard(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
      child: const MaterialApp(
        // Pinned: the assertions match English strings.
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: NextDiveInput())),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return ProviderScope.containerOf(tester.element(find.byType(NextDiveInput)));
}

/// Sliders render in declaration order: depth, time, O2, helium.
const _o2SliderIndex = 2;
const _heSliderIndex = 3;

Slider _sliderAt(WidgetTester tester, int index) =>
    tester.widgetList<Slider>(find.byType(Slider)).elementAt(index);

void main() {
  group('NextDiveInput gas mix controls', () {
    testWidgets('renders depth, time, O2 and helium sliders', (tester) async {
      await _pumpCard(tester);

      expect(find.byType(Slider), findsNWidgets(4));
    });

    testWidgets('shows the gas mix label and defaults to air', (tester) async {
      await _pumpCard(tester);

      expect(find.text('Gas Mix: '), findsOneWidget);
      expect(find.text('Air'), findsOneWidget);
    });

    testWidgets('names the mix as the diver changes O2', (tester) async {
      final container = await _pumpCard(tester);

      container.read(siSecondDiveO2Provider.notifier).state = 32.0;
      await tester.pumpAndSettle();

      expect(find.text('EAN32'), findsOneWidget);
      expect(find.text('Air'), findsNothing);
    });

    testWidgets('names the mix as trimix once helium is added', (tester) async {
      final container = await _pumpCard(tester);

      container.read(siSecondDiveO2Provider.notifier).state = 21.0;
      container.read(siSecondDiveHeProvider.notifier).state = 35.0;
      await tester.pumpAndSettle();

      expect(find.text('Trimix 21/35'), findsOneWidget);
    });

    testWidgets('O2 slider writes through to the second dive provider', (
      tester,
    ) async {
      final container = await _pumpCard(tester);

      _sliderAt(tester, _o2SliderIndex).onChanged!(32.0);
      await tester.pumpAndSettle();

      expect(container.read(siSecondDiveO2Provider), 32.0);
    });

    testWidgets('helium slider writes through to the second dive provider', (
      tester,
    ) async {
      final container = await _pumpCard(tester);

      _sliderAt(tester, _heSliderIndex).onChanged!(35.0);
      await tester.pumpAndSettle();

      expect(container.read(siSecondDiveHeProvider), 35.0);
    });

    testWidgets('raising O2 clamps helium so the mix stays at 100%', (
      tester,
    ) async {
      final container = await _pumpCard(tester);

      _sliderAt(tester, _heSliderIndex).onChanged!(35.0);
      await tester.pumpAndSettle();

      _sliderAt(tester, _o2SliderIndex).onChanged!(90.0);
      await tester.pumpAndSettle();

      expect(container.read(siSecondDiveO2Provider), 90.0);
      expect(container.read(siSecondDiveHeProvider), 10.0);
    });

    testWidgets('raising helium clamps O2 so the mix stays at 100%', (
      tester,
    ) async {
      final container = await _pumpCard(tester);

      _sliderAt(tester, _o2SliderIndex).onChanged!(80.0);
      await tester.pumpAndSettle();

      _sliderAt(tester, _heSliderIndex).onChanged!(40.0);
      await tester.pumpAndSettle();

      expect(container.read(siSecondDiveHeProvider), 40.0);
      expect(container.read(siSecondDiveO2Provider), 60.0);
    });
  });
}
