import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/features/safety/presentation/providers/incident_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

/// The near-miss action on a check-in row: log one from this issue, or open
/// the one already linked. An OK check shows nothing, since only an issue can
/// stand behind a near-miss, and so does a row whose reports have not loaded,
/// so a linked check-in never flashes the offer to log another.
class ObservationNearMissAction extends ConsumerWidget {
  final EquipmentObservation observation;

  const ObservationNearMissAction({required this.observation, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!observation.isIssue) return const SizedBox.shrink();
    final byCheckIn = ref
        .watch(nearMissesByCheckInProvider(observation.equipmentId))
        .valueOrNull;
    if (byCheckIn == null) return const SizedBox.shrink();
    final reports = byCheckIn[observation.id] ?? const <Incident>[];
    final l10n = context.l10n;
    return TileSubtitleAction(
      label: reports.isEmpty
          ? l10n.incidents_add
          : l10n.equipmentObservation_card_nearMissLinked(reports.length),
      onPressed: () => context.push(switch (reports) {
        [] => '/incidents/new?observationId=${observation.id}',
        [final only] => '/incidents/${only.id}',
        _ => '/incidents',
      }),
    );
  }
}
