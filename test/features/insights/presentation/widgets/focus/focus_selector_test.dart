import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/insights/domain/focus/focus_metric.dart';
import 'package:submersion/features/insights/domain/focus/focus_selection.dart';
import 'package:submersion/features/insights/presentation/providers/insights_focus_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/focus/focus_selector.dart';
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
    Locale locale = const Locale('en'),
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
        overrides: overrides,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: FocusSelector()),
        ),
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(
      tester.element(find.byType(FocusSelector)),
    );
  }

  testWidgets('RMV offers Best and Worst; depth offers Lowest and Highest', (
    tester,
  ) async {
    final c = await pump(tester);
    expect(find.text('Best'), findsOneWidget);
    expect(find.text('Worst'), findsOneWidget);
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(
      metric: FocusMetric.maxDepth,
    );
    await tester.pump();
    expect(find.text('Lowest'), findsOneWidget);
    expect(find.text('Highest'), findsOneWidget);
  });

  testWidgets('a count chip sets N', (tester) async {
    final c = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('focus-count-20')));
    await tester.pump();
    expect(c.read(focusSelectionProvider).count, 20);
  });

  testWidgets('an out-of-range count shows an error and keeps N', (
    tester,
  ) async {
    final c = await pump(tester);
    await tester.enterText(
      find.byKey(const ValueKey('focus-count-field')),
      '0',
    );
    await tester.pump();
    expect(find.text('Enter a whole number from 1 to 999'), findsOneWidget);
    expect(c.read(focusSelectionProvider).count, 10);
  });

  testWidgets('an imperial RMV threshold is stored in litres per minute', (
    tester,
  ) async {
    final c = await pump(
      tester,
      settings: const AppSettings(volumeUnit: VolumeUnit.cubicFeet),
    );
    await tester.tap(find.text('Above'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('focus-threshold-field')),
      '0.75',
    );
    await tester.pump();
    final s = c.read(focusSelectionProvider);
    expect(s.mode, FocusMode.above);
    expect(s.threshold, closeTo(21.24, 0.01));
  });

  testWidgets('a negative RMV is rejected', (tester) async {
    final c = await pump(tester);
    await tester.tap(find.text('Above'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('focus-threshold-field')),
      '-1',
    );
    await tester.pump();
    expect(find.text('Enter zero or more'), findsOneWidget);
    expect(c.read(focusSelectionProvider).threshold, isNull);
  });

  testWidgets('a sub-zero water temperature is accepted', (tester) async {
    final c = await pump(tester);
    c.read(focusSelectionProvider.notifier).state = const FocusSelection(
      metric: FocusMetric.waterTemp,
      mode: FocusMode.below,
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('focus-threshold-field')),
      '-1',
    );
    await tester.pump();
    expect(c.read(focusSelectionProvider).threshold, closeTo(-1, 1e-9));
  });

  testWidgets('a comma decimal reads as a decimal in German', (tester) async {
    final previous = Intl.defaultLocale;
    Intl.defaultLocale = 'de';
    addTearDown(() => Intl.defaultLocale = previous);
    final c = await pump(tester);
    await tester.tap(find.text('Above'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('focus-threshold-field')),
      '0,75',
    );
    await tester.pump();
    expect(c.read(focusSelectionProvider).threshold, closeTo(0.75, 1e-9));
  });

  testWidgets('switching metric clears a threshold', (tester) async {
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
    expect(s.threshold, isNull);
  });

  testWidgets('a long mode label stays on one line on a phone', (tester) async {
    await pump(tester, locale: const Locale('de'), width: 390);
    final label = find.text('Schlechteste');
    expect(label, findsOneWidget);
    // One line of 14 px text; a mid-word wrap would make it two.
    expect(tester.getSize(label).height, lessThan(24));
  });

  testWidgets('clearing the threshold field clears the stored threshold', (
    tester,
  ) async {
    final c = await pump(tester);
    await tester.tap(find.text('Above'));
    await tester.pump();
    final field = find.byKey(const ValueKey('focus-threshold-field'));
    await tester.enterText(field, '20');
    await tester.pump();
    expect(c.read(focusSelectionProvider).threshold, 20);
    await tester.enterText(field, '');
    await tester.pump();
    expect(c.read(focusSelectionProvider).threshold, isNull);
    expect(find.text('Enter a number'), findsNothing);
  });
}
