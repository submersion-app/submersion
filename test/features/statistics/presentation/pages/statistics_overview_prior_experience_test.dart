import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_overview_page.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

DiveStatistics _stats({int totalDives = 312}) => DiveStatistics(
  totalDives: totalDives,
  totalTimeSeconds: totalDives == 0 ? 0 : 43 * 3600,
  maxDepth: totalDives == 0 ? 0 : 30,
  avgMaxDepth: totalDives == 0 ? 0 : 18,
  totalSites: totalDives == 0 ? 0 : 5,
  firstDiveDate: totalDives == 0 ? null : DateTime(2020),
);

Diver _diver({int? count, int? seconds, DateTime? since}) => Diver(
  id: 'd1',
  name: 'A',
  priorDiveCount: count,
  priorDiveTimeSeconds: seconds,
  divingSince: since,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<void> _pump(
  WidgetTester tester,
  Diver diver, {
  DiveStatistics? stats,
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        diveStatisticsProvider.overrideWith((ref) async => stats ?? _stats()),
        filteredDiveStatisticsProvider.overrideWith(
          (ref) async => stats ?? _stats(),
        ),
        currentDiverProvider.overrideWith((ref) async => diver),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StatisticsOverviewPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows combined total + breakdown + diving since', (
    tester,
  ) async {
    await _pump(
      tester,
      _diver(count: 1200, seconds: 1150 * 3600, since: DateTime(1990)),
    );
    expect(find.textContaining('1512'), findsWidgets);
    expect(find.textContaining('logged'), findsWidgets);
    expect(find.textContaining('1990'), findsOneWidget);
  });

  testWidgets('no prior experience -> logged-only, no breakdown', (
    tester,
  ) async {
    await _pump(tester, _diver());
    expect(find.text('312'), findsOneWidget);
    expect(find.textContaining('prior'), findsNothing);
    expect(find.textContaining('Diving since'), findsNothing);
  });

  testWidgets('prior experience with zero logged dives shows career total', (
    tester,
  ) async {
    await _pump(
      tester,
      _diver(count: 1200, seconds: 1150 * 3600, since: DateTime(1990)),
      stats: _stats(totalDives: 0),
    );
    // Not the empty state: the combined career total (0 logged + 1200) shows.
    expect(find.text('1200'), findsOneWidget);
    expect(find.textContaining('1990'), findsOneWidget);
  });

  testWidgets('zero logged + diver loading shows a loader, not empty state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveStatisticsProvider.overrideWith(
            (ref) async => _stats(totalDives: 0),
          ),
          filteredDiveStatisticsProvider.overrideWith(
            (ref) async => _stats(totalDives: 0),
          ),
          currentDiverProvider.overrideWith((ref) async {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            return _diver(count: 1200, since: DateTime(1990));
          }),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StatisticsOverviewPage(),
        ),
      ),
    );
    await tester.pump(); // resolve the stats future
    await tester
        .pump(); // rebuild _OverviewBody while the diver is still loading
    // The guard shows a loader rather than flashing the empty state, so a diver
    // with prior experience but no logged dives never loses their career total.
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    // Once the diver resolves, the career total renders.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('1200'), findsOneWidget);
  });
}
