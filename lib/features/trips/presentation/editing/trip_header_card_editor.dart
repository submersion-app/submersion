import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/presentation/editing/item_shares_sharing_adapter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/item_shares_providers.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_fields.dart';
import 'package:submersion/features/trips/presentation/editing/trip_new_sitting.dart';
import 'package:submersion/features/trips/presentation/providers/side_trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/part_of_trip_field.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_sharing_sitting.dart';
import 'package:submersion/shared/widgets/shared_items/item_sharing_field.dart';
import 'package:submersion/shared/widgets/shared_items/shared_item_dialogs.dart';
import 'package:submersion/shared/widgets/shared_items/share_target_dialog.dart';

/// The trip page's header block (issue #4527, phase 3): its line on the
/// Overview and its editor.

/// Who the trip is shared with, held in its sitting and written at Save.
final tripSharing = RecordSharingSitting<Trip, ItemSharing>(
  key: 'trip.sharing',
  cardId: TripCardId.header.name,
  recordIdOf: (t) => t.id,
);

/// Reads who the trip is shared with into [session], so the header's
/// editor can change it and an owner's Save clears share rows a sync race
/// left beside the Everyone flag. A new trip is shared as its seed was,
/// read from nowhere (plan 11).
Future<void> loadTripSharing(EditSession<Trip> session, ProviderRead read) =>
    tripSharing.load(
      session,
      ItemSharesSharingAdapter(
        read(itemSharesRepositoryProvider),
        SharedItemKind.trip,
      ),
      actingDiverId: read(validatedCurrentDiverIdProvider).value,
      newRecordSharing: session.isNew ? newTripSharing(session.stored) : null,
    );

/// The trip's values no other part of its page shows, on one compact line
/// that wraps: its type when not a liveaboard (a liveaboard has its Vessel
/// card), where it is, its resort, the boat's name as older versions kept
/// it, and, for the owner, who it is shared with. Each is an icon and its
/// value, read out with its label. Nothing while none is set.
///
/// It sits with the rest of the trip summary, on the Overview: under the
/// dates on the story's Trip page and under the hero on the prepare page
/// (issue #4927).
class TripHeaderRows extends ConsumerWidget {
  const TripHeaderRows({super.key, required this.trip});

  /// The trip as the page shows it: the sitting's while unlocked.
  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scope = RecordEditScope.maybeOf<Trip>(context);
    final unlocked = scope?.isUnlocked ?? false;
    final sharing = _sharedWith(context, ref, scope?.session);
    final items = <Widget>[
      if (trip.tripType != TripType.liveaboard)
        _HeaderItem(
          icon: tripTypeIcon(trip.tripType),
          label: l10n.enum_tripField_tripType,
          value: tripTypeName(l10n, trip.tripType),
        ),
      if (_present(trip.location) case final location?)
        _HeaderItem(
          icon: Icons.place,
          label: l10n.trips_edit_label_location,
          value: location,
        ),
      if (_present(trip.resortName) case final resort?)
        _HeaderItem(
          icon: Icons.hotel,
          label: l10n.trips_edit_label_resortName,
          value: resort,
        ),
      if (_present(trip.liveaboardName) case final boat?)
        _HeaderItem(
          icon: Icons.sailing,
          label: l10n.trips_edit_label_liveaboardName,
          value: boat,
        ),
      ?sharing,
    ];
    // Locked, a trip with none of these draws nothing; unlocked the block
    // is always there, so its pencil is.
    if (items.isEmpty && !unlocked) return const SizedBox.shrink();
    final title = TripCardId.header.localizedDisplayName(l10n);
    return Padding(
      key: const Key('trip-header-rows'),
      padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 0, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Wrap(spacing: 16, runSpacing: 4, children: items)),
          RecordCardPencil(cardTitle: title),
        ],
      ),
    );
  }

  /// [value] trimmed, or null when blank: sync and imports can store
  /// whitespace the form would have stored as none.
  static String? _present(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// "Shared with", for the owner of a trip shared with other profiles,
  /// when there are two or more.
  Widget? _sharedWith(
    BuildContext context,
    WidgetRef ref,
    EditSession<Trip>? session,
  ) {
    final divers = ref.watch(allDiversProvider).value ?? const [];
    if (divers.length < 2) return null;
    final isOwner = canDestroySharedItemOnceKnown(
      ref.watch(validatedCurrentDiverIdProvider),
      ownerId: trip.diverId,
    );
    if (isOwner != true) return null;
    final sharing =
        (session == null ? null : tripSharing.inSitting(session)) ??
        ref
            .watch(
              itemSharingProvider((kind: SharedItemKind.trip, id: trip.id)),
            )
            .value;
    if (sharing == null || !sharing.isShared) return null;
    return _HeaderItem(
      icon: Icons.people_outline,
      label: context.l10n.sharedItems_sharedWith_label,
      value: sharingSummary(sharing, {
        for (final d in divers) d.id: d.name,
      }, context.l10n),
    );
  }
}

