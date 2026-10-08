import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/year_play_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/year_range_slider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget child, {
  ({int first, int last})? span = (first: 2019, last: 2024),
}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        connectionsYearSpanProvider.overrideWith((ref) async => span),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
}

void main() {
  testWidgets('the year slider writes the date range into the filter', (
    tester,
  ) async {
    final c = await _pump(tester, const YearRangeSlider());
    expect(find.byType(RangeSlider), findsOneWidget);
    expect(find.text('Years 2019 to 2024'), findsOneWidget);
    final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
    slider.onChangeEnd!(const RangeValues(2021, 2023));
    await tester.pump();
    final f = c.read(connectionsFilterProvider);
    expect(f.startDate, DateTime(2021, 1, 1));
    expect(f.endDate, DateTime(2023, 12, 31));
    expect(find.text('Years 2021 to 2023'), findsOneWidget);
  });

  testWidgets('the year slider hides on a one-year log or no dives', (
    tester,
  ) async {
    await _pump(
      tester,
      const YearRangeSlider(),
      span: (first: 2024, last: 2024),
    );
    expect(find.byType(RangeSlider), findsNothing);
    await _pump(tester, const YearRangeSlider(), span: null);
    expect(find.byType(RangeSlider), findsNothing);
  });

  testWidgets('dragging back to the full span clears the date filter', (
    tester,
  ) async {
    final c = await _pump(tester, const YearRangeSlider());
    c.read(connectionsFilterProvider.notifier).state = DiveFilterState(
      startDate: DateTime(2021),
      endDate: DateTime(2022, 12, 31),
    );
    await tester.pump();
    tester.widget<RangeSlider>(find.byType(RangeSlider)).onChangeEnd!(
      const RangeValues(2019, 2024),
    );
    await tester.pump();
    final f = c.read(connectionsFilterProvider);
    expect(f.startDate, isNull);
    expect(f.endDate, isNull);
    expect(f.hasActiveFilters, isFalse);
  });
  testWidgets('the slider has a play button that moves the thumbs', (
    tester,
  ) async {
    final c = await _pump(tester, const YearRangeSlider());
    await tester.tap(find.byKey(const ValueKey('year-play-button')));
    await tester.pump();
    final slider = tester.widget<RangeSlider>(find.byType(RangeSlider));
    expect(slider.values, const RangeValues(2019, 2019));
    c.read(yearPlayProvider.notifier).pause();
  });
  testWidgets('starting a drag pauses play at once', (tester) async {
    final c = await _pump(tester, const YearRangeSlider());
    c.read(yearPlayProvider.notifier).play();
    await tester.pump();
    expect(c.read(yearPlayProvider), isNotNull);
    tester.widget<RangeSlider>(find.byType(RangeSlider)).onChangeStart!(
      const RangeValues(2019, 2019),
    );
    await tester.pump();
    expect(c.read(yearPlayProvider), isNull);
  });
}
