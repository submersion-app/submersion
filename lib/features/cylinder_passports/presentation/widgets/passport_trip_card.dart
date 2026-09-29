import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_picker.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('passportTripCard');

/// The trips a cylinder is packed for (spec section 8, issue #2338): the
/// nearest in-progress or upcoming trip first, "+N" for the rest. A trip
/// where the cylinder is only a slot on the trip's cylinder board shows too,
/// but only a packed trip can be unpacked here.
class PassportTripCard extends ConsumerStatefulWidget {
  const PassportTripCard({super.key, required this.equipmentId});

  final String equipmentId;

  @override
  ConsumerState<PassportTripCard> createState() => _PassportTripCardState();
}

class _PassportTripCardState extends ConsumerState<PassportTripCard> {
  bool _expanded = false;

  Future<void> _assign() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final trip = await showModalBottomSheet<Trip>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => TripPickerSheet(
          scrollController: scrollController,
          selectedTrip: null,
          onTripSelected: (trip) => Navigator.of(sheetContext).pop(trip),
          // Packing starts from an existing trip; a new one is made on the
          // trips page.
          onCreateNewTrip: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
    if (trip == null) return;
    try {
      await ref.read(tripEquipmentRepositoryProvider).pack(trip.id, [
        widget.equipmentId,
      ]);
    } catch (e, stackTrace) {
      _log.error('Failed to pack a cylinder', error: e, stackTrace: stackTrace);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.passport_trip_failed)),
      );
    }
  }

  Future<void> _unpack(Trip trip) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref
          .read(tripEquipmentRepositoryProvider)
          .unpack(trip.id, widget.equipmentId);
    } catch (e, stackTrace) {
      _log.error(
        'Failed to unpack a cylinder',
        error: e,
        stackTrace: stackTrace,
      );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.passport_trip_failed)),
      );
    }
  }

  Widget _chip(PackedTrip p) {
    final l10n = context.l10n;
    final chip = InputChip(
      key: Key('passport-trip-${p.trip.id}'),
      avatar: Icon(
        p.packed ? Icons.luggage_outlined : Icons.propane_tank_outlined,
        size: 18,
      ),
      label: Text(l10n.passport_trip_packedFor(p.trip.name)),
      visualDensity: VisualDensity.compact,
      onPressed: () => context.push('/trips/${p.trip.id}'),
      onDeleted: p.packed ? () => _unpack(p.trip) : null,
      deleteButtonTooltipMessage: l10n.passport_trip_unassign,
    );
    return p.packed
        ? chip
        : Tooltip(message: l10n.passport_trip_onBoard, child: chip);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final trips =
        ref.watch(equipmentTripsProvider(widget.equipmentId)).value ??
        const <PackedTrip>[];
    final shown = _expanded ? trips : trips.take(1);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.passport_trip_title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (trips.isEmpty)
              Text(l10n.passport_trip_none)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in shown) _chip(p),
                  if (!_expanded && trips.length > 1)
                    ActionChip(
                      key: const Key('passport-trip-more'),
                      label: Text(l10n.passport_trip_more(trips.length - 1)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _expanded = true),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                key: const Key('passport-trip-assign'),
                onPressed: _assign,
                icon: const Icon(Icons.add),
                label: Text(l10n.passport_trip_assign),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
