import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/selection_trip_facts.dart';
import 'package:submersion/features/trips/domain/services/trip_draft.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the new-trip form prefilled from the dives [diveIds] (issue #3658)
/// and, once the trip is saved, the trip itself. Returns the new trip's id,
/// or null when nothing was saved.
Future<String?> newTripFromSelection(
  BuildContext context,
  WidgetRef ref,
  List<String> diveIds,
) async {
  final l10n = context.l10n;
  final units = UnitFormatter(ref.read(settingsProvider));
  final facts = await loadSelectionTripFacts(diveIds);
  if (facts.isEmpty) return null;
  final trips = await ref.read(allTripsProvider.future);
  final draft = buildTripDraft(
    facts,
    tripsById: {for (final t in trips) t.id: t},
    nameFor: (location, start) {
      final monthYear = units.formatMonthYear(start);
      return location == null
          ? l10n.trips_fromSelection_nameNoLocation(monthYear)
          : l10n.trips_fromSelection_name(location, monthYear);
    },
  );
  if (!context.mounted) return null;
  final tripId = await context.push<String>('/trips/new', extra: draft);
  if (tripId != null && context.mounted) context.push('/trips/$tripId');
  return tripId;
}
