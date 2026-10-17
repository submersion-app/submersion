import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_summary_scene.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_summary_widget.dart';
import 'package:submersion/shared/widgets/summary/summary_pane_switcher.dart';

/// What the Trips detail pane shows with no trip selected: the passage
/// scene or the data-rich summary, per Settings > Appearance and the pane's
/// corner toggle.
///
/// No trips defaults to the summary widget, whose Add Trip button is the way
/// in. A list still loading is not empty, so the pane never flashes from one
/// view to the other on start.
class TripSummaryPane extends ConsumerWidget {
  const TripSummaryPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripListNotifierProvider).value;

    return SummaryPaneSwitcher(
      sectionId: 'trips',
      isEmpty: trips != null && trips.isEmpty,
      scene: (_) => const TripSummaryScene(),
      details: (_) => const TripSummaryWidget(),
    );
  }
}
