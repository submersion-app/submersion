import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/connections/domain/entities/connection_graph.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/graph_selection.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/providers/connections_filter_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_lens_provider.dart';
import 'package:submersion/features/connections/presentation/providers/connections_providers.dart';
import 'package:submersion/features/connections/presentation/providers/connections_selection_provider.dart';
import 'package:submersion/features/connections/presentation/widgets/connections_filter_bar.dart';
import 'package:submersion/features/connections/presentation/widgets/lens_chip_row.dart';
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
  testWidgets('lens chips switch the lens and clear focus and selection', (
    tester,
  ) async {
    final c = await _pump(tester, const LensChipRow());
    c.read(connectionsFocusProvider.notifier).state = const NodeRef(
      ConnectionKind.buddy,
      'x',
    );
    c.read(connectionsSelectionProvider.notifier).state = const NodeSelection(
      NodeRef(ConnectionKind.buddy, 'x'),
    );
    expect(find.text('Dive circle'), findsOneWidget);
    await tester.tap(find.text('Who dives where'));
    await tester.pump();
    expect(c.read(connectionsLensProvider).lensId, 'where');
    expect(c.read(connectionsFocusProvider), isNull);
    expect(c.read(connectionsSelectionProvider), isNull);
  });

  testWidgets('the filter bar is hidden without a filter and clears with one', (
    tester,
  ) async {
    final c = await _pump(
      tester,
      Consumer(
        builder: (context, ref, _) {
          ref.watch(connectionsFilterProvider);
          return ConnectionsFilterBar(
            graph: AsyncValue.data(
              ConnectionGraph.empty.copyWith(hiddenNodeCount: 0),
            ),
          );
        },
      ),
    );
    expect(find.byKey(const ValueKey('connections-filter-bar')), findsNothing);
    c.read(connectionsFilterProvider.notifier).state = const DiveFilterState(
      siteId: 's1',
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('connections-filter-bar')),
      findsOneWidget,
    );
    expect(find.text('0 nodes, 0 connections'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear filter'));
    await tester.pump();
    expect(c.read(connectionsFilterProvider).hasActiveFilters, isFalse);
  });

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
}
