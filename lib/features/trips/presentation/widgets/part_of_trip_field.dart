import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/side_trips.dart';
import 'package:submersion/features/trips/presentation/providers/side_trip_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The trip form's "Part of" field (issue #3658): the larger trip this trip
/// is a side trip of, picked from the trips that may be one (never this
/// trip, never a side trip), or none.
class PartOfTripField extends ConsumerWidget {
  const PartOfTripField({
    super.key,
    required this.tripId,
    required this.value,
    required this.onChanged,
  });

  /// The trip being edited; null for a trip not saved yet.
  final String? tripId;

  /// The chosen larger trip's id, or null.
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // The chosen trip, only when this profile can see it; the candidates
    // only once the sheet opens, so a form with no larger trip resolves no
    // profile while it builds.
    final chosen = value == null
        ? null
        : ref.watch(visibleTripProvider(value!)).value;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.account_tree_outlined),
      title: Text(l10n.trips_edit_field_partOf),
      subtitle: Text(chosen?.name ?? l10n.trips_edit_partOf_none),
      trailing: const Icon(Icons.arrow_drop_down),
      onTap: () async {
        final trips = await ref.read(allTripsProvider.future);
        final candidates =
            trips.where((t) => canChooseAsParent(t, forTripId: tripId)).toList()
              ..sort((a, b) => b.startDate.compareTo(a.startDate));
        if (!context.mounted) return;
        final picked = await showModalBottomSheet<_Pick>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) =>
              _PartOfSheet(candidates: candidates, selectedId: value),
        );
        if (picked != null) onChanged(picked.tripId);
      },
    );
  }
}

/// A choice from the sheet; null [tripId] is "none".
class _Pick {
  const _Pick(this.tripId);
  final String? tripId;
}

class _PartOfSheet extends StatelessWidget {
  const _PartOfSheet({required this.candidates, required this.selectedId});

  final List<Trip> candidates;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          title: Text(
            l10n.trips_edit_field_partOf,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          subtitle: Text(l10n.trips_edit_partOf_helper),
        ),
        const Divider(height: 1),
        ListTile(
          title: Text(l10n.trips_edit_partOf_none),
          trailing: selectedId == null ? const Icon(Icons.check) : null,
          onTap: () => Navigator.of(context).pop(const _Pick(null)),
        ),
        for (final trip in candidates)
          ListTile(
            title: Text(trip.name),
            trailing: trip.id == selectedId ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(context).pop(_Pick(trip.id)),
          ),
      ],
    );
  }
}
