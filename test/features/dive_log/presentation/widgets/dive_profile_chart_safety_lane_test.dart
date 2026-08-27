import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_findings_overlay.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  final profile = List.generate(
    10,
    (i) => DiveProfilePoint(
      timestamp: i * 30,
      depth: i < 5 ? i * 3.0 : (10 - i) * 3.0,
    ),
  );

  SafetyFinding finding(String id, {required int start, int? end}) {
    return SafetyFinding(
      id: id,
      diveId: 'd1',
      ruleId: SafetyRuleId.rapidAscent,
      severity: SafetySeverity.caution,
      startTimestamp: start,
      endTimestamp: end,
      value: 14,
      engineVersion: 1,
      createdAt: DateTime(2026),
    );
  }

  Future<void> pumpChart(
    WidgetTester tester, {
    List<SafetyFinding>? safetyFindings,
    String? selectedId,
    void Function(SafetyFinding)? onTap,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: DiveProfileChart(
                profile: profile,
                safetyFindings: safetyFindings,
                selectedSafetyFindingId: selectedId,
                onSafetyFindingTap:
                    onTap ?? (safetyFindings != null ? (_) {} : null),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no findings renders no lane overlay', (tester) async {
    await pumpChart(tester);
    expect(find.byType(SafetyFindingsOverlay), findsNothing);
  });

  testWidgets('findings render the lane overlay with chips', (tester) async {
    await pumpChart(
      tester,
      safetyFindings: [finding('a', start: 60, end: 120)],
    );
    expect(find.byType(SafetyFindingsOverlay), findsOneWidget);
    expect(find.byKey(const ValueKey('safetyLaneChip-0')), findsOneWidget);
  });

  testWidgets('chip tap reaches the chart callback', (tester) async {
    SafetyFinding? tapped;
    await pumpChart(
      tester,
      safetyFindings: [finding('a', start: 60, end: 120)],
      onTap: (f) => tapped = f,
    );
    await tester.tap(find.byKey(const ValueKey('safetyLaneChip-0')));
    // Settle past the chart's double-tap window so its recognizer's timer
    // resolves before the test tears the tree down.
    await tester.pumpAndSettle();
    expect(tapped?.id, 'a');
  });

  testWidgets('selected finding shows the callout above the lane', (
    tester,
  ) async {
    await pumpChart(
      tester,
      safetyFindings: [finding('a', start: 60, end: 120)],
      selectedId: 'a',
    );
    expect(find.byKey(const ValueKey('safetyFindingCallout')), findsOneWidget);
  });
}
