import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_range_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The seam between the range-selection provider and the chart that now draws
/// the handles (issue #1579): the page hands the chart the selected window and
/// writes a dragged window back.
void main() {
  const profile = [
    DiveProfilePoint(timestamp: 0, depth: 0.0),
    DiveProfilePoint(timestamp: 60, depth: 10.0),
    DiveProfilePoint(timestamp: 120, depth: 20.0),
    DiveProfilePoint(timestamp: 180, depth: 0.0),
  ];

  late Dive dive;

  setUp(() {
    dive = createTestDiveWithBottomTime().copyWith(profile: profile);
  });

  Future<void> pumpPage(WidgetTester tester) async {
    final base = await getBaseOverrides();
    final originalOnError = FlutterError.onError;
    addTearDown(() => FlutterError.onError = originalOnError);
    FlutterError.onError = (d) {
      if (d.toString().contains('overflowed')) return;
      originalOnError?.call(d);
    };
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveProvider(dive.id).overrideWith((ref) async => dive),
          gasSwitchesProvider(
            dive.id,
          ).overrideWith((ref) async => <GasSwitchWithTank>[]),
          tankPressuresProvider(
            dive.id,
          ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveDetailPage(diveId: dive.id, embedded: true)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    FlutterError.onError = originalOnError;
  }

  DiveProfileChart chartOf(WidgetTester tester) =>
      tester.widget<DiveProfileChart>(find.byType(DiveProfileChart));

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(DiveProfileChart)));

  testWidgets('the chart is given no range while range mode is off', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(chartOf(tester).rangeSelection, isNull);
  });

  testWidgets('enabling range mode hands the chart the selected window', (
    tester,
  ) async {
    await pumpPage(tester);
    final container = containerOf(tester);

    container.read(rangeSelectionProvider(dive.id).notifier).enableRangeMode();
    await tester.pump();

    final state = container.read(rangeSelectionProvider(dive.id));
    final selection = chartOf(tester).rangeSelection;
    expect(selection, isNotNull);
    expect(selection!.startSeconds, state.startTimestamp);
    expect(selection.endSeconds, state.endTimestamp);
    // The chart clamps the end handle at the last drawn sample, so the range
    // can never run past the profile the user is measuring.
    expect(selection.maxSeconds, 180);
  });

  testWidgets('a dragged window is written back to the provider', (
    tester,
  ) async {
    await pumpPage(tester);
    final container = containerOf(tester);
    container.read(rangeSelectionProvider(dive.id).notifier).enableRangeMode();
    await tester.pump();

    chartOf(tester).onRangeChanged!(30, 90);
    await tester.pump();

    final state = container.read(rangeSelectionProvider(dive.id));
    expect(state.startTimestamp, 30);
    expect(state.endTimestamp, 90);
    expect(chartOf(tester).rangeSelection!.startSeconds, 30);
  });
}
