import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/presentation/providers/service_clock_snapshot_provider.dart';

import 'mock_providers.dart' show Override;

/// Stubs [serviceClockSnapshotProvider] for [equipmentId] with [statuses]:
/// the clocks are [schedules], or the statuses' own schedules, and an
/// evaluation hands back the statuses of the clocks it is given. For a test
/// that stubs the item's clocks rather than storing them (issue #5042: the
/// Service clocks card reads its rows and verdicts from one snapshot).
Override serviceClockSnapshotOverride(
  String equipmentId, {
  List<ServiceClockStatus> statuses = const [],
  List<ServiceSchedule>? schedules,
}) => serviceClockSnapshotProvider(equipmentId).overrideWith(
  (ref) async => ServiceClockSnapshot(
    schedules: schedules ?? [for (final s in statuses) s.schedule],
    records: const [],
    evaluate: (schedules, _) {
      final ids = {for (final s in schedules) s.id};
      return [
        for (final s in statuses)
          if (ids.contains(s.schedule.id)) s,
      ];
    },
  ),
);
