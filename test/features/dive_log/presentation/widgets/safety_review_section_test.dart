import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/collapsible_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_review_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/mock_providers.dart';

void main() {
  final now = DateTime.utc(2026, 7, 16);

  SafetyReview reviewWith(List<SafetyFinding> findings) => SafetyReview(
    diveId: 'dive-1',
    engineVersion: 1,
    reviewedAt: now,
    findings: findings,
  );

  SafetyFinding rapidAscent({DateTime? dismissedAt}) => SafetyFinding(
    id: 'f1',
    diveId: 'dive-1',
    ruleId: SafetyRuleId.rapidAscent,
    severity: SafetySeverity.significant,
    startTimestamp: 1500,
    endTimestamp: 1540,
    value: 14.2,
    engineVersion: 1,
    dismissedAt: dismissedAt,
    createdAt: now,
  );

  Future<void> pump(WidgetTester tester, SafetyReview review) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          safetyReviewProvider('dive-1').overrideWith((ref) async => review),
        ],
        child: localizedMaterialApp(
          home: const Scaffold(
            body: SingleChildScrollView(
              child: SafetyReviewSection(diveId: 'dive-1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders a rapid ascent finding', (tester) async {
    await pump(tester, reviewWith([rapidAscent()]));
    expect(find.textContaining('Ascent exceeded'), findsOneWidget);
  });

  testWidgets('renders a neutral placeholder when value is null', (
    tester,
  ) async {
    await pump(
      tester,
      reviewWith([
        SafetyFinding(
          id: 'f-null',
          diveId: 'dive-1',
          ruleId: SafetyRuleId.rapidAscent,
          severity: SafetySeverity.significant,
          startTimestamp: 1500,
          endTimestamp: 1540,
          value: null,
          engineVersion: 1,
          createdAt: now,
        ),
      ]),
    );
    // A missing number must not read as a fabricated "0"; it shows "--" while
    // still preserving the known duration.
    expect(find.textContaining('Ascent exceeded --'), findsOneWidget);
    expect(find.textContaining('exceeded 0'), findsNothing);
  });

  testWidgets('renders nothing when there are no findings', (tester) async {
    await pump(tester, reviewWith(const []));
    expect(find.text('Safety review'), findsNothing);
  });

  testWidgets('dismissed findings are hidden behind a toggle', (tester) async {
    await pump(tester, reviewWith([rapidAscent(dismissedAt: now)]));
    expect(find.textContaining('Ascent exceeded'), findsNothing);
    expect(find.textContaining('dismissed'), findsOneWidget);
  });

  SafetyFinding finding(
    SafetyRuleId rule, {
    required SafetySeverity severity,
    required double value,
    String id = 'f',
    int? start = 100,
    int? end = 160,
    DateTime? dismissedAt,
  }) => SafetyFinding(
    id: id,
    diveId: 'dive-1',
    ruleId: rule,
    severity: severity,
    startTimestamp: start,
    endTimestamp: end,
    value: value,
    engineVersion: 1,
    dismissedAt: dismissedAt,
    createdAt: now,
  );

  testWidgets('renders a title and icon for every rule type', (tester) async {
    await pump(
      tester,
      reviewWith([
        finding(
          SafetyRuleId.missedDecoStop,
          severity: SafetySeverity.significant,
          value: 2.5,
          id: 'a',
        ),
        finding(
          SafetyRuleId.omittedSafetyStop,
          severity: SafetySeverity.info,
          value: 90,
          id: 'b',
        ),
        finding(
          SafetyRuleId.sawtoothProfile,
          severity: SafetySeverity.caution,
          value: 4,
          id: 'c',
        ),
        finding(
          SafetyRuleId.highSurfaceGf,
          severity: SafetySeverity.info,
          value: 82,
          id: 'd',
        ),
      ]),
    );
    // One ListTile per finding; the switch in _titleFor ran for each rule.
    expect(find.byType(ListTile), findsNWidgets(4));
    expect(find.byIcon(Icons.info_outline), findsNWidgets(2));
    expect(find.byIcon(Icons.report_problem_outlined), findsNWidgets(2));
  });

  testWidgets('show-dismissed toggle reveals dismissed findings', (
    tester,
  ) async {
    await pump(
      tester,
      reviewWith([
        rapidAscent(),
        finding(
          SafetyRuleId.sawtoothProfile,
          severity: SafetySeverity.caution,
          value: 4,
          id: 'dismissed',
          dismissedAt: now,
        ),
      ]),
    );
    // Active finding shows; dismissed one hidden behind the toggle.
    expect(find.textContaining('Ascent exceeded'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);

    await tester.tap(find.textContaining('dismissed'));
    await tester.pumpAndSettle();
    // The dismissed tile is now rendered too.
    expect(find.byType(ListTile), findsNWidgets(2));
  });

  testWidgets('tapping dismiss invokes the repository', (tester) async {
    final repo = _RecordingSafetyRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          safetyFindingsRepositoryProvider.overrideWithValue(repo),
          safetyReviewProvider(
            'dive-1',
          ).overrideWith((ref) async => reviewWith([rapidAscent()])),
        ],
        child: localizedMaterialApp(
          home: const Scaffold(
            body: SingleChildScrollView(
              child: SafetyReviewSection(diveId: 'dive-1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(repo.calls, hasLength(1));
    expect(repo.calls.first.$1, 'f1');
    expect(repo.calls.first.$2, isTrue);
  });

  testWidgets('tapping restore on a dismissed finding invokes the repository', (
    tester,
  ) async {
    final repo = _RecordingSafetyRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          safetyFindingsRepositoryProvider.overrideWithValue(repo),
          safetyReviewProvider('dive-1').overrideWith(
            (ref) async => reviewWith([rapidAscent(dismissedAt: now)]),
          ),
        ],
        child: localizedMaterialApp(
          home: const Scaffold(
            body: SingleChildScrollView(
              child: SafetyReviewSection(diveId: 'dive-1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Reveal the dismissed section, then tap its restore (undo) control.
    await tester.tap(find.textContaining('dismissed'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.undo));
    await tester.pumpAndSettle();

    expect(repo.calls, hasLength(1));
    expect(repo.calls.first.$1, 'f1');
    expect(repo.calls.first.$2, isFalse);
  });

  testWidgets('sawtooth with null value falls back to the neutral rule name', (
    tester,
  ) async {
    await pump(
      tester,
      reviewWith([
        SafetyFinding(
          id: 'saw-null',
          diveId: 'dive-1',
          ruleId: SafetyRuleId.sawtoothProfile,
          severity: SafetySeverity.caution,
          startTimestamp: 100,
          endTimestamp: 160,
          value: null,
          engineVersion: 1,
          createdAt: now,
        ),
      ]),
    );
    // With no cycle count there is nothing to interpolate, so the tile shows
    // the neutral rule name rather than "0 repeated ... depth changes".
    expect(find.text('Sawtooth profiles'), findsOneWidget);
  });

  testWidgets('collapse toggle flips the expanded state', (tester) async {
    await pump(tester, reviewWith([rapidAscent()]));
    CollapsibleSection section() =>
        tester.widget<CollapsibleSection>(find.byType(CollapsibleSection));
    expect(section().isExpanded, isTrue);

    await tester.tap(find.text('Safety review'));
    await tester.pumpAndSettle();
    expect(section().isExpanded, isFalse);
  });
}

/// Records [setDismissed] calls without touching a database.
class _RecordingSafetyRepo extends SafetyFindingsRepository {
  final List<(String, bool)> calls = [];

  @override
  Future<void> setDismissed({
    required String findingId,
    required bool dismissed,
    required DateTime now,
  }) async {
    calls.add((findingId, dismissed));
  }
}
