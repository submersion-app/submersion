import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The service status sentence is composed in exactly one place.
///
/// This is the drift that actually happened: `equipment_list_worstClock` and
/// `trips_serviceAlert_overdue` held the same sentence under two keys, in two
/// features, byte-identical across all 11 locale files, with nothing keeping
/// them in step. Retiring one key fixes today; this keeps tomorrow honest.
///
/// Deliberately NOT a guard on `equipmentRollupClockProvider`. Several
/// surfaces read that map for things the indicator does not own: tinting a
/// list avatar, arbitrating against a condition finding via `pickBadgeSource`,
/// or drawing a neutral dot for a healthy part, which the indicator renders
/// as nothing. A guard whose allowlist held most of its readers would guard
/// nothing at all.
void main() {
  /// Files permitted to compose the status wording, with the reason.
  const allowed = <String, String>{
    // The one place the app decides how a service clock reads.
    'lib/features/equipment/presentation/widgets/service_status_indicator.dart':
        'the shared indicator',
    // The trip banner pairs the shared overdue sentence with its own
    // trip-relative due-soon wording ("due before {trip date}"), which is
    // more useful there than a plain relative day count.
    'lib/features/trips/presentation/widgets/trip_service_alert_banner.dart':
        'trip-relative due-soon wording',
  };

  // Match the call, `l10n.equipment_service_overdue(...)`, not the name.
  // A bare substring scan also hits doc comments that merely mention the key,
  // which is prose, not a second place composing the sentence.
  final calls = RegExp(
    r'\.(equipment_service_overdue|equipment_service_dueRelative)\s*\(',
  );

  test('only the shared indicator composes the service status wording', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      // Generated localizations declare every key by definition.
      if (path.startsWith('lib/l10n/')) continue;
      if (allowed.containsKey(path)) continue;
      final source = entity.readAsStringSync();
      if (calls.hasMatch(source)) offenders.add(path);
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'render service status through ServiceStatusIndicator, '
          'ServiceStatusIndicatorFor or ServiceStatusIndicatorForAny rather '
          'than composing the sentence again. If a surface genuinely needs '
          'its own wording, add it to the allowlist in this test with the '
          'reason.',
    );
  });

  test('every allowlisted file exists and still uses the wording', () {
    // An allowlist entry that no longer applies is a stale exemption, and a
    // stale exemption is how a guard quietly stops guarding.
    for (final entry in allowed.entries) {
      final file = File(entry.key);
      expect(
        file.existsSync(),
        isTrue,
        reason: '${entry.key} is allowlisted but does not exist',
      );
      expect(
        calls.hasMatch(file.readAsStringSync()),
        isTrue,
        reason:
            '${entry.key} is allowlisted as "${entry.value}" but no longer '
            'composes the wording; remove it from the allowlist',
      );
    }
  });
}
