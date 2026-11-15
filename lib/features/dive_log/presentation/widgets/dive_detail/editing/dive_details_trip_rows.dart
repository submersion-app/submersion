import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/domain/services/dive_center_picker_ranking.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_picker.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_draft.dart';
import 'package:submersion/features/trips/presentation/helpers/new_trip_from_selection.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_picker.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

// The trip and dive center rows of the Details card's editor. Each is a
// picker over existing records with a way to make a new one. A record made
// that way exists at once and outlives a cancelled sitting; only the dive's
// link to it is held until Save.

const _log = LoggerService('DiveDetailsTripRows');

/// What a picker sheet pops with when the diver asks for a new record.
const _createNew = '__create_new__';

/// How far the words under a picker row sit in from the card's edge: the
/// form rows' own inset.
const double _underRowInset = 14;

/// Reads back a record the diver has just made, to put it on the dive.
///
/// The record exists whether or not this read works. When it fails the dive
/// is left as it was and the diver is told, so they can pick the new record
/// from the list instead. [messenger] and [sorry] are read before the page
/// that made the record was opened.
Future<V?> _readBack<V>(
  Future<V?> Function() read, {
  required String what,
  required ScaffoldMessengerState messenger,
  required String sorry,
}) async {
  try {
    return await read();
  } catch (error, stackTrace) {
    _log.warning(
      'Could not read back the new $what',
      error: error,
      stackTrace: stackTrace,
    );
    messenger.showSnackBar(SnackBar(content: Text(sorry)));
    return null;
  }
}

/// Sets [field] unless the row has gone, or the sitting has ended or is
/// being written: a sheet, a page or a lookup can answer after any of them.
void _setIfStillEditing<V>(
  State state,
  EditSession<Dive> session,
  EditField<Dive, V> field,
  V value,
) {
  if (!state.mounted || session.isDisposed || session.isFrozen) return;
  session.set(field, value);
}

/// The line under a picker row that says more about what was picked.
class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(_underRowInset, 0, _underRowInset, 10),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Opens [sheet] as the dive form opens its pickers.
Future<String?> _showPickerSheet(
  BuildContext context,
  Widget Function(BuildContext sheetContext, ScrollController scroll) sheet,
) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scroll) => sheet(sheetContext, scroll),
    ),
  );
}

/// The trip row of the Details card: the trip, its dates under it, and,
/// for a dive on no trip, the trip its day falls in as a suggestion.
class DiveTripRow extends ConsumerStatefulWidget {
  const DiveTripRow({super.key, required this.session});

  final EditSession<Dive> session;

  @override
  ConsumerState<DiveTripRow> createState() => _DiveTripRowState();
}

class _DiveTripRowState extends ConsumerState<DiveTripRow> {
  void _set(Trip? trip) =>
      _setIfStillEditing(this, widget.session, diveTripField, trip);

  Future<void> _pick() async {
    final session = widget.session;
    // Read now: the lookup below can run after the row has gone.
    final trips = ref.read(tripRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final sorry = context.l10n.common_error_tryAgain;
    final result = await _showPickerSheet(
      context,
      (sheetContext, scroll) => TripPickerSheet(
        scrollController: scroll,
        selectedTrip: session.valueOf(diveTripField),
        onTripSelected: (trip) {
          Navigator.of(sheetContext).pop();
          _set(trip);
        },
        onCreateNewTrip: () => Navigator.of(sheetContext).pop(_createNew),
      ),
    );
    if (result != _createNew || !mounted) return;
    final tripId = await newTripForDiveEdit(context, ref, _newTripFacts);
    if (tripId == null) return;
    final trip = await _readBack(
      () => trips.getTripById(tripId),
      what: 'trip',
      messenger: messenger,
      sorry: sorry,
    );
    if (trip != null) _set(trip);
  }

  /// What a trip made from here learns from the dive as the sitting holds
  /// it (#3351).
  Future<List<SelectionDiveFacts>> _newTripFacts() async {
    final dive = widget.session.working;
    final entry = dive.effectiveEntryTime;
    return [
      SelectionDiveFacts(
        diveId: '',
        diveDateTime: DateTime.utc(entry.year, entry.month, entry.day),
        tripId: dive.tripId ?? dive.trip?.id,
        siteRegion: dive.site?.region,
        siteCountry: dive.site?.country,
        diveCenterName: dive.diveCenter?.name,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final session = widget.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final trip = session.valueOf(diveTripField);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            FormRow.picker(
              label: l10n.diveLog_edit_row_trip,
              value: trip?.name,
              placeholder: l10n.diveLog_edit_row_notSet,
              onTap: _pick,
              onClear: trip == null ? null : () => _set(null),
              clearTooltip: l10n.common_action_remove,
            ),
            if (trip != null)
              _Caption(
                units.formatDateRange(trip.startDate, trip.endDate, l10n: l10n),
              )
            else
              _TripSuggestion(
                day: diveTripSuggestionDay(session.working),
                onUse: _set,
              ),
          ],
        );
      },
    );
  }
}

