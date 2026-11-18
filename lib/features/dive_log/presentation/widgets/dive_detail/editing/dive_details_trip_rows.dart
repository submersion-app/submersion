import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/domain/services/dive_center_picker_ranking.dart';
import 'package:submersion/features/dive_centers/domain/services/rental_memory_resolver.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/apply_last_dive_confirm_dialog.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_picker.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/rental_memory_card.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_rules.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_weights_fields.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
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
/// The record exists whether or not this read works. When the read fails,
/// or finds nothing, the dive is left as it was and the diver is told that
/// it was saved and to pick it from the list: asked to try again, they
/// would make it a second time. [messenger] and
/// [sorry] are read before the page that made the record was opened.
Future<V?> _readBack<V>(
  Future<V?> Function() read, {
  required String what,
  required ScaffoldMessengerState messenger,
  required String sorry,
}) async {
  V? record;
  try {
    record = await read();
    if (record == null) _log.warning('The new $what was not there to read');
  } catch (error, stackTrace) {
    _log.warning(
      'Could not read back the new $what',
      error: error,
      stackTrace: stackTrace,
    );
  }
  if (record == null) messenger.showSnackBar(SnackBar(content: Text(sorry)));
  return record;
}

/// Sets [field] on [session] unless the row has gone, or the sitting has
/// ended or is being written: a sheet, a page or a lookup can answer after
/// any of them.
///
/// [session] is the sitting the answer was asked for. A row can be handed
/// another sitting while its picker is open, and what comes back belongs to
/// the one it was opened in, never to whichever the row holds by then.
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
  /// Puts [trip] on the dive. A slot belongs to one trip, so a change of
  /// trip clears every cylinder's slot link and suggests slots on the new
  /// one, as the dive form does (`_setTrip`; issue #4527, plan 5).
  void _set(EditSession<Dive> session, Trip? trip) {
    final was = session.valueOf(diveTripField)?.id;
    _setIfStillEditing(this, session, diveTripField, trip);
    if (!mounted || session.valueOf(diveTripField)?.id == was) return;
    tanksAfterTripChange(
      session,
      readSlots: tripSlotReader(
        ProviderScope.containerOf(context, listen: false),
        session.stored.id,
      ),
    );
  }

  /// Takes the dive off a trip that did not load. Its cylinders' slot
  /// links went with that trip, as for any change of trip.
  void _clearUnloaded(EditSession<Dive> session) {
    _setIfStillEditing(this, session, diveTripIdField, null);
    if (!mounted || session.valueOf(diveTripIdField) != null) return;
    tanksAfterTripChange(
      session,
      readSlots: tripSlotReader(
        ProviderScope.containerOf(context, listen: false),
        session.stored.id,
      ),
    );
  }

  Future<void> _pick() async {
    final session = widget.session;
    // Read now: the lookup below can run after the row has gone.
    final trips = ref.read(tripRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final sorry = context.l10n.diveLog_edit_newRecordNotAdded;
    final result = await _showPickerSheet(
      context,
      (sheetContext, scroll) => TripPickerSheet(
        scrollController: scroll,
        selectedTrip: session.valueOf(diveTripField),
        onTripSelected: (trip) {
          Navigator.of(sheetContext).pop();
          _set(session, trip);
        },
        onCreateNewTrip: () => Navigator.of(sheetContext).pop(_createNew),
      ),
    );
    if (result != _createNew || !mounted) return;
    final tripId = await newTripForDiveEdit(
      context,
      ref,
      () => _newTripFacts(session),
    );
    if (tripId == null) return;
    final trip = await _readBack(
      () => trips.getTripById(tripId),
      what: 'trip',
      messenger: messenger,
      sorry: sorry,
    );
    if (trip != null) _set(session, trip);
  }

  /// What a trip made from here learns from the dive as [session] holds it
  /// (#3351): the sitting the picker was opened in.
  Future<List<SelectionDiveFacts>> _newTripFacts(
    EditSession<Dive> session,
  ) async {
    final dive = session.working;
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
        // A trip id whose trip did not load would read as no trip, but Save
        // keeps the id. The row says the trip is not there, and offers the
        // clear.
        final unloaded =
            trip == null && session.valueOf(diveTripIdField) != null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            FormRow.picker(
              label: l10n.diveLog_edit_row_trip,
              value:
                  trip?.name ??
                  (unloaded ? l10n.diveLog_edit_row_tripNotFound : null),
              placeholder: l10n.diveLog_edit_row_notSet,
              onTap: _pick,
              onClear: trip != null
                  ? () => _set(session, null)
                  : unloaded
                  ? () => _clearUnloaded(session)
                  : null,
              clearTooltip: l10n.common_action_remove,
            ),
            if (trip != null)
              _Caption(
                units.formatDateRange(trip.startDate, trip.endDate, l10n: l10n),
              )
            else
              _TripSuggestion(
                day: diveTripSuggestionDay(session.working),
                onUse: (suggested) => _set(session, suggested),
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
  void _set(EditSession<Dive> session, DiveCenter? center) =>
      _setIfStillEditing(this, session, diveCenterField, center);

  /// The weights and cylinders of the diver's last dive at the center
  /// replace the sitting's, asking first when it holds any (issue #2075).
  Future<void> _applyLastDive(
    EditSession<Dive> session,
    LastDiveAtCenter last,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final applied = context.l10n.diveCenters_rental_applied;
    final startPressure = ref.read(
      settingsProvider.select((s) => s.defaultStartPressure),
    );
    if (applyLastDiveNeedsConfirm(
      weights: session.valueOf(diveWeightsField),
      tanks: session.valueOf(diveTanksField),
    )) {
      final replace = await confirmApplyLastDive(context);
      if (!replace || !mounted) return;
    }
    if (session.isDisposed || session.isFrozen) return;
    applyLastDiveInSitting(session, last, defaultStartPressure: startPressure);
    messenger.showSnackBar(SnackBar(content: Text(applied)));
  }

  Future<void> _pick() async {
    final session = widget.session;
    final dive = session.working;
    // Read now: the lookup below can run after the row has gone.
    final centers = ref.read(diveCenterRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final sorry = context.l10n.diveLog_edit_newRecordNotAdded;
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
          _set(session, center);
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
    if (center != null) _set(session, center);
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
              onClear: center == null ? null : () => _set(session, null),
              clearTooltip: l10n.common_action_remove,
            ),
            if (where != null) _Caption(where),
            // What the diver rented here last time, and a way to copy that
            // dive's weights and cylinders. Its rental notes are the
            // center's own records, written at once (issue #4527, plan 5).
            if (center != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  _underRowInset,
                  0,
                  _underRowInset,
                  10,
                ),
                child: RentalMemoryCard(
                  center: center,
                  currentDiveId: session.stored.id,
                  onApplyLastDive: (last) => _applyLastDive(session, last),
                ),
              ),
          ],
        );
      },
    );
  }
}
