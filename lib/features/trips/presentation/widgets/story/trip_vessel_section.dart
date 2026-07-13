import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Vessel information section for liveaboard trips.
class TripVesselSection extends ConsumerWidget {
  final String tripId;

  const TripVesselSection({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(liveaboardDetailsProvider(tripId));

    return detailsAsync.when(
      data: (details) {
        if (details == null) return const SizedBox.shrink();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.trips_detail_sectionTitle_vessel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                // vesselName is the one required detail; surface it so a record
                // with no optional fields still shows more than the heading.
                Text(
                  details.vesselName,
                  style: Theme.of(context).textTheme.bodyLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                if (details.operatorName != null)
                  _VesselDetailRow(
                    icon: Icons.business,
                    label: context.l10n.trips_detail_label_operator,
                    value: details.operatorName!,
                  ),
                if (details.vesselType != null)
                  _VesselDetailRow(
                    icon: Icons.directions_boat,
                    label: context.l10n.trips_detail_label_vesselType,
                    value: details.vesselType!,
                  ),
                if (details.cabinType != null)
                  _VesselDetailRow(
                    icon: Icons.king_bed,
                    label: context.l10n.trips_detail_label_cabin,
                    value: details.cabinType!,
                  ),
                if (details.capacity != null)
                  _VesselDetailRow(
                    icon: Icons.people,
                    label: context.l10n.trips_detail_label_capacity,
                    value: details.capacity.toString(),
                  ),
                if (details.embarkPort != null)
                  _VesselDetailRow(
                    icon: Icons.login,
                    label: context.l10n.trips_detail_label_embark,
                    value: details.embarkPort!,
                  ),
                if (details.disembarkPort != null)
                  _VesselDetailRow(
                    icon: Icons.logout,
                    label: context.l10n.trips_detail_label_disembark,
                    value: details.disembarkPort!,
                  ),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// A single row in the vessel details section.
class _VesselDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _VesselDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
