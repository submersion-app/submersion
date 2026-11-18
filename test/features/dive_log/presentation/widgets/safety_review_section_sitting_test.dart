import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/providers/safety_review_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_safety_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_review_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/l10n_test_helpers.dart';

/// The Safety review card under the dive's lock (issue #4527, plan 6).
void main() {
  final now = DateTime.utc(2026, 7, 16);
  final dive = Dive(id: 'dive-1', dateTime: now);
  final rapid = SafetyFinding(
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
  final review = SafetyReview(
    diveId: 'dive-1',
    engineVersion: 1,
    reviewedAt: now,
    findings: [rapid],
  );

  Future<RecordEditController<Dive>> pump(
    WidgetTester tester, {
    bool unlocked = false,
    bool open = false,
  }) async {
    final controller = RecordEditController<Dive>(onSave: (_) async {});
    addTearDown(controller.dispose);
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          safetyReviewProvider('dive-1').overrideWith((ref) async => review),
        ],
        child: localizedMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return SingleChildScrollView(
                  child: RecordEditScope<Dive>(
                    controller: controller,
                    child: ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) => SafetyReviewSection(
                        diveId: 'dive-1',
                        editing: open ? controller.session : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (unlocked) {
      controller.unlock(dive);
      holdSafetyDismissals(controller.session!, container.read);
      await tester.pumpAndSettle();
    }
    return controller;
  }

  testWidgets('locked: no dismiss, no restore, no Dismiss all', (tester) async {
    await pump(tester);
    expect(find.textContaining('Ascent exceeded'), findsOneWidget);
    expect(find.byTooltip('Dismiss'), findsNothing);
    expect(find.text('Dismiss all'), findsNothing);
  });

  testWidgets('open: Dismiss all holds every visible finding, shown '
      'dismissed', (tester) async {
    final c2 = await pump(tester, unlocked: true, open: true);
    expect(find.text('Dismiss all'), findsOneWidget);
    await tester.tap(find.text('Dismiss all'));
    await tester.pumpAndSettle();

    expect(c2.session!.changedCardIds, {'safetyReview'});
    expect(sittingDismissals(c2.session!), {'f1': true});
    expect(find.textContaining('Ascent exceeded'), findsNothing);
  });

  testWidgets("closed in a sitting: read only, with the sitting's "
      'dismissals', (tester) async {
    final c = await pump(tester, unlocked: true);
    setFindingDismissed(c.session!, rapid, dismissed: true);
    await tester.pumpAndSettle();

    expect(find.textContaining('Ascent exceeded'), findsNothing);
    expect(find.text('Dismiss all'), findsNothing);
    expect(find.text('Restore all'), findsNothing);
  });

  testWidgets('closed in a sitting: a dismissed finding shown offers no '
      'restore', (tester) async {
    final c = await pump(tester, unlocked: true);
    setFindingDismissed(c.session!, rapid, dismissed: true);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show 1 dismissed'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ascent exceeded'), findsOneWidget);
    expect(find.byTooltip('Restore'), findsNothing);
  });
}
