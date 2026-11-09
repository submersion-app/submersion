import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/health_auto_import_service.dart';
import 'package:submersion/features/dive_import/presentation/health_auto_import_feedback.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// What the diver hears after an automatic Apple Health import (issue #637).
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('one new dive offers to add details to it', () {
    final message = healthAutoImportMessage(
      const HealthAutoImportResult(newDiveIds: ['d1']),
      l10n,
    )!;

    expect(message.title, 'New dive from your Apple Watch');
    expect(message.body, 'Add details?');
    expect(message.payload, 'dive:d1');
  });

  test('a filled draft counts as a new dive', () {
    final message = healthAutoImportMessage(
      const HealthAutoImportResult(filledDraftIds: ['d2']),
      l10n,
    )!;

    expect(message.payload, 'dive:d2');
  });

  test('several dives are one message that opens the list', () {
    final message = healthAutoImportMessage(
      const HealthAutoImportResult(
        newDiveIds: ['a', 'b'],
        filledDraftIds: ['c'],
      ),
      l10n,
    )!;

    expect(message.title, '3 new dives from your Apple Watch');
    expect(message.payload, 'dives');
  });

  test('a workout that waits for the diver opens the Health import', () {
    final message = healthAutoImportMessage(
      const HealthAutoImportResult(reviewWorkoutIds: ['w']),
      l10n,
    )!;

    expect(message.payload, 'healthReview');
  });

  test("a workout on a plan's day says so", () {
    final message = healthAutoImportMessage(
      const HealthAutoImportResult(planReviewWorkoutIds: ['w']),
      l10n,
    )!;

    expect(message.body, contains('planned'));
    expect(message.payload, 'healthReview');
  });

  test('a quiet run, or one that only joined dives, says nothing', () {
    expect(
      healthAutoImportMessage(const HealthAutoImportResult(), l10n),
      isNull,
    );
    expect(
      healthAutoImportMessage(
        const HealthAutoImportResult(consolidatedIds: ['x']),
        l10n,
      ),
      isNull,
    );
  });

  test('the import runs at most every ten minutes', () {
    var now = DateTime(2026, 7, 17, 10);
    final throttle = HealthAutoImportThrottle(clock: () => now);

    expect(throttle.take(), isTrue);
    now = now.add(const Duration(minutes: 9));
    expect(throttle.take(), isFalse);
    now = now.add(const Duration(minutes: 2));
    expect(throttle.take(), isTrue);
  });
}
