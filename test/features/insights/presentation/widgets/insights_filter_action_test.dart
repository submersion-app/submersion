import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart'
    show diveFilterProvider;
import 'package:submersion/features/dive_log/presentation/widgets/refine/refine_panel.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/widgets/insights_filter_action.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpAction(
    WidgetTester tester, {
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          insightsFilterProvider.overrideWith((ref) => filter),
          diveFilterProvider.overrideWith(
            (ref) => const DiveFilterState(minDepth: 30),
          ),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: AppBar(actions: const [InsightsFilterAction()]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders an unbadged filter icon when no filter is active', (
    tester,
  ) async {
    await pumpAction(tester);

    expect(
      find.byKey(const ValueKey('insights-filter-action')),
      findsOneWidget,
    );
    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isFalse);
  });

  testWidgets('badges the icon when a filter is active', (tester) async {
    await pumpAction(
      tester,
      filter: DiveFilterState(startDate: DateTime.utc(2024, 1, 1)),
    );

    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isTrue);
  });

  testWidgets('tapping it opens the Refine panel', (tester) async {
    await pumpAction(tester);

    await tester.tap(find.byKey(const ValueKey('insights-filter-action')));
    await tester.pumpAndSettle();

    expect(find.byType(RefinePanel), findsOneWidget);
  });

  // Review Focus 4: Insights writes its own filter, never the dive list's,
  // and stays where it is.
  testWidgets('Show writes the Insights filter only', (tester) async {
    await pumpAction(
      tester,
      filter: DiveFilterState(startDate: DateTime.utc(2024, 1, 1)),
    );
    await tester.tap(find.byKey(const ValueKey('insights-filter-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kRefineClearAllKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kRefineApplyKey));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );
    expect(container.read(insightsFilterProvider), const DiveFilterState());
    expect(
      container.read(diveFilterProvider),
      const DiveFilterState(minDepth: 30),
    );
    expect(
      find.byKey(const ValueKey('insights-filter-action')),
      findsOneWidget,
    );
  });
}
