import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// A widget for selecting a trip, with optional auto-suggest based on date
class TripPicker extends ConsumerStatefulWidget {
  final Trip? selectedTrip;
  final DateTime? diveDate;
  final ValueChanged<Trip?> onTripSelected;

  const TripPicker({
    super.key,
    this.selectedTrip,
    this.diveDate,
    required this.onTripSelected,
  });

  @override
  ConsumerState<TripPicker> createState() => _TripPickerState();
}

class _TripPickerState extends ConsumerState<TripPicker> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.flight_takeoff,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          title: Text(widget.selectedTrip?.name ?? 'No trip selected'),
          subtitle: widget.selectedTrip != null
              ? Text(_formatTripDates(widget.selectedTrip!))
              : const Text('Tap to select a trip'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.selectedTrip != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => widget.onTripSelected(null),
                  tooltip: 'Clear selection',
                ),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => _showTripPickerSheet(context),
        ),
        if (widget.diveDate != null && widget.selectedTrip == null)
          _buildSuggestedTrip(),
      ],
    );
  }

  String _formatTripDates(Trip trip) {
    final dateFormat = DateFormat.yMMMd();
    return '${dateFormat.format(trip.startDate)} - ${dateFormat.format(trip.endDate)}';
  }

  Widget _buildSuggestedTrip() {
    final suggestedTripAsync = ref.watch(tripForDateProvider(widget.diveDate!));

    return suggestedTripAsync.when(
      data: (suggestedTrip) {
        if (suggestedTrip == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(left: 56, top: 4),
          child: Semantics(
            button: true,
            label: 'Suggested trip: ${suggestedTrip.name}. Tap to use',
            child: InkWell(
              onTap: () => widget.onTripSelected(suggestedTrip),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Suggested: ${suggestedTrip.name}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onTripSelected(suggestedTrip),
                    child: const Text('Use'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  void _showTripPickerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => TripPickerSheet(
          scrollController: scrollController,
          selectedTrip: widget.selectedTrip,
          onTripSelected: (trip) {
            Navigator.of(sheetContext).pop();
            widget.onTripSelected(trip);
          },
        ),
      ),
    );
  }
}

/// A bottom sheet widget for selecting a trip from a list
class TripPickerSheet extends ConsumerWidget {
  final ScrollController scrollController;
  final Trip? selectedTrip;
  final ValueChanged<Trip> onTripSelected;

  const TripPickerSheet({
    super.key,
    required this.scrollController,
    required this.selectedTrip,
    required this.onTripSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(allTripsProvider);

    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Title and add button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Trip',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/trips/new');
                },
                icon: const Icon(Icons.add),
                label: const Text('New Trip'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Trip list
        Expanded(
          child: tripsAsync.when(
            data: (trips) {
              if (trips.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.flight_takeoff,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No trips yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push('/trips/new');
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Create Trip'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                controller: scrollController,
                itemCount: trips.length,
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  final isSelected = selectedTrip?.id == trip.id;
                  final dateFormat = DateFormat.yMMMd();

                  final tripLabel =
                      '${trip.name}, ${dateFormat.format(trip.startDate)} to ${dateFormat.format(trip.endDate)}${isSelected ? ', selected' : ''}';

                  return Semantics(
                    label: tripLabel,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          trip.isLiveaboard
                              ? Icons.sailing
                              : Icons.flight_takeoff,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(trip.name),
                      subtitle: Text(
                        '${dateFormat.format(trip.startDate)} - ${dateFormat.format(trip.endDate)}',
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () => onTripSelected(trip),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text('Error loading trips: $error')),
          ),
        ),
      ],
    );
  }
}
