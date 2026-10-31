import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/insights/presentation/widgets/depth_pie_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Issue #3805: the pie draws no slice for an empty bucket, so a slice's
/// index is not its bucket's.
void main() {
  DepthRangeStat range(int min, int count) => DepthRangeStat(
    label: '$min',
    minDepth: min,
    maxDepth: min + 10,
    count: count,
    totalDurationSeconds: 0,
  );

  final distribution = [range(0, 0), range(10, 5), range(20, 5)];

  Future<void> pump(
    WidgetTester tester,
    Future<void> Function(int)? onOpen,
    List<DepthRangeStat> ranges,
  ) async {
    tester.view.physicalSize = const Size(400, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DepthPieCard(
            depthDistribution: ranges,
            fmt: UnitFormatter(const AppSettings(depthUnit: DepthUnit.meters)),
            onOpenBucket: onOpen,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Offset firstSlice(WidgetTester tester) {
    final pie = tester.getRect(find.byType(PieChart));
    return pie.center + const Offset(35, 25);
  }

  testWidgets('a slice opens its own bucket when an earlier one is empty', (
    tester,
  ) async {
    int? opened;
    await pump(tester, (bucket) async => opened = bucket, distribution);

    await tester.tapAt(firstSlice(tester));
    await tester.pumpAndSettle();

    expect(find.textContaining('5 dives'), findsOneWidget);
    await tester.tap(find.text('View dives'));
    await tester.pumpAndSettle();

    expect(opened, 1);
  });

  testWidgets('a legend row opens its own bucket in one tap', (tester) async {
    int? opened;
    await pump(tester, (bucket) async => opened = bucket, distribution);

    await tester.tap(find.byIcon(Icons.chevron_right).last);
    await tester.pumpAndSettle();

    expect(opened, 2);
  });

  testWidgets('new counts clear the mark', (tester) async {
    await pump(tester, (_) async {}, distribution);
    await tester.tapAt(firstSlice(tester));
    await tester.pumpAndSettle();

    await pump(tester, (_) async {}, [range(0, 1), range(10, 5), range(20, 5)]);

    expect(find.text('View dives'), findsNothing);
  });
}
