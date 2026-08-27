import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/safety/presentation/providers/incident_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Quiet chip shown in dive detail when near-miss reports link to the dive.
/// Renders nothing when there are none.
class LinkedIncidentsRow extends ConsumerWidget {
  final String diveId;

  const LinkedIncidentsRow({required this.diveId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidents = ref.watch(incidentsForDiveProvider(diveId)).value;
    if (incidents == null || incidents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ActionChip(
        avatar: Icon(
          Icons.flag_outlined,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        label: Text(
          context.l10n.diveLog_detail_linkedIncidents(incidents.length),
        ),
        onPressed: () => context.push('/incidents'),
      ),
    );
  }
}
