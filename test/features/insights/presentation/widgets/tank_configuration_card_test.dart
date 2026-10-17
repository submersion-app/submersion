import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/tank_configuration/tank_configuration.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/horizontal_category_bar_chart.dart';
import 'package:submersion/features/insights/presentation/widgets/tank_configuration_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

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
}
