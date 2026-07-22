import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/backup/presentation/widgets/restore_barrier.dart';

void main() {
  Widget wrap({
    required bool restoring,
    String? message,
    required VoidCallback onTap,
  }) {
    return ProviderScope(
      overrides: [
        restoreInProgressProvider.overrideWithValue(restoring),
        restoreMessageProvider.overrideWithValue(message),
      ],
      child: MaterialApp(
        home: RestoreBarrier(
          child: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: onTap,
                child: const Text('Tap me'),
              ),
            ),
          ),
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
}
