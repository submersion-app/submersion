import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_vessel_sitting.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row_group.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';

/// Vessel information section for liveaboard trips.
///
/// Where the trip page edits in place (issue #4527) it is the Vessel card:
/// with [session] it shows the details the sitting holds, and a liveaboard
/// with none still shows its title, so the card can be opened.
class TripVesselSection extends ConsumerWidget {
  final String tripId;

  /// The trip page's open sitting.
  final EditSession<Trip>? session;

  const TripVesselSection({super.key, required this.tripId, this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = this.session;
    if (session != null) {
      final list = tripVesselState;
      return ListenableBuilder(
        listenable: list.changes(session),
        builder: (context, _) {
          final held = list.current(session);
          if (held == null) {
            // Not read yet: what is stored, until the sitting's read lands.
            return _stored(context, ref, showEmpty: true);
          }
          return _card(context, tripVesselInSitting(list, session));
        },
      );
    }
    return _stored(context, ref);
  }

  Widget _stored(
    BuildContext context,
    WidgetRef ref, {
    bool showEmpty = false,
  }) {
    final detailsAsync = ref.watch(liveaboardDetailsProvider(tripId));

    return detailsAsync.when(
      data: (details) {
        if (details == null && !showEmpty) return const SizedBox.shrink();
        return _card(context, details);
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

  /// The card for [details]; with none, its title alone.
  Widget _card(BuildContext context, LiveaboardDetails? details) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DetailRowGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.trips_detail_sectionTitle_vessel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // The card's pencil while the page edits in place.
                  RecordCardPencil(
                    cardTitle: context.l10n.trips_detail_sectionTitle_vessel,
                  ),
                ],
              ),
              if (details != null) ...[
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
            ],
          ),
        ),
      ),
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
    final textTheme = Theme.of(context).textTheme;
    return DetailRow.text(
      icon: icon,
      label: label,
      labelStyle: textTheme.bodyMedium,
      value: value,
      valueStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      padding: const EdgeInsets.symmetric(vertical: 4),
    );
  }
}
