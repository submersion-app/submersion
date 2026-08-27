import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_findings_overlay.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  SafetyFinding finding(
    String id, {
    required int start,
    int? end,
    SafetyRuleId rule = SafetyRuleId.rapidAscent,
  }) {
    return SafetyFinding(
      id: id,
      diveId: 'd1',
      ruleId: rule,
      severity: SafetySeverity.caution,
      startTimestamp: start,
      endTimestamp: end,
      value: 14,
      engineVersion: 1,
      createdAt: DateTime(2026),
    );
  }

  Future<void> pumpOverlay(
    WidgetTester tester, {
    required List<SafetyFinding> findings,
    String? selectedFindingId,
    void Function(SafetyFinding)? onTap,
    void Function(SafetyFinding)? onDismiss,
    void Function(SafetyFinding)? onDetails,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 300,
            child: SafetyFindingsOverlay(
              findings: findings,
              selectedFindingId: selectedFindingId,
              visibleMinSeconds: 0,
              visibleMaxSeconds: 1000,
              insets: (left: 48, top: 0, right: 38, bottom: 96),
              laneHeight: 24,
              laneBottomOffset: 36,
              units: const UnitFormatter(AppSettings()),
              onFindingTap: onTap ?? (_) {},
              onFindingDismiss: onDismiss ?? (_) {},
              onFindingDetails: onDetails,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders one chip per finding', (tester) async {
    await pumpOverlay(
      tester,
      findings: [
        finding('a', start: 100, end: 200),
        finding('b', start: 800, end: 800),
      ],
    );
    expect(find.byKey(const ValueKey('safetyLaneChip-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('safetyLaneChip-1')), findsOneWidget);
  });

  testWidgets('tapping a chip reports its finding', (tester) async {
    SafetyFinding? tapped;
    await pumpOverlay(
      tester,
      findings: [finding('a', start: 100, end: 200)],
      onTap: (f) => tapped = f,
    );
    await tester.tap(find.byKey(const ValueKey('safetyLaneChip-0')));
    await tester.pump();
    expect(tapped?.id, 'a');
  });

  testWidgets('overlapping findings cluster into one chip with a count', (
    tester,
  ) async {
    await pumpOverlay(
      tester,
      findings: [
        finding('a', start: 500, end: 500),
        finding('b', start: 505, end: 505),
      ],
    );
    expect(find.byKey(const ValueKey('safetyLaneChip-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('safetyLaneChip-1')), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('cluster tap cycles: first, next, then toggles last to clear', (
    tester,
  ) async {
    final findings = [
      finding('a', start: 500, end: 500),
      finding('b', start: 505, end: 505),
    ];
    SafetyFinding? tapped;

    await pumpOverlay(tester, findings: findings, onTap: (f) => tapped = f);
    await tester.tap(find.byKey(const ValueKey('safetyLaneChip-0')));
    expect(tapped?.id, 'a');

    await pumpOverlay(
      tester,
      findings: findings,
      selectedFindingId: 'a',
      onTap: (f) => tapped = f,
    );
    await tester.tap(find.byKey(const ValueKey('safetyLaneChip-0')));
    expect(tapped?.id, 'b');

    await pumpOverlay(
      tester,
      findings: findings,
      selectedFindingId: 'b',
      onTap: (f) => tapped = f,
    );
    await tester.tap(find.byKey(const ValueKey('safetyLaneChip-0')));
    expect(tapped?.id, 'b'); // parent toggle clears
  });

  testWidgets('selection shows the callout with title and actions', (
    tester,
  ) async {
    await pumpOverlay(
      tester,
      findings: [finding('a', start: 100, end: 200)],
      selectedFindingId: 'a',
      onDetails: (_) {},
    );
    expect(find.byKey(const ValueKey('safetyFindingCallout')), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('callout hides the Details link when onFindingDetails is null', (
    tester,
  ) async {
    await pumpOverlay(
      tester,
      findings: [finding('a', start: 100, end: 200)],
      selectedFindingId: 'a',
    );
    expect(find.text('Details'), findsNothing);
  });

  testWidgets('callout actions invoke their callbacks', (tester) async {
    SafetyFinding? cleared;
    SafetyFinding? dismissed;
    SafetyFinding? details;
    await pumpOverlay(
      tester,
      findings: [finding('a', start: 100, end: 200)],
      selectedFindingId: 'a',
      onTap: (f) => cleared = f,
      onDismiss: (f) => dismissed = f,
      onDetails: (f) => details = f,
    );
    await tester.tap(find.text('Details'));
    expect(details?.id, 'a');
    await tester.tap(find.text('Dismiss'));
    expect(dismissed?.id, 'a');
    await tester.tap(find.byIcon(Icons.close));
    expect(cleared?.id, 'a'); // clear = toggle-tap of the selected finding
  });

  testWidgets('no callout when the selected finding is not in the lane', (
    tester,
  ) async {
    await pumpOverlay(
      tester,
      findings: [finding('a', start: 100, end: 200)],
      selectedFindingId: 'gone',
    );
    expect(find.byKey(const ValueKey('safetyFindingCallout')), findsNothing);
  });
}
