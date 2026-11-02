import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/selection_trip_facts.dart';
import 'package:submersion/features/trips/domain/services/trip_draft.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _log = LoggerService('newTripFromSelection');

/// Opens the new-trip form prefilled from the dives [diveIds] (issue #3658)
/// and, once the trip is saved, the trip itself. Returns the new trip's id,
/// or null when nothing was saved.
Future<String?> newTripFromSelection(
  BuildContext context,
  WidgetRef ref,
  List<String> diveIds,
) async {
  final facts = await loadSelectionTripFacts(diveIds);
  if (facts.isEmpty || !context.mounted) return null;
  final draft = await _draftFrom(context, ref, facts);
  if (!context.mounted) return null;
  final tripId = await context.push<String>('/trips/new', extra: draft);
  if (tripId != null && context.mounted) context.push('/trips/$tripId');
  return tripId;
}

/// Opens the new-trip form prefilled from [loadFacts] for an edit in progress
/// (issue #3351), the dive editor's or bulk edit's. The draft takes no dives:
/// they join the trip when that edit saves, so backing out moves nothing. A
/// draft that cannot be built opens the blank form, since the prefill only
/// saves typing. Returns the new trip's id, or null when nothing was saved.
Future<String?> newTripForDiveEdit(
  BuildContext context,
  WidgetRef ref,
  Future<List<SelectionDiveFacts>> Function() loadFacts,
) async {
  TripDraft? draft;
  try {
    final facts = await loadFacts();
    if (facts.isNotEmpty && context.mounted) {
      final built = await _draftFrom(context, ref, facts);
      draft = TripDraft(trip: built.trip, diveIds: const []);
    }
  } catch (e, stackTrace) {
    _log.error(
      'Failed to prefill a new trip',
      error: e,
      stackTrace: stackTrace,
    );
  }
  if (!context.mounted) return null;
  return context.push<String>('/trips/new', extra: draft);
}

Future<TripDraft> _draftFrom(
  BuildContext context,
  WidgetRef ref,
  List<SelectionDiveFacts> facts,
) async {
  final l10n = context.l10n;
  final units = UnitFormatter(ref.read(settingsProvider));
  final trips = await ref.read(allTripsProvider.future);
  return buildTripDraft(
    facts,
    tripsById: {for (final t in trips) t.id: t},
    nameFor: (location, start) {
      final monthYear = units.formatMonthYear(start);
      return location == null
          ? l10n.trips_fromSelection_nameNoLocation(monthYear)
          : l10n.trips_fromSelection_name(location, monthYear);
    },
  );
}
