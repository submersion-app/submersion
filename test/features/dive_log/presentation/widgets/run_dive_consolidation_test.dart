import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/services/profile_alignment.dart';
import 'package:submersion/features/dive_log/presentation/widgets/run_dive_consolidation.dart';

import '../../../../helpers/fake_dive_consolidation_service.dart';
import '../../../../helpers/test_app.dart';

/// Covers `runDiveConsolidation` -- the shared apply/undo/SnackBar wiring
/// behind the multi-select combine dialog's consolidation panel and the data
/// quality inbox's "consolidate duplicate" repair -- directly, without a
/// dialog in front of it.
///
/// The success path is also exercised end-to-end through
/// combine_dives_dialog_test.dart; the undo and failure branches are only
/// reachable here, so this file owns them. (They used to ride along on
/// merge_dive_dialog_test.dart, whose widget was orphaned and removed in
/// #1452.)
const _targetDiveId = 'target-dive';
const _secondaryDiveIds = ['secondary-dive'];

void main() {
  group('runDiveConsolidation', () {
    testWidgets(
      'calls DiveConsolidationService.apply with the target and secondaries',
      (tester) async {
        final service = FakeDiveConsolidationService();

        await _pumpAndRun(tester, service: service);

        expect(service.capturedTargetDiveId, equals(_targetDiveId));
        expect(service.capturedSecondaryDiveIds, equals(_secondaryDiveIds));
      },
    );

    testWidgets('forwards the alignment to apply', (tester) async {
      final service = FakeDiveConsolidationService();

      await _pumpAndRun(
        tester,
        service: service,
        alignment: ConsolidationAlignment.starts,
      );

      expect(service.capturedAlignment, ConsolidationAlignment.starts);
    });

    testWidgets('reports the fold to the caller via onConsolidated', (
      tester,
    ) async {
      var consolidatedCalls = 0;

      await _pumpAndRun(
        tester,
        service: FakeDiveConsolidationService(),
        onConsolidated: () => consolidatedCalls++,
      );

      expect(consolidatedCalls, 1);
    });

    testWidgets('shows an Undo snackbar on success with persist:false and '
        "showCloseIcon:true (this repo's convention for actioned SnackBars)", (
      tester,
    ) async {
      await _pumpAndRun(tester, service: FakeDiveConsolidationService());

      expect(
        find.text('Dive merged as an additional computer.'),
        findsOneWidget,
      );
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.action, isNotNull);
      expect(snackBar.action!.label, equals('Undo'));
      expect(snackBar.persist, isFalse);
      expect(snackBar.showCloseIcon, isTrue);
    });

    testWidgets('tapping Undo rolls back with the outcome snapshot, tells the '
        'caller to refresh again, and confirms', (tester) async {
      final service = FakeDiveConsolidationService();
      var consolidatedCalls = 0;

      await _pumpAndRun(
        tester,
        service: service,
        onConsolidated: () => consolidatedCalls++,
      );

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(service.undoCallCount, 1);
      expect(service.undoneSnapshot, same(service.outcomeSnapshot));
      // The rollback is a second write, so the caller has to refresh again or
      // the list keeps showing the merged dive.
      expect(consolidatedCalls, 2);
      // See app_en.arb's diveLog_consolidate_undone.
      expect(find.text('Merge undone'), findsOneWidget);
    });

    testWidgets(
      'tapping Undo still works once the calling dialog has been popped',
      (tester) async {
        final service = FakeDiveConsolidationService();
        var consolidatedCalls = 0;

        // Mirrors combine_dives_dialog.dart's _confirmConsolidation, which
        // pops itself and then calls runDiveConsolidation with the dialog's
        // own (deactivating) context. The helper reads context only before
        // its first await; this test fails if that ever changes, e.g. if the
        // Undo closure starts re-reading ScaffoldMessenger.of(context).
        await _pumpAndRunFromPoppedDialog(
          tester,
          service: service,
          onConsolidated: () => consolidatedCalls++,
        );

        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();

        expect(service.undoCallCount, 1);
        expect(find.text('Merge undone'), findsOneWidget);
        // Both refreshes still reach the caller even though the dialog that
        // started this is gone. Production depends on exactly that: the real
        // callback invalidates providers through a captured container rather
        // than `ref`, because the dialog's State is disposed by now.
        expect(consolidatedCalls, 2);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'tapping Undo when service.undo throws shows the undo-error snackbar '
      'text instead of crashing',
      (tester) async {
        final service = FakeDiveConsolidationService(
          undoError: StateError('Bad state: dive already deleted'),
        );

        await _pumpAndRun(tester, service: service);

        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();

        // See app_en.arb's diveLog_consolidate_undoError for the English
        // source string.
        expect(find.text("Couldn't undo the merge."), findsOneWidget);
        // The rollback was attempted rather than skipped, and it did not
        // complete.
        expect(service.undoCallCount, 1);
        expect(service.undoneSnapshot, isNull);
        // The failure was caught inside the SnackBarAction's onPressed; no
        // exception should escape to the test framework.
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'an ArgumentError with a sameComputer reason surfaces the sameComputer '
      'error text instead of a success snackbar',
      (tester) async {
        await _pumpAndRun(
          tester,
          service: FakeDiveConsolidationService(
            applyError: ArgumentError('sameComputer: shares comp-1'),
          ),
        );

        expect(
          find.text(
            "These dives are from the same dive computer and can't be "
            'merged this way.',
          ),
          findsOneWidget,
        );
        // No Undo action on a failure snackbar.
        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.action, isNull);
      },
    );

    testWidgets('an ArgumentError with a notOverlapping reason surfaces the '
        'notOverlapping error text', (tester) async {
      await _pumpAndRun(
        tester,
        service: FakeDiveConsolidationService(
          // The wrapper DiveConsolidationBuilder.build throws.
          applyError: ArgumentError(
            'build() requires a consolidatable selection; got '
            'ConsolidationInvalid(notOverlapping)',
          ),
        ),
      );

      expect(
        find.text(
          "These dives don't overlap in time, so they can't be merged as "
          'the same dive.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'a non-ArgumentError failure (e.g. a dive deleted by sync mid-flow) '
      'surfaces the generic error text instead of crashing',
      (tester) async {
        var consolidatedCalls = 0;

        await _pumpAndRun(
          tester,
          service: FakeDiveConsolidationService(
            applyError: StateError('Bad state: No element'),
          ),
          onConsolidated: () => consolidatedCalls++,
        );

        expect(
          find.text("Couldn't merge the dives. Nothing was changed."),
          findsOneWidget,
        );
        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.action, isNull);
        // Nothing was written, so the caller is never told to refresh.
        expect(consolidatedCalls, 0);
        // The interaction failed gracefully: no unhandled exception reached
        // the framework.
        expect(tester.takeException(), isNull);
      },
    );
  });
}

/// Pumps a bare button whose callback awaits [runDiveConsolidation], taps it,
/// and settles. The helper needs nothing but a [BuildContext] with a
/// [ScaffoldMessenger] and localizations above it, so there is no dialog in
/// the way of the wiring under test.
///
/// Awaiting mirrors the data quality inbox caller; the popped-dialog helper
/// below mirrors the combine dialog's fire-and-forget call instead, so both
/// production shapes are covered.
///
/// The locale is pinned to English: flutter_test forwards the HOST machine's
/// locale list, so an unpinned MaterialApp resolves against it and a developer
/// whose primary locale is one of the app's other ten would get a translated
/// UI, failing every English SnackBar assertion above while CI stayed green.
Future<void> _pumpAndRun(
  WidgetTester tester, {
  required FakeDiveConsolidationService service,
  VoidCallback? onConsolidated,
  ConsolidationAlignment? alignment,
}) async {
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      child: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              _run(context, service, onConsolidated, alignment: alignment),
          child: const Text('Merge'),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Merge'));
  await tester.pumpAndSettle();
}

/// Like [_pumpAndRun], but the call is made from a dialog that pops itself
/// first, reproducing the production sequence in `combine_dives_dialog.dart`.
Future<void> _pumpAndRunFromPoppedDialog(
  WidgetTester tester, {
  required FakeDiveConsolidationService service,
  VoidCallback? onConsolidated,
}) async {
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      child: Builder(
        builder: (hostContext) => TextButton(
          onPressed: () => showDialog<void>(
            context: hostContext,
            builder: (dialogContext) => AlertDialog(
              content: TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  // Fire-and-forget, exactly as _confirmConsolidation does.
                  _run(dialogContext, service, onConsolidated);
                },
                child: const Text('Merge'),
              ),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Merge'));
  await tester.pumpAndSettle();
}

Future<void> _run(
  BuildContext context,
  FakeDiveConsolidationService service,
  VoidCallback? onConsolidated, {
  ConsolidationAlignment? alignment,
}) {
  return runDiveConsolidation(
    context: context,
    service: service,
    targetDiveId: _targetDiveId,
    secondaryDiveIds: _secondaryDiveIds,
    onConsolidated: onConsolidated ?? () {},
    alignment: alignment,
  );
}
