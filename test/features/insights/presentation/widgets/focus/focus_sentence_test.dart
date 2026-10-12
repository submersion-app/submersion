import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/presentation/providers/insights_focus_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_sentence.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_database.dart';

void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
    double? defaultThreshold = 16,
    double width = 800,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(settings),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          // Re-resolves on a metric change, as the real provider does, and
          // gives max depth its own mean so a stale value from the previous
          // metric cannot pass for the new one.
          focusThresholdDefaultProvider.overrideWith((ref) async {
            final metric = ref.watch(
              focusSelectionProvider.select((s) => s.metric),
            );
            if (defaultThreshold == null) return null;
            return metric == FocusMetric.maxDepth ? 20 : defaultThreshold;
          }),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FocusSentence()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return ProviderScope.containerOf(
      tester.element(find.byType(FocusSentence)),
    );
  }

  Finder field() => find.byKey(const ValueKey('focus-threshold-field'));
  TextField fieldWidget(WidgetTester tester) =>
      tester.widget<TextField>(field());

  testWidgets('the ranked sentence reads as words around three controls', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Show the'), findsOneWidget);
    expect(find.text('dives with the'), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-count')), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-mode')), findsOneWidget);
    expect(find.byKey(const ValueKey('focus-metric')), findsOneWidget);
    expect(field(), findsNothing);
  });

  testWidgets('RMV offers best and worst; depth offers lowest and highest', (
    tester,
  ) async {
    final c = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('focus-mode')));
    await tester.pumpAndSettle();
    expect(find.text('best'), findsWidgets);
    expect(find.text('worst'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(
      metric: FocusMetric.maxDepth,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('focus-mode')));
    await tester.pumpAndSettle();
    expect(find.text('highest'), findsOneWidget);
  });

  testWidgets('the metric menu is grouped', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('focus-metric')));
    await tester.pumpAndSettle();
    expect(find.text('Depth and time'), findsOneWidget);
    expect(find.text('Exposure'), findsOneWidget);
    expect(find.text('CNS at end'), findsOneWidget);
  });

  testWidgets('picking 20 sets N; Custom opens a dialog that sets N', (
    tester,
  ) async {
    final c = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('focus-count')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20').last);
    await tester.pumpAndSettle();
    expect(c.read(focusSelectionProvider).count, 20);
    await tester.tap(find.byKey(const ValueKey('focus-count')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom...').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('focus-count-custom-field')),
      '7',
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(c.read(focusSelectionProvider).count, 7);
  });

  testWidgets('an out-of-range custom count shows the error and keeps N', (
    tester,
  ) async {
    final c = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('focus-count')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom...').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('focus-count-custom-field')),
      '0',
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a whole number from 1 to 999'), findsOneWidget);
    expect(c.read(focusSelectionProvider).count, 10);
  });

  testWidgets(
    'above rewrites the sentence and pre-fills the mean with its unit',
    (tester) async {
      final c = await pump(tester);
      await tester.tap(find.byKey(const ValueKey('focus-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('above').last);
      await tester.pumpAndSettle();
      expect(find.text('Show the dives with'), findsOneWidget);
      expect(fieldWidget(tester).controller!.text, '16');
      expect(fieldWidget(tester).decoration!.suffixText, 'L/min');
      expect(c.read(focusSelectionProvider).threshold, 16);
      expect(c.read(focusSelectionProvider).mode, FocusMode.above);
    },
  );

  testWidgets('an imperial threshold is stored in litres per minute', (
    tester,
  ) async {
    final c = await pump(
      tester,
      settings: const AppSettings(volumeUnit: VolumeUnit.cubicFeet),
    );
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(
      mode: FocusMode.above,
      threshold: 20,
    );
    await tester.pump();
    await tester.enterText(field(), '0.75');
    await tester.pump();
    expect(c.read(focusSelectionProvider).threshold, closeTo(21.24, 0.01));
  });

  testWidgets(
    'changing the metric in a threshold mode clears and re-fills the value',
    (tester) async {
      final c = await pump(tester);
      c.read(focusSelectionProvider.notifier).state = const FocusSelection(
        mode: FocusMode.above,
        threshold: 20,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('focus-metric')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Max depth').last);
      await tester.pumpAndSettle();
      final s = c.read(focusSelectionProvider);
      expect(s.metric, FocusMetric.maxDepth);
      // Max depth's own mean, never the 16 L/min RMV carried before.
      expect(s.threshold, 20);
      expect(fieldWidget(tester).controller!.text, '20');
      expect(fieldWidget(tester).decoration!.suffixText, 'm');
    },
  );

  testWidgets(
    'no dives with the metric leaves the threshold empty without error',
    (tester) async {
      final c = await pump(tester, defaultThreshold: null);
      c.read(focusSelectionProvider.notifier).state = const FocusSelection(
        mode: FocusMode.above,
      );
      await tester.pump();
      await tester.pump();
      expect(fieldWidget(tester).controller!.text, '');
      expect(c.read(focusSelectionProvider).threshold, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a negative RMV is rejected; a sub-zero air temp is accepted', (
    tester,
  ) async {
    final c = await pump(tester);
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(
      mode: FocusMode.above,
      threshold: 20,
    );
    await tester.pump();
    await tester.enterText(field(), '-1');
    await tester.pump();
    expect(find.text('Enter zero or more'), findsOneWidget);
    expect(c.read(focusSelectionProvider).threshold, 20);
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(
      metric: FocusMetric.airTemp,
      mode: FocusMode.below,
      threshold: 5,
    );
    await tester.pump();
    await tester.enterText(field(), '-2');
    await tester.pump();
    expect(c.read(focusSelectionProvider).threshold, -2);
  });

  testWidgets('a failing default leaves the threshold empty, no exception', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          focusSelectionProvider.overrideWith(
            (ref) => const FocusSelection(mode: FocusMode.above),
          ),
          focusThresholdDefaultProvider.overrideWith(
            (ref) async => throw StateError('series failed'),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FocusSentence()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(fieldWidget(tester).controller!.text, '');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sentence wraps on a phone', (tester) async {
    await pump(tester, width: 360);
    expect(tester.takeException(), isNull);
  });
}
