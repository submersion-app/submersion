import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_dive_list_tile.dart';
import 'package:submersion/features/dive_log/presentation/widgets/planned_dive_chip.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

class _TestCardConfigNotifier extends CardViewConfigNotifier {
  _TestCardConfigNotifier(CardViewConfig config)
    : super.withMode(ListViewMode.detailed) {
    state = config;
  }
}

DiveSummary _summary({required bool isPlanned}) => DiveSummary(
  id: 'd1',
  diveNumber: isPlanned ? null : 7,
  dateTime: DateTime(2026, 3, 15),
  siteName: 'Blue Hole',
  maxDepth: 30.0,
  bottomTime: const Duration(minutes: 40),
  runtime: const Duration(minutes: 45),
  isPlanned: isPlanned,
  sortTimestamp: 0,
);

void main() {
  Future<List<dynamic>> overrides() async => [
    ...await getBaseOverrides(),
    detailedCardConfigProvider.overrideWith(
      (ref) => _TestCardConfigNotifier(CardViewConfig.defaultDetailed()),
    ),
  ];

  Widget detailedTile(DiveSummary summary) => DiveListTile(
    diveId: summary.id,
    diveNumber: summary.diveNumber ?? 0,
    dateTime: summary.dateTime,
    siteName: summary.siteName,
    maxDepth: summary.maxDepth,
    duration: summary.bottomTime,
    summary: summary,
  );

  testWidgets('the detailed tile shows Planned for a planned summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overrides(),
        child: detailedTile(_summary(isPlanned: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlannedDiveChip), findsOneWidget);
    expect(find.text('Planned'), findsOneWidget);
  });

  testWidgets('the detailed tile shows no chip for a logged summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overrides(),
        child: detailedTile(_summary(isPlanned: false)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlannedDiveChip), findsNothing);
  });

  testWidgets('the compact tile shows Planned for a planned summary', (
    tester,
  ) async {
    final summary = _summary(isPlanned: true);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overrides(),
        child: CompactDiveListTile(
          diveId: summary.id,
          diveNumber: summary.diveNumber ?? 0,
          dateTime: summary.dateTime,
          siteName: summary.siteName,
          maxDepth: summary.maxDepth,
          duration: summary.bottomTime,
          summary: summary,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlannedDiveChip), findsOneWidget);
  });
}
