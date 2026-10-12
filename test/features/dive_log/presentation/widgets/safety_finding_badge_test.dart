import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_dive_list_tile.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_badge.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

class _TestCardConfigNotifier extends CardViewConfigNotifier {
  _TestCardConfigNotifier(CardViewConfig config)
    : super.withMode(ListViewMode.detailed) {
    state = config;
  }
}

DiveSummary _summary({required int findings}) => DiveSummary(
  id: 'd1',
  diveNumber: 1382,
  dateTime: DateTime(2026, 9, 9, 9, 22),
  siteName: 'Grotta Niedda',
  maxDepth: 31.6,
  runtime: const Duration(minutes: 49),
  safetyFindingCount: findings,
  sortTimestamp: 0,
);

// Issue #3207: the list badge for post-dive safety review findings was a bare
// dot whose tooltip read "1 observation", which divers took for a marine life
// sighting. The badge must say it is a safety review finding.
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
    duration: summary.runtime,
    summary: summary,
  );

  Widget compactTile(DiveSummary summary) => CompactDiveListTile(
    diveId: summary.id,
    diveNumber: summary.diveNumber ?? 0,
    dateTime: summary.dateTime,
    siteName: summary.siteName,
    maxDepth: summary.maxDepth,
    duration: summary.runtime,
    summary: summary,
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      testApp(locale: locale, overrides: await overrides(), child: child),
    );
    await tester.pumpAndSettle();
  }

  String tooltipOf(WidgetTester tester) => tester
      .widget<Tooltip>(
        find.descendant(
          of: find.byType(SafetyFindingBadge),
          matching: find.byType(Tooltip),
        ),
      )
      .message!;

  for (final (name, build) in [
    ('detailed', detailedTile),
    ('compact', compactTile),
  ]) {
    group('$name tile', () {
      testWidgets('names the badge as a safety observation', (tester) async {
        await pump(tester, build(_summary(findings: 1)));

        expect(find.byType(SafetyFindingBadge), findsOneWidget);
        expect(tooltipOf(tester), '1 safety observation');
        expect(
          find.descendant(
            of: find.byType(SafetyFindingBadge),
            matching: find.byIcon(Icons.health_and_safety_outlined),
          ),
          findsOneWidget,
        );
      });

      testWidgets('pluralizes the count', (tester) async {
        await pump(tester, build(_summary(findings: 3)));

        expect(tooltipOf(tester), '3 safety observations');
      });

      testWidgets('is localized', (tester) async {
        await pump(
          tester,
          build(_summary(findings: 1)),
          locale: const Locale('de'),
        );

        expect(tooltipOf(tester), '1 Sicherheitshinweis');
      });

      testWidgets('is absent when the dive has no findings', (tester) async {
        await pump(tester, build(_summary(findings: 0)));

        expect(find.byType(SafetyFindingBadge), findsNothing);
      });
    });
  }
}
