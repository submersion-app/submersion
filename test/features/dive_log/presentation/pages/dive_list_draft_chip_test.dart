import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_dive_list_tile.dart';
import 'package:submersion/features/dive_log/presentation/widgets/unfilled_dive_chip.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

class _TestCardConfigNotifier extends CardViewConfigNotifier {
  _TestCardConfigNotifier(CardViewConfig config)
    : super.withMode(ListViewMode.detailed) {
    state = config;
  }
}

/// A draft (issue #637) waits for its dive computer readings: the list marks
/// it "Waiting for download", or "In the water" while it is open, and never
/// shows a number for it.
DiveSummary _draft({bool open = false}) => DiveSummary(
  id: 'd1',
  dateTime: DateTime(2026, 3, 15, 10),
  entryTime: DateTime(2026, 3, 15, 10),
  siteName: 'Blue Hole',
  isDraft: true,
  isOpenDraft: open,
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
    diveNumber: summary.diveNumber ?? 4,
    dateTime: summary.dateTime,
    siteName: summary.siteName,
    maxDepth: summary.maxDepth,
    duration: summary.bottomTime,
    summary: summary,
  );

  Widget compactTile(DiveSummary summary) => CompactDiveListTile(
    diveId: summary.id,
    diveNumber: summary.diveNumber ?? 4,
    dateTime: summary.dateTime,
    siteName: summary.siteName,
    maxDepth: summary.maxDepth,
    duration: summary.bottomTime,
    summary: summary,
  );

  Future<void> pump(WidgetTester tester, Widget tile) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await overrides(),
        child: tile,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a closed draft shows Waiting for download', (tester) async {
    await pump(tester, detailedTile(_draft()));

    expect(find.byType(UnfilledDiveChip), findsOneWidget);
    expect(find.text('Waiting for download'), findsOneWidget);
    expect(find.text('Planned'), findsNothing);
  });

  testWidgets('an open draft shows In the water', (tester) async {
    await pump(tester, detailedTile(_draft(open: true)));

    expect(find.text('In the water'), findsOneWidget);
    expect(find.text('Waiting for download'), findsNothing);
  });

  testWidgets('the detailed tile shows the draft icon, not a number', (
    tester,
  ) async {
    await pump(tester, detailedTile(_draft()));

    expect(find.textContaining('#'), findsNothing);
    expect(find.byIcon(Icons.hourglass_top_outlined), findsOneWidget);
  });

  testWidgets('the compact tile marks a draft and shows no number', (
    tester,
  ) async {
    await pump(tester, compactTile(_draft()));

    expect(find.text('Waiting for download'), findsOneWidget);
    expect(find.textContaining('#'), findsNothing);
    expect(find.byIcon(Icons.hourglass_top_outlined), findsOneWidget);
  });

  testWidgets('a screen reader hears a draft without a number', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, detailedTile(_draft()));

    expect(
      find.bySemanticsLabel(RegExp('Draft dive at Blue Hole')),
      findsWidgets,
    );
    expect(find.bySemanticsLabel(RegExp(r'Dive \d+ at')), findsNothing);
    handle.dispose();
  });
}