/// One value of the header block's line: its icon and its value, read out
/// with its [label], which the line leaves out to stay compact.
class _HeaderItem extends StatelessWidget {
  const _HeaderItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          // Two lines at most: the line stays compact, and the whole value
          // is in the label and the editor.
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The icon a trip type is drawn with.
IconData tripTypeIcon(TripType type) => switch (type) {
  TripType.shore => Icons.beach_access,
  TripType.liveaboard => Icons.sailing,
  TripType.resort => Icons.hotel,
  TripType.dayTrip => Icons.wb_sunny_outlined,
};

/// A trip type's name.
String tripTypeName(AppLocalizations l10n, TripType type) => switch (type) {
  TripType.shore => l10n.trips_type_shore,
  TripType.liveaboard => l10n.trips_type_liveaboard,
  TripType.resort => l10n.trips_type_resort,
  TripType.dayTrip => l10n.trips_type_dayTrip,
};

/// The header block's editor: the trip's type, name, larger trip, dates,
/// return flight, location, resort, the boat's name as older versions kept
/// it, and who it is shared with, with the form's rules. At its full
/// height, in the Overview's own scroll.
class TripHeaderCardEditor extends ConsumerStatefulWidget {
  const TripHeaderCardEditor({super.key, required this.session});

  final EditSession<Trip> session;

  @override
  ConsumerState<TripHeaderCardEditor> createState() =>
      _TripHeaderCardEditorState();
}

class _TripHeaderCardEditorState extends ConsumerState<TripHeaderCardEditor> {
  EditSession<Trip> get _session => widget.session;

  late final _name = _bind(tripNameField);
  late final _location = _bindOptional(tripLocationField);
  late final _resort = _bindOptional(tripResortField);
  late final _boat = _bindOptional(tripLiveaboardNameField);

  FieldTextBinding<Trip, String> _bind(EditField<Trip, String> field) =>
      FieldTextBinding.plain(session: _session, field: field, format: (v) => v);

