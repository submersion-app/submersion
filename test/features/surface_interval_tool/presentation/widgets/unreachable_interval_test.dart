import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/surface_interval_tool/presentation/providers/surface_interval_providers.dart';
import 'package:submersion/features/surface_interval_tool/presentation/widgets/surface_interval_result.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ProviderContainer> _pump(WidgetTester tester) async {
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
        home: Scaffold(
          body: SingleChildScrollView(child: SurfaceIntervalResult()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

Future<void> _setPlan(
  WidgetTester tester,
  ProviderContainer container, {
  required double firstDepth,
  required int firstTime,
  required double secondDepth,
  required int secondTime,
}) async {
  container.read(siFirstDiveDepthProvider.notifier).state = firstDepth;
  container.read(siFirstDiveTimeProvider.notifier).state = firstTime;
  container.read(siSecondDiveDepthProvider.notifier).state = secondDepth;
  container.read(siSecondDiveTimeProvider.notifier).state = secondTime;
  await tester.pumpAndSettle();
}

int _occurrences(String haystack, String needle) =>
    needle.allMatches(haystack).length;

void main() {
  group('result card when no surface interval is enough', () {
    testWidgets('does not print a fabricated six hour wait', (tester) async {
      final container = await _pump(tester);

      await _setPlan(
        tester,
        container,
        firstDepth: 18.0,
        firstTime: 45,
        secondDepth: 18.0,
        secondTime: 45,
      );

      expect(
        container.read(siMinimumIntervalProvider).outcome,
        SiIntervalOutcome.impossible,
      );
      expect(
        find.text('6h 0m'),
        findsNothing,
        reason: 'the old search bound must never surface as an answer',
      );
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('names the longest no-stop dive the diver can plan', (
      tester,
    ) async {
      final container = await _pump(tester);

      await _setPlan(
        tester,
        container,
        firstDepth: 18.0,
        firstTime: 45,
        secondDepth: 18.0,
        secondTime: 45,
      );

      final maxMinutes =
          container.read(siMinimumIntervalProvider).cleanTissueNoStopSeconds ~/
          60;

      expect(
        find.textContaining('No surface interval is enough'),
        findsOneWidget,
      );
      expect(find.textContaining('$maxMinutes min'), findsOneWidget);
    });

    testWidgets('does not announce a bare em dash to a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final container = await _pump(tester);

      await _setPlan(
        tester,
        container,
        firstDepth: 18.0,
        firstTime: 45,
        secondDepth: 18.0,
        secondTime: 45,
      );

      final label = tester
          .getSemantics(find.byType(SurfaceIntervalResult))
          .label;
      expect(label, contains('Not achievable at any surface interval'));
      expect(label, isNot(contains('—')));

      handle.dispose();
    });

    testWidgets('tells a screen reader the ceiling, and only once', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final container = await _pump(tester);

      await _setPlan(
        tester,
        container,
        firstDepth: 18.0,
        firstTime: 45,
        secondDepth: 18.0,
        secondTime: 45,
      );

      final maxMinutes =
          container.read(siMinimumIntervalProvider).cleanTissueNoStopSeconds ~/
          60;
      final label = tester
          .getSemantics(find.byType(SurfaceIntervalResult))
          .label;

      // The remedy and the ceiling are the whole point of this state, and a
      // screen reader has no other way to reach them.
      expect(label, contains('$maxMinutes min'));
      expect(label, contains('Shorten the second dive'));
      expect(
        _occurrences(label, 'Not achievable at any surface interval'),
        1,
        reason: 'the summary should add information, not restate itself',
      );

      handle.dispose();
    });

    testWidgets('stops advising a longer wait that cannot help', (
      tester,
    ) async {
      final container = await _pump(tester);

      await _setPlan(
        tester,
        container,
        firstDepth: 18.0,
        firstTime: 45,
        secondDepth: 18.0,
        secondTime: 45,
      );

      expect(
        find.textContaining('Increase surface interval'),
        findsNothing,
        reason: 'waiting longer cannot fix a dive that busts the no-stop limit',
      );
    });
  });

  group('result card when the wait runs past the planner horizon', () {
    testWidgets('says wait longer rather than change the dive', (tester) async {
      final container = await _pump(tester);

      // Heavily loaded slow tissues: the dive fits on clean tissues, so the
      // remedy is patience, not a different plan.
      await _setPlan(
        tester,
        container,
        firstDepth: 55.0,
        firstTime: 120,
        secondDepth: 12.0,
        secondTime: 100,
      );

      expect(
        container.read(siMinimumIntervalProvider).outcome,
        SiIntervalOutcome.beyondHorizon,
      );
      expect(find.text('> 6h'), findsOneWidget);
      expect(find.text('—'), findsNothing);
      expect(
        find.textContaining('No surface interval is enough'),
        findsNothing,
        reason: 'this dive is possible, it just needs a longer wait',
      );
      expect(
        find.textContaining('runs past the 6 hours this planner searches'),
        findsOneWidget,
      );
    });

    testWidgets('reads the wait out rather than announcing "> 6h"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final container = await _pump(tester);

      await _setPlan(
        tester,
        container,
        firstDepth: 55.0,
        firstTime: 120,
        secondDepth: 12.0,
        secondTime: 100,
      );

      final label = tester
          .getSemantics(find.byType(SurfaceIntervalResult))
          .label;
      expect(
        label,
        contains('More than 6 hours'),
        reason: 'a screen reader must not be handed the "> 6h" glyph',
      );
      expect(label, isNot(contains('> 6h')));

      // The summary must explain the wait rather than say the same words twice.
      expect(
        _occurrences(label, 'More than 6 hours'),
        1,
        reason: 'the status slot should add information, not restate itself',
      );
      expect(label, contains('this planner searches'));

      handle.dispose();
    });
  });

  group('result card when a surface interval does help', () {
    testWidgets('still shows the wait and the standard advice', (tester) async {
      final container = await _pump(tester);

      await _setPlan(
        tester,
        container,
        firstDepth: 18.0,
        firstTime: 45,
        secondDepth: 18.0,
        secondTime: 40,
      );
      container.read(siSurfaceIntervalProvider.notifier).state = 10;
      await tester.pumpAndSettle();

      final minutes = container.read(siMinimumIntervalProvider).minutes!;
      final expected = minutes >= 60
          ? '${minutes ~/ 60}h ${minutes % 60}m'
          : '$minutes min';

      expect(find.text(expected), findsWidgets);
      expect(find.text('—'), findsNothing);
      expect(
        find.textContaining('No surface interval is enough'),
        findsNothing,
      );
      expect(find.textContaining('Increase surface interval'), findsOneWidget);
    });
  });
}
