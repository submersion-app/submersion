import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_sheet.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_filter_provider.dart';
import 'package:submersion/features/statistics/presentation/widgets/statistics_filter_action.dart';
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
          statisticsFilterProvider.overrideWith((ref) => filter),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: AppBar(actions: const [StatisticsFilterAction()]),
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
      find.byKey(const ValueKey('statistics-filter-action')),
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

  testWidgets('tapping it opens the filter sheet', (tester) async {
    await pumpAction(tester);

    await tester.tap(find.byKey(const ValueKey('statistics-filter-action')));
    await tester.pumpAndSettle();

    expect(find.byType(DiveFilterSheet), findsOneWidget);
  });
}