  FieldTextBinding<Trip, String?> _bindOptional(
    EditField<Trip, String?> field,
  ) => FieldTextBinding.plain(
    session: _session,
    field: field,
    format: (v) => v ?? '',
  );

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSession);
  }

  void _onSession() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    _name.dispose();
    _location.dispose();
    _resort.dispose();
    _boat.dispose();
    super.dispose();
  }

  TripDates get _dates => _session.valueOf(tripDatesField);

  Future<void> _pickStart() async {
    final dates = _dates;
    final picked = await showAppDatePicker(
      context: context,
      initialDate: dates.start,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    _session.set(
      tripDatesField,
      tripStartPicked(
        picked,
        end: dates.end,
        type: _session.valueOf(tripTypeField),
      ),
    );
  }

  Future<void> _pickEnd() async {
    final dates = _dates;
    // As the form's did: a new trip's end is a placeholder until the diver
    // picks one (or a draft gives one), so the picker opens at the start; a
    // stored trip's end is the trip's own, and it opens there.
    final placeholder = _session.isNew && dates.end == _session.stored.endDate;
    final picked = await showAppDatePicker(
      context: context,
      initialDate: placeholder || dates.end.isBefore(dates.start)
          ? dates.start
          : dates.end,
      firstDate: dates.start,
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    _session.set(tripDatesField, (start: dates.start, end: picked));
  }

  Future<void> _pickReturnFlight() async {
    final end = _dates.end;
    final initial =
        _session.valueOf(tripReturnFlightField) ??
        DateTime(end.year, end.month, end.day, 12);
    final pickedDate = await showAppDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null || !mounted) return;
    _session.set(
      tripReturnFlightField,
      tripReturnFlightAt(pickedDate, pickedTime),
    );
  }

  /// "Shared with", as the form offered it: only with two or more divers
  /// (the field hides itself otherwise), and locked while the profile, or
  /// the sharing, is not known yet, and to anyone but the owner.
  Widget? _sharingField() {
    final loaded = tripSharing.loaded(_session);
    final unread = tripSharing.unread(_session);
    if (loaded == null && !unread) return null;
    final stored = _session.stored;
    final current = tripSharing.inSitting(_session) ?? ItemSharing.none;
    final activeDiver = ref.watch(validatedCurrentDiverIdProvider);
    return ItemSharingField(
      kind: SharedItemKind.trip,
      value: current,
      original: loaded ?? ItemSharing.none,
      mayShare: unread
          ? null
          : canDestroySharedItemOnceKnown(activeDiver, ownerId: stored.diverId),
      ownerId: stored.diverId ?? activeDiver.value,
      itemName: _session.working.name,
      onChanged: (next) => tripSharing.set(
        _session,
        next,
        // The profile acting now, which the repository checks.
        actingDiverId: ref.read(validatedCurrentDiverIdProvider).value,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final type = _session.valueOf(tripTypeField);
    final dates = _dates;
    final endLocked = tripEndLocked(type, dates);
    final returnFlight = _session.valueOf(tripReturnFlightField);
    // One level deep: a trip with side trips of its own cannot be one
    // (issue #3658).
    final hasSideTrips =
        ref.watch(hasSideTripsProvider(_session.stored.id)).value ?? false;
    final nameBlank = !tripNameValid(_name.controller.text);
    final sharing = _sharingField();
    // At its full height: the page around it scrolls, so a scroll window
    // of its own would leave its last fields out of reach.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<TripType>(
          key: const Key('trip-edit-type'),
          // Four types across a card on a phone: the check and the
          // usual padding would wrap "Liveaboard" over two lines.
          showSelectedIcon: false,
          style: const ButtonStyle(
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 4),
            ),
          ),
          segments: [
            for (final t in [
              TripType.shore,
              TripType.liveaboard,
              TripType.resort,
              TripType.dayTrip,
            ])
              ButtonSegment(value: t, label: Text(tripTypeName(l10n, t))),
          ],
          selected: {type},
          onSelectionChanged: (selected) {
            final next = selected.first;
            _session
              ..set(tripTypeField, next)
              ..set(tripDatesField, tripTypePicked(next, _dates));
          },
        ),
        const SizedBox(height: 8),
        // Says what each type is for (#2625).
        Text(
          tripTypeDescription(l10n, type),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('trip-edit-name'),
          controller: _name.controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.trips_edit_label_tripName,
            prefixIcon: const Icon(Icons.flight_takeoff),
            hintText: l10n.trips_edit_hint_tripName,
            errorText: nameBlank
                ? l10n.trips_edit_validation_nameRequired
                : null,
          ),
        ),
        if (!hasSideTrips) ...[
          const SizedBox(height: 8),
          PartOfTripField(
            tripId: _session.stored.id,
            value: _session.valueOf(tripParentField),
            onChanged: (id) => _session.set(tripParentField, id),
          ),
        ],
        const SizedBox(height: 8),
        ListTile(
          key: const Key('trip-edit-start'),
          leading: const Icon(Icons.calendar_today),
          title: Text(l10n.trips_edit_label_startDate),
          subtitle: Text(units.formatDate(dates.start)),
          onTap: _pickStart,
          contentPadding: EdgeInsets.zero,
          trailing: const Icon(Icons.edit),
        ),
        // Locked on a one-day Day Trip.
        ListTile(
          key: const Key('trip-edit-end'),
          leading: const Icon(Icons.event),
          title: Text(l10n.trips_edit_label_endDate),
          subtitle: Text(units.formatDate(dates.end)),
          enabled: !endLocked,
          onTap: endLocked ? null : _pickEnd,
          contentPadding: EdgeInsets.zero,
          trailing: Icon(endLocked ? Icons.lock_outline : Icons.edit),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 40),
          child: Text(
            // Calendar days, as the itinerary counts them.
            l10n.trips_edit_durationDays(
              calendarDaysBetween(dates.start, dates.end) + 1,
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        // The return flight drives the no-fly countdown.
        ListTile(
          key: const Key('trip-edit-return-flight'),
          leading: const Icon(Icons.flight_land),
          title: Text(l10n.trips_edit_label_returnFlight),
          subtitle: Text(
            returnFlight == null
                ? l10n.trips_edit_returnFlightNotSet
                // The diver's time format, not the platform's (#1512).
                : '${units.formatDate(returnFlight)}, '
                      '${units.formatTime(returnFlight)}',
          ),
          trailing: returnFlight == null
              ? const Icon(Icons.edit)
              : IconButton(
                  tooltip: l10n.trips_edit_returnFlightClear,
                  icon: const Icon(Icons.clear),
                  onPressed: () => _session.set(tripReturnFlightField, null),
                ),
          contentPadding: EdgeInsets.zero,
          onTap: _pickReturnFlight,
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('trip-edit-location'),
          controller: _location.controller,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.trips_edit_label_location,
            prefixIcon: const Icon(Icons.place),
            hintText: l10n.trips_edit_hint_location,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('trip-edit-resort'),
          controller: _resort.controller,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.trips_edit_label_resortName,
            prefixIcon: const Icon(Icons.hotel),
            hintText: l10n.trips_edit_hint_resortName,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('trip-edit-liveaboard-name'),
          controller: _boat.controller,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.trips_edit_label_liveaboardName,
            prefixIcon: const Icon(Icons.sailing),
            hintText: l10n.trips_edit_hint_liveaboardName,
          ),
        ),
        if (sharing != null) ...[const SizedBox(height: 8), sharing],
      ],
    );
  }
}