/// The trip a dive's day falls in, offered to a dive on no trip. Draws
/// nothing while it is looked up, when the lookup fails, or when no trip
/// covers the day.
class _TripSuggestion extends ConsumerWidget {
  const _TripSuggestion({required this.day, required this.onUse});

  final DateTime day;
  final ValueChanged<Trip> onUse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggested = ref.watch(tripForDateProvider(day)).valueOrNull;
    if (suggested == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _underRowInset),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.diveLog_edit_tripSuggested(suggested.name),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => onUse(suggested),
            child: Text(l10n.diveLog_edit_tripUse),
          ),
        ],
      ),
    );
  }
}

/// The dive center row of the Details card, with where the center is.
class DiveCenterRow extends ConsumerStatefulWidget {
  const DiveCenterRow({super.key, required this.session});

  final EditSession<Dive> session;

  @override
  ConsumerState<DiveCenterRow> createState() => _DiveCenterRowState();
}

class _DiveCenterRowState extends ConsumerState<DiveCenterRow> {
  void _set(DiveCenter? center) =>
      _setIfStillEditing(this, widget.session, diveCenterField, center);

  Future<void> _pick() async {
    final session = widget.session;
    final dive = session.working;
    // Read now: the lookup below can run after the row has gone.
    final centers = ref.read(diveCenterRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final sorry = context.l10n.common_error_tryAgain;
    final result = await _showPickerSheet(
      context,
      (sheetContext, scroll) => DiveCenterPickerSheet(
        scrollController: scroll,
        selectedCenter: session.valueOf(diveCenterField),
        // Centers near the dive first (#3379): the site, else the dive's
        // own GPS.
        reference: resolveDiveCenterPickerReference(
          site: dive.site,
          entryLocation: dive.entryLocation,
          exitLocation: dive.exitLocation,
        ),
        onCenterSelected: (center) {
          Navigator.of(sheetContext).pop();
          _set(center);
        },
        onCreateNewCenter: () => Navigator.of(sheetContext).pop(_createNew),
      ),
    );
    if (result != _createNew || !mounted) return;
    final centerId = await context.push<String>('/dive-centers/new');
    if (centerId == null) return;
    final center = await _readBack(
      () => centers.getDiveCenterById(centerId),
      what: 'dive center',
      messenger: messenger,
      sorry: sorry,
    );
    if (center != null) _set(center);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = widget.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final center = session.valueOf(diveCenterField);
        final where = center?.displayLocation;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            FormRow.picker(
              label: l10n.diveLog_edit_row_diveCenter,
              value: center?.name,
              placeholder: l10n.diveLog_edit_row_notSet,
              onTap: _pick,
              onClear: center == null ? null : () => _set(null),
              clearTooltip: l10n.common_action_remove,
            ),
            if (where != null) _Caption(where),
          ],
        );
      },
    );
  }
}
