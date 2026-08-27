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

  group('finding selection', () {
    SafetyFinding secondFinding() => SafetyFinding(
      id: 'f2',
      diveId: 'dive-1',
      ruleId: SafetyRuleId.missedDecoStop,
      severity: SafetySeverity.caution,
      startTimestamp: 600,
      endTimestamp: 700,
      value: 2.0,
      engineVersion: 1,
      createdAt: now,
    );

    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(
          tester.element(find.byType(SafetyReviewSection)),
        );

    Future<void> pumpSelectable(
      WidgetTester tester,
      SafetyReview review, {
      ScrollController? controller,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            safetyReviewProvider('dive-1').overrideWith((ref) async => review),
            safetyFindingsRepositoryProvider.overrideWithValue(
              _RecordingSafetyRepo(),
            ),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                controller: controller,
                child: const Column(
                  children: [
                    SizedBox(height: 2000),
                    SafetyReviewSection(diveId: 'dive-1'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('tapping a finding selects it', (tester) async {
      await pumpSelectable(tester, reviewWith([rapidAscent()]));

      await tester.scrollUntilVisible(
        find.textContaining('Ascent exceeded'),
        400,
      );
      await tester.tap(find.textContaining('Ascent exceeded'));
      await tester.pumpAndSettle();

      final selected = containerOf(
        tester,
      ).read(selectedSafetyFindingProvider('dive-1'));
      expect(selected?.id, 'f1');
    });

    testWidgets('tapping the selected finding clears the selection', (
      tester,
    ) async {
      await pumpSelectable(tester, reviewWith([rapidAscent()]));

      await tester.scrollUntilVisible(
        find.textContaining('Ascent exceeded'),
        400,
      );
      await tester.tap(find.textContaining('Ascent exceeded'));
      await tester.pumpAndSettle();
      // Selecting scrolled the view back to the top; scroll down again to
      // reach the tile for the second tap.
      await tester.scrollUntilVisible(
        find.textContaining('Ascent exceeded'),
        400,
      );
      await tester.tap(find.textContaining('Ascent exceeded'));
      await tester.pumpAndSettle();

      expect(
        containerOf(tester).read(selectedSafetyFindingProvider('dive-1')),
        isNull,
      );
    });

    testWidgets('tapping a different finding replaces the selection', (
      tester,
    ) async {
      await pumpSelectable(
        tester,
        reviewWith([rapidAscent(), secondFinding()]),
      );

      await tester.scrollUntilVisible(
        find.textContaining('Ascent exceeded'),
        400,
      );
      await tester.tap(find.textContaining('Ascent exceeded'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.textContaining('ceiling'), 400);
      await tester.tap(find.textContaining('ceiling'));
      await tester.pumpAndSettle();

      final selected = containerOf(
        tester,
      ).read(selectedSafetyFindingProvider('dive-1'));
      expect(selected?.id, 'f2');
    });

    testWidgets('selecting scrolls the page toward the chart (offset 0)', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await pumpSelectable(
        tester,
        reviewWith([rapidAscent()]),
        controller: controller,
      );

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      await tester.tap(find.textContaining('Ascent exceeded'));
      await tester.pumpAndSettle();

      expect(controller.offset, 0);
    });

    testWidgets('dismissing the selected finding clears the selection', (
      tester,
    ) async {
      await pumpSelectable(tester, reviewWith([rapidAscent()]));

      await tester.scrollUntilVisible(
        find.textContaining('Ascent exceeded'),
        400,
      );
      await tester.tap(find.textContaining('Ascent exceeded'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byIcon(Icons.close), 400);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(
        containerOf(tester).read(selectedSafetyFindingProvider('dive-1')),
        isNull,
      );
    });

    testWidgets('a finding without timestamps is not tappable', (tester) async {
      await pumpSelectable(
        tester,
        reviewWith([
          SafetyFinding(
            id: 'f-no-time',
            diveId: 'dive-1',
            ruleId: SafetyRuleId.sawtoothProfile,
            severity: SafetySeverity.info,
            startTimestamp: null,
            endTimestamp: null,
            value: 4.0,
            engineVersion: 1,
            createdAt: now,
          ),
        ]),
      );

      await tester.scrollUntilVisible(find.byType(ListTile), 400);
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(
        containerOf(tester).read(selectedSafetyFindingProvider('dive-1')),
        isNull,
      );
    });
  });

  group('bulk dismiss', () {
    Future<_RecordingSafetyRepo> pumpBulk(
      WidgetTester tester,
      SafetyReview review, {
      AppSettings? settings,
    }) async {
      final repo = _RecordingSafetyRepo();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(
              (ref) => MockSettingsNotifier(settings),
            ),
            safetyFindingsRepositoryProvider.overrideWithValue(repo),
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
      return repo;
    }

    testWidgets('dismiss all sends one bulk call for the dive', (tester) async {
      final repo = await pumpBulk(
        tester,
        reviewWith([
          rapidAscent(),
          finding(
            SafetyRuleId.sawtoothProfile,
            severity: SafetySeverity.info,
            value: 4,
            id: 'f2',
          ),
        ]),
      );

      await tester.tap(find.text('Dismiss all'));
      await tester.pumpAndSettle();

      expect(repo.bulkCalls, hasLength(1));
      expect(repo.bulkCalls.single.diveIds, ['dive-1']);
      expect(repo.bulkCalls.single.dismissed, isTrue);
      expect(
        repo.calls,
        isEmpty,
        reason: 'one bulk write, not one call per finding',
      );
    });

    testWidgets('offers restore all once nothing is active', (tester) async {
      final repo = await pumpBulk(
        tester,
        reviewWith([rapidAscent(dismissedAt: now)]),
      );

      expect(find.text('Dismiss all'), findsNothing);
      await tester.tap(find.text('Restore all'));
      await tester.pumpAndSettle();

      expect(repo.bulkCalls.single.dismissed, isFalse);
    });

    testWidgets('passes only the rules the diver has enabled', (tester) async {
      final repo = await pumpBulk(
        tester,
        reviewWith([rapidAscent()]),
        settings: const AppSettings(
          safetyReviewDisabledRules: {'sawtoothProfile'},
        ),
      );

      await tester.tap(find.text('Dismiss all'));
      await tester.pumpAndSettle();

      final ruleIds = repo.bulkCalls.single.ruleIds;
      expect(ruleIds, contains(SafetyRuleId.rapidAscent.dbValue));
      expect(
        ruleIds,
        isNot(contains(SafetyRuleId.sawtoothProfile.dbValue)),
        reason: 'a rule hidden in settings must not be dismissed unseen',
      );
    });

    testWidgets('dismiss all clears the chart highlight', (tester) async {
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

      await tester.tap(find.textContaining('Ascent exceeded'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SafetyReviewSection)),
      );
      expect(
        container.read(selectedSafetyFindingProvider('dive-1')),
        isNotNull,
      );

      await tester.tap(find.text('Dismiss all'));
      await tester.pumpAndSettle();

      expect(
        container.read(selectedSafetyFindingProvider('dive-1')),
        isNull,
        reason: 'a dismissed finding must not stay highlighted on the chart',
      );
    });

    testWidgets('the footer fits a narrow screen in a long locale', (
      tester,
    ) async {
      // The state the primary action lands in: everything dismissed, so the
      // "show dismissed" toggle and "restore all" render side by side. German
      // labels are roughly twice the width of the English ones, which is why
      // an English-only test would not catch a row overflow here.
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            safetyFindingsRepositoryProvider.overrideWithValue(
              _RecordingSafetyRepo(),
            ),
            safetyReviewProvider('dive-1').overrideWith(
              (ref) async => reviewWith([rapidAscent(dismissedAt: now)]),
            ),
          ],
          child: localizedMaterialApp(
            locale: const Locale('de'),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: SafetyReviewSection(diveId: 'dive-1'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alle wiederherstellen'), findsOneWidget);
      expect(find.textContaining('Ausgeblendete anzeigen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// Records dismiss calls without touching a database.
class _RecordingSafetyRepo extends SafetyFindingsRepository {
  final List<(String, bool)> calls = [];
  final List<({List<String> diveIds, bool dismissed, Set<String> ruleIds})>
  bulkCalls = [];

  @override
  Future<void> setDismissed({
    required String findingId,
    required bool dismissed,
    required DateTime now,
  }) async {
    calls.add((findingId, dismissed));
  }

  @override
  Future<int> setDismissedForDives({
    required List<String> diveIds,
    required bool dismissed,
    required Set<String> enabledRuleIds,
    required DateTime now,
    int chunkSize = SafetyFindingsRepository.dismissChunkSize,
  }) async {
    bulkCalls.add((
      diveIds: diveIds,
      dismissed: dismissed,
      ruleIds: enabledRuleIds,
    ));
    return diveIds.length;
  }
}
