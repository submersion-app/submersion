import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/surface_interval_tool/presentation/providers/surface_interval_providers.dart';
import 'package:submersion/features/surface_interval_tool/presentation/widgets/next_dive_input.dart';
import 'package:submersion/features/surface_interval_tool/presentation/widgets/previous_dive_input.dart';
import 'package:submersion/features/surface_interval_tool/presentation/widgets/surface_interval_result.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier({DepthUnit depthUnit = DepthUnit.meters})
    : super(AppSettings(depthUnit: depthUnit));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget child, {
  DepthUnit depthUnit = DepthUnit.meters,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _TestSettingsNotifier(depthUnit: depthUnit),
        ),
      ],
      child: MaterialApp(
        // Pinned: the assertions match English strings.
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

/// Matches the warning body regardless of the numbers interpolated into it.
final _warningFinder = find.textContaining('MOD for this mix is');

void main() {
  group('second dive MOD warning', () {
    testWidgets('is absent for air at a recreational depth', (tester) async {
      final container = await _pump(tester, const NextDiveInput());

      container.read(siSecondDiveDepthProvider.notifier).state = 30.0;
      await tester.pumpAndSettle();

      expect(_warningFinder, findsNothing);
    });

    testWidgets('appears once the mix busts its MOD', (tester) async {
      final container = await _pump(tester, const NextDiveInput());

      container.read(siSecondDiveDepthProvider.notifier).state = 30.0;
      container.read(siSecondDiveO2Provider.notifier).state = 40.0;
      await tester.pumpAndSettle();

      expect(_warningFinder, findsOneWidget);
      // ppO2 1.60, limit 1.40, MOD 25 m at 30 m.
      expect(find.textContaining('1.60'), findsOneWidget);
      expect(find.textContaining('1.40'), findsOneWidget);
      expect(find.textContaining('25m'), findsOneWidget);
    });

    testWidgets('clears again when the diver shallows up', (tester) async {
      final container = await _pump(tester, const NextDiveInput());

      container.read(siSecondDiveDepthProvider.notifier).state = 30.0;
      container.read(siSecondDiveO2Provider.notifier).state = 40.0;
      await tester.pumpAndSettle();
      expect(_warningFinder, findsOneWidget);

      container.read(siSecondDiveDepthProvider.notifier).state = 20.0;
      await tester.pumpAndSettle();

      expect(_warningFinder, findsNothing);
    });

    testWidgets('reports the MOD in the diver units', (tester) async {
      final container = await _pump(
        tester,
        const NextDiveInput(),
        depthUnit: DepthUnit.feet,
      );

      container.read(siSecondDiveDepthProvider.notifier).state = 30.0;
      container.read(siSecondDiveO2Provider.notifier).state = 40.0;
      await tester.pumpAndSettle();

      // 25 m MOD is 82 ft; the metric figure must not leak through.
      expect(find.textContaining('82ft'), findsOneWidget);
      expect(find.textContaining('25m'), findsNothing);
    });
  });

  group('first dive MOD warning', () {
    testWidgets('warns independently of the second dive', (tester) async {
      final container = await _pump(tester, const PreviousDiveInput());

      container.read(siFirstDiveDepthProvider.notifier).state = 40.0;
      container.read(siFirstDiveO2Provider.notifier).state = 32.0;
      await tester.pumpAndSettle();

      expect(_warningFinder, findsOneWidget);
    });
  });

  group('result card gas verdict', () {
    testWidgets('does not claim safe to dive while a mix busts MOD', (
      tester,
    ) async {
      final container = await _pump(tester, const SurfaceIntervalResult());

      // A generous interval and a short shallow dive: no-deco is satisfied.
      container.read(siFirstDiveDepthProvider.notifier).state = 18.0;
      container.read(siFirstDiveTimeProvider.notifier).state = 20;
      container.read(siSurfaceIntervalProvider.notifier).state = 180;
      container.read(siSecondDiveDepthProvider.notifier).state = 30.0;
      container.read(siSecondDiveTimeProvider.notifier).state = 10;
      await tester.pumpAndSettle();

      expect(container.read(siSecondDiveIsSafeProvider), isTrue);
      expect(find.text('Gas unsafe at this depth'), findsNothing);

      // Now make the second dive's gas unbreathable at that depth.
      container.read(siSecondDiveO2Provider.notifier).state = 40.0;
      await tester.pumpAndSettle();

      expect(
        find.text('Gas unsafe at this depth'),
        findsOneWidget,
        reason: 'the result card must surface the oxygen problem',
      );
    });

    testWidgets('keeps the deco advice separate from the gas warning', (
      tester,
    ) async {
      final container = await _pump(tester, const SurfaceIntervalResult());

      container.read(siFirstDiveDepthProvider.notifier).state = 18.0;
      container.read(siFirstDiveTimeProvider.notifier).state = 20;
      container.read(siSurfaceIntervalProvider.notifier).state = 180;
      container.read(siSecondDiveDepthProvider.notifier).state = 30.0;
      container.read(siSecondDiveTimeProvider.notifier).state = 10;
      container.read(siSecondDiveO2Provider.notifier).state = 40.0;
      await tester.pumpAndSettle();

      // Gas is the only problem, so the "wait longer" advice stays hidden.
      expect(find.text('Gas unsafe at this depth'), findsOneWidget);
      expect(find.textContaining('Increase surface interval'), findsNothing);
    });
  });
}
