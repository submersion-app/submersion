import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/restore_barrier.dart';

import '../../../../helpers/test_app.dart';

void main() {
  // Pin the locale via the shared testApp helper for deterministic string
  // finders. The barrier's message is a raw (non-localized) string today, but
  // pinning keeps the test robust if it ever becomes localized.
  Widget wrap({
    required bool restoring,
    String? message,
    SafetyReviewSweepProgress? sweepProgress,
    required VoidCallback onTap,
  }) {
    return testApp(
      locale: const Locale('en'),
      overrides: [
        restoreInProgressProvider.overrideWithValue(restoring),
        restoreMessageProvider.overrideWithValue(message),
        restoreSweepProgressProvider.overrideWithValue(sweepProgress),
      ],
      child: RestoreBarrier(
        child: Center(
          child: ElevatedButton(onPressed: onTap, child: const Text('Tap me')),
        ),
      ),
    );
  }

  testWidgets('when not restoring, no overlay and the child is interactive', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(wrap(restoring: false, onTap: () => taps++));

    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.text('Tap me'));
    expect(taps, 1);
  });

  testWidgets('while restoring, the overlay shows and blocks interaction', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        restoring: true,
        message: 'Restoring backup...',
        onTap: () => taps++,
      ),
    );

    // Progress + message are shown.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Restoring backup...'), findsOneWidget);

    // The underlying button is still present but taps are absorbed by the
    // barrier (warnIfMissed: the hit is intentionally swallowed).
    await tester.tap(find.text('Tap me'), warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('falls back to a default message when none is provided', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(restoring: true, onTap: () {}));
    expect(find.text('Restoring backup...'), findsOneWidget);
  });

  // The Skip button's callback resolves backupOperationProvider.notifier,
  // which would drag the whole backup service graph into a widget test. These
  // assert that it renders; the skip behavior itself is covered by the
  // notifier test in backup_providers_restore_test.dart.
  testWidgets('shows determinate sweep progress and a Skip button', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        restoring: true,
        sweepProgress: const SafetyReviewSweepProgress(done: 3, total: 10),
        onTap: () {},
      ),
    );

    expect(find.text('Running the safety review'), findsOneWidget);
    expect(find.text('Analyzed 3 of 10 dives'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.3, 0.001));
  });

  testWidgets('keeps the plain spinner when no sweep is running', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(restoring: true, message: 'Restoring backup...', onTap: () {}),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Skip'), findsNothing);
  });

  testWidgets(
    'exposes a semantics label so screen readers announce the state',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(restoring: true, message: 'Restoring backup...', onTap: () {}),
      );

      expect(find.bySemanticsLabel('Restoring backup...'), findsOneWidget);
      handle.dispose();
    },
  );
}
