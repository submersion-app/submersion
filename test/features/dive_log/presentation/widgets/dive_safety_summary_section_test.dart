import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_safety_summary_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_review_section.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/features/safety/presentation/providers/incident_providers.dart';
import 'package:submersion/features/safety/presentation/widgets/linked_incidents_row.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_providers.dart';

// The review and the incidents chip each collapse independently, so the
// section that groups them must decide -- before either half builds --
// whether the pair has anything to show, and which half owns the gap above
// it. https://github.com/submersion-app/submersion/pull/1477 (Copilot review)
void main() {
  final now = DateTime.utc(2026, 7, 16);

  SafetyReview reviewWith(List<SafetyFinding> findings) => SafetyReview(
    diveId: 'dive-1',
    engineVersion: 1,
    reviewedAt: now,
    findings: findings,
  );

  SafetyFinding rapidAscent() => SafetyFinding(
    id: 'f1',
    diveId: 'dive-1',
    ruleId: SafetyRuleId.rapidAscent,
    severity: SafetySeverity.significant,
    startTimestamp: 1500,
    endTimestamp: 1540,
    value: 14.2,
    engineVersion: 1,
    createdAt: now,
  );

  Incident incident() => Incident(
    id: 'i1',
    occurredAt: now,
    category: IncidentCategory.gasSupply,
    severity: IncidentSeverity.moderate,
    narrative: 'Free-flow at 18 m.',
    createdAt: now,
    updatedAt: now,
    diveId: 'dive-1',
  );

  Future<void> pump(
    WidgetTester tester, {
    SafetyReview? review,
    List<Incident> incidents = const [],
    bool hasProfile = true,
    double topGap = 24,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          safetyReviewProvider('dive-1').overrideWith((ref) async => review),
          incidentsForDiveProvider(
            'dive-1',
          ).overrideWith((ref) async => incidents),
        ],
        child: localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 100, child: Text('ABOVE')),
                  DiveSafetySummarySection(
                    diveId: 'dive-1',
                    hasProfile: hasProfile,
                    topGap: topGap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('renders nothing when neither half has content', (tester) async {
    await pump(tester, review: null, incidents: const []);

    expect(find.byType(SafetyReviewSection), findsNothing);
    expect(find.byType(LinkedIncidentsRow), findsNothing);
    expect(tester.getSize(find.byType(DiveSafetySummarySection)), Size.zero);
  });

  testWidgets('the review alone gets the full top gap', (tester) async {
    await pump(
      tester,
      review: reviewWith([rapidAscent()]),
      incidents: const [],
    );

    expect(find.byType(SafetyReviewSection), findsOneWidget);
    expect(find.byType(LinkedIncidentsRow), findsNothing);
    final above = tester.getBottomLeft(find.text('ABOVE')).dy;
    final review = tester.getTopLeft(find.byType(SafetyReviewSection)).dy;
    expect(review - above, 24);
  });

  // The bug the fix targets: without it, the chip only carried its own
  // internal 12px, not the standard section gap.
  testWidgets('the incidents chip alone gets the full top gap', (tester) async {
    await pump(tester, review: null, incidents: [incident()]);

    expect(find.byType(SafetyReviewSection), findsNothing);
    expect(find.byType(LinkedIncidentsRow), findsOneWidget);
    final above = tester.getBottomLeft(find.text('ABOVE')).dy;
    final chip = tester.getTopLeft(find.byType(LinkedIncidentsRow)).dy;
    expect(chip - above, 24);
  });

  testWidgets(
    'with both, the review keeps the gap and the chip groups under it',
    (tester) async {
      await pump(
        tester,
        review: reviewWith([rapidAscent()]),
        incidents: [incident()],
      );

      final above = tester.getBottomLeft(find.text('ABOVE')).dy;
      final review = tester.getTopLeft(find.byType(SafetyReviewSection)).dy;
      expect(review - above, 24);

      final reviewBottom = tester
          .getBottomLeft(find.byType(SafetyReviewSection))
          .dy;
      final chip = tester.getTopLeft(find.byType(LinkedIncidentsRow)).dy;
      expect(chip - reviewBottom, 12);
    },
  );

  // A gauge or manually-logged dive has no profile to compute findings from;
  // the review never renders for one, but a linked incident still should.
  testWidgets('without a profile, only the incidents chip can render', (
    tester,
  ) async {
    await pump(
      tester,
      review: reviewWith([rapidAscent()]),
      incidents: [incident()],
      hasProfile: false,
    );

    expect(find.byType(SafetyReviewSection), findsNothing);
    expect(find.byType(LinkedIncidentsRow), findsOneWidget);
    final above = tester.getBottomLeft(find.text('ABOVE')).dy;
    final chip = tester.getTopLeft(find.byType(LinkedIncidentsRow)).dy;
    expect(chip - above, 24);
  });

  testWidgets('a zero top gap (list layout) is honored', (tester) async {
    await pump(
      tester,
      review: reviewWith([rapidAscent()]),
      incidents: const [],
      topGap: 0,
    );

    final above = tester.getBottomLeft(find.text('ABOVE')).dy;
    final review = tester.getTopLeft(find.byType(SafetyReviewSection)).dy;
    expect(review - above, 0);
  });
}
