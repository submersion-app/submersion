import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/insights/domain/tank_configuration/tank_configuration.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/horizontal_category_bar_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/tank_configuration_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../recording_insights_repository.dart';

/// Issue #3421: the Gas page's tank configuration card.
void main() {
  Future<void> pumpCard(WidgetTester tester, TankConfigurationStats stats) {
    return tester
        .pumpWidget(
          ProviderScope(
            overrides: [
              tankConfigurationStatsProvider.overrideWith((ref) async => stats),
            ],
            child: const MaterialApp(
              locale: Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SingleChildScrollView(child: TankConfigurationCard()),
              ),
            ),
          ),
        )
        .then((_) => tester.pump());
  }

  const tenDives = TankConfigurationStats(
    totalDives: 10,
    baseCounts: {
      TankBaseConfiguration.singleBackmount: 4,
      TankBaseConfiguration.sidemount: 6,
    },
    extraCounts: {},
  );

  testWidgets('shows configuration rows by count with count and percent', (
    tester,
  ) async {
    await pumpCard(tester, tenDives);

    final chart = tester.widget<HorizontalCategoryBarChart>(
      find.byType(HorizontalCategoryBarChart).first,
    );
    expect(chart.data.map((e) => e.label), ['Sidemount', 'Single backmount']);
    expect(find.text('6 · 60%'), findsOneWidget);
    expect(find.text('4 · 40%'), findsOneWidget);
  });

  testWidgets('hides zero rows', (tester) async {
    await pumpCard(tester, tenDives);

    expect(find.text('Rebreather'), findsNothing);
    expect(find.text('No tanks logged'), findsNothing);
  });

  testWidgets('hides the extras group when no dive has an extra', (
    tester,
  ) async {
    await pumpCard(tester, tenDives);

    expect(find.text('Extras'), findsNothing);
    expect(find.byType(HorizontalCategoryBarChart), findsOneWidget);
  });

  testWidgets('shows extras as a share of all dives', (tester) async {
    await pumpCard(
      tester,
      const TankConfigurationStats(
        totalDives: 10,
        baseCounts: {TankBaseConfiguration.sidemount: 10},
        extraCounts: {
          TankConfigurationExtra.stages: 3,
          TankConfigurationExtra.multiGas: 5,
        },
      ),
    );

    expect(find.text('Extras'), findsOneWidget);
    final extras = tester.widget<HorizontalCategoryBarChart>(
      find.byType(HorizontalCategoryBarChart).last,
    );
    expect(extras.data.map((e) => e.label), ['Multi-gas', 'Stage(s)']);
    expect(find.text('3 · 30%'), findsOneWidget);
  });

  testWidgets('both groups draw against all dives', (tester) async {
    await pumpCard(
      tester,
      const TankConfigurationStats(
        totalDives: 10,
        baseCounts: {TankBaseConfiguration.sidemount: 10},
        extraCounts: {TankConfigurationExtra.stages: 3},
      ),
    );

    final charts = tester.widgetList<HorizontalCategoryBarChart>(
      find.byType(HorizontalCategoryBarChart),
    );
    expect(charts.map((c) => c.scaleTo), [10, 10]);
  });

  testWidgets('shows the note', (tester) async {
    await pumpCard(tester, tenDives);

    expect(find.textContaining('Sidemount Left and Right'), findsOneWidget);
  });

  Future<void> pumpWith(
    WidgetTester tester,
    Future<TankConfigurationStats> Function() load,
  ) => tester.pumpWidget(
    ProviderScope(
      overrides: [tankConfigurationStatsProvider.overrideWith((ref) => load())],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: TankConfigurationCard()),
        ),
      ),
    ),
  );

  testWidgets('shows a spinner while loading', (tester) async {
    final pending = Completer<TankConfigurationStats>();
    await pumpWith(tester, () => pending.future);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(TankConfigurationStats.empty);
    await tester.pump();
  });

  testWidgets('a failed load shows the error state', (tester) async {
    await pumpWith(tester, () async => throw StateError('query failed'));
    await tester.pump();

    expect(find.text('Unable to load tank configuration'), findsOneWidget);
  });

  testWidgets('empty stats show the empty state', (tester) async {
    await pumpCard(tester, TankConfigurationStats.empty);

    expect(find.text('No dives to show'), findsOneWidget);
    expect(find.byType(HorizontalCategoryBarChart), findsNothing);
  });

  group('tapping a bar (#3804)', () {
    late RecordingInsightsRepository repository;

    setUp(() => repository = RecordingInsightsRepository());

    Future<ProviderContainer> pumpRouted(
      WidgetTester tester,
      TankConfigurationStats stats, {
      DiveFilterState insightsFilter = const DiveFilterState(),
    }) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/insights',
        routes: [
          GoRoute(
            path: '/insights',
            builder: (_, _) => const Scaffold(
              body: SingleChildScrollView(child: TankConfigurationCard()),
            ),
          ),
          GoRoute(path: '/dives', builder: (_, _) => const Text('dive list')),
        ],
      );
      await tester.pumpWidget(
        testAppRouter(
          router: router,
          overrides: [
            ...await getBaseOverrides(),
            insightsFilterProvider.overrideWith((ref) => insightsFilter),
            insightsRepositoryProvider.overrideWithValue(repository),
            tankConfigurationStatsProvider.overrideWith((ref) async => stats),
          ],
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
        tester.element(find.byType(TankConfigurationCard)),
      );
    }

    ConditionNode field(String key, QueryValue value) =>
        ConditionNode(FieldPath([key]), QueryOp.eq, value);

    // The count sort puts Sidemount above Single backmount, the reverse of
    // the stats' own order, so the row index alone says nothing.
    testWidgets('a bar opens the configuration it shows after the sort', (
      tester,
    ) async {
      final container = await pumpRouted(
        tester,
        tenDives,
        insightsFilter: const DiveFilterState(minDepth: 18),
      );

      await tester.tap(find.text('Single backmount'));
      await tester.pumpAndSettle();

      expect(find.text('dive list'), findsOneWidget);
      expect(repository.lastFilter?.minDepth, 18);
      expect(
        repository.lastFilter?.query,
        field('tankConfig', const EnumValue('singleBackmount')),
      );
      expect(
        container.read(diveFilterProvider).diveIdsLabel,
        'Tank configuration: Single backmount',
      );
    });

    testWidgets('an extra opens that extra', (tester) async {
      final container = await pumpRouted(
        tester,
        const TankConfigurationStats(
          totalDives: 10,
          baseCounts: {TankBaseConfiguration.singleBackmount: 10},
          extraCounts: {
            TankConfigurationExtra.stages: 2,
            TankConfigurationExtra.multiGas: 7,
          },
        ),
      );

      await tester.tap(find.text('Stage(s)'));
      await tester.pumpAndSettle();

      expect(
        repository.lastFilter?.query,
        field('stages', const BoolValue(true)),
      );
      expect(container.read(diveFilterProvider).diveIds, ['d1']);
    });
  });
}
