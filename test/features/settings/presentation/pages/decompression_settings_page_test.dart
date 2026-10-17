import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/decompression_settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Widget _app({VoidCallback? onBack, MockSettingsNotifier? notifier}) =>
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) =>
              notifier ??
              MockSettingsNotifier(const AppSettings(gfLow: 30, gfHigh: 70)),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DecompressionSettingsPage(onBack: onBack),
      ),
    );

void main() {
  testWidgets('is its own page with an app bar and the current GF', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Decompression'),
      ),
      findsOneWidget,
    );
    expect(find.text('GF 30/70'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('GTR reserve pressure'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('GTR reserve pressure'), findsOneWidget);
  });

  testWidgets('without onBack it shows no back arrow of its own', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Back'), findsNothing);
  });

  testWidgets('with onBack the back arrow calls it', (tester) async {
    var backs = 0;
    await tester.pumpWidget(_app(onBack: () => backs++));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(backs, 1);
  });

  group('editing', () {
    late MockSettingsNotifier notifier;

    Future<void> pump(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      notifier = MockSettingsNotifier(const AppSettings(gfLow: 30, gfHigh: 70));
      await tester.pumpWidget(_app(notifier: notifier));
      await tester.pumpAndSettle();
    }

    testWidgets('the GF tile opens the picker and saves a preset', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('Current Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Medium'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(notifier.state.gfLow, 50);
      expect(notifier.state.gfHigh, 85);
      expect(find.text('GF 50/85'), findsOneWidget);
    });

    testWidgets('the END limit dialog saves the slider value', (tester) async {
      await pump(tester);

      await tester.tap(find.text('END Limit'));
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Slider),
        ),
      );
      slider.onChanged!(40);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(notifier.state.endLimit, 40);
    });

    testWidgets('the O2 narcotic switch writes through', (tester) async {
      await pump(tester);
      final before = notifier.state.o2Narcotic;

      await tester.tap(
        find.ancestor(
          of: find.text('O2 is narcotic'),
          matching: find.byType(SwitchListTile),
        ),
      );
      await tester.pumpAndSettle();

      expect(notifier.state.o2Narcotic, !before);
    });

    testWidgets('the ascent gas dropdown writes the chosen set', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('All carried cylinders'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deco/stage + back gas').last);
      await tester.pumpAndSettle();

      expect(notifier.state.ascentGasSet, AscentGasSet.decoStageOnly);
    });

    testWidgets('each data-source dropdown writes its own setting', (
      tester,
    ) async {
      await pump(tester);

      final sources = <String, MetricDataSource Function(AppSettings)>{
        'NDL Source': (s) => s.defaultNdlSource,
        'Deco Stop Source': (s) => s.defaultDecoStopSource,
        'TTS Source': (s) => s.defaultTtsSource,
        'GTR Source': (s) => s.defaultGtrSource,
        'CNS Source': (s) => s.defaultCnsSource,
      };
      for (final MapEntry(key: label, value: read) in sources.entries) {
        expect(read(notifier.state), MetricDataSource.computer, reason: label);
        await tester.tap(
          find.descendant(
            of: find.ancestor(
              of: find.text(label),
              matching: find.byType(ListTile),
            ),
            matching: find.byType(DropdownButton<MetricDataSource>),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Calculated').last);
        await tester.pumpAndSettle();
        expect(
          read(notifier.state),
          MetricDataSource.calculated,
          reason: label,
        );
      }
    });
  });
}
