import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
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

  testWidgets('a screen reader hears that the dive is planned', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overrides(),
        child: detailedTile(_summary(isPlanned: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('Planned')), findsWidgets);
    handle.dispose();
  });

  testWidgets('the detailed tile shows no number badge when planned', (
    tester,
  ) async {
    // The list passes its position when a dive has no number, so an
    // unnumbered planned dive would wear a number that belongs to another
    // dive. The icon stands in for the badge instead.
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overrides(),
        child: detailedTile(_summary(isPlanned: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('#'), findsNothing);
    expect(find.byIcon(Icons.event_available_outlined), findsOneWidget);
  });

  testWidgets('the detailed tile keeps the badge for a logged dive', (
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
    expect(find.text('#7'), findsOneWidget);
  });

  testWidgets('the compact tile shows no number badge when planned', (
    tester,
  ) async {
    final summary = _summary(isPlanned: true);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overrides(),
        child: CompactDiveListTile(
          diveId: summary.id,
          diveNumber: summary.diveNumber ?? 3,
          dateTime: summary.dateTime,
          siteName: summary.siteName,
          maxDepth: summary.maxDepth,
          duration: summary.bottomTime,
          summary: summary,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('#'), findsNothing);
    expect(find.byIcon(Icons.event_available_outlined), findsOneWidget);
  });

  testWidgets('a screen reader hears a planned dive without a number', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overrides(),
        child: detailedTile(_summary(isPlanned: true)),
      ),
    );
    await tester.pumpAndSettle();
    // The node merges its children's labels, so match the part the tile
    // itself contributes and check no dive number reaches the reader.
    expect(
      find.bySemanticsLabel(RegExp('Planned dive at Blue Hole')),
      findsWidgets,
    );
    expect(find.bySemanticsLabel(RegExp(r'Dive \d+ at')), findsNothing);
    handle.dispose();
  });
}
