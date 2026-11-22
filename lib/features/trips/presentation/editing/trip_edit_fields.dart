import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';

/// The trip page's values a sitting edits, and the rules the trip form
/// kept (issue #4527, phase 3).

final String _header = TripCardId.header.name;
final String _plan = TripCardId.plan.name;
final String _notes = TripCardId.notes.name;

/// A trip's first and last day, edited as one value: a start that pulls
/// the end along is one change.
typedef TripDates = ({DateTime start, DateTime end});

/// A blank optional value is stored as none, as the form stored it.
String? _orNone(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

bool _sameText(String? a, String? b) => _orNone(a) == _orNone(b);

/// A whole number above zero, or null for none and for zero or below, as
/// the form stored its planning numbers: zero or a negative is not a plan.
int? tripPositiveOrNull(num? value) =>
    value != null && value > 0 ? value.toInt() : null;

/// The trip's name, required, shown in the bar and edited on the header.
final tripNameField = EditField<Trip, String>(
  id: 'name',
  cardId: _header,
  read: (t) => t.name,
  write: (t, v) => t.copyWith(name: v.trim()),
  equals: (a, b) => a.trim() == b.trim(),
);

final tripTypeField = EditField<Trip, TripType>(
  id: 'tripType',
  cardId: _header,
  read: (t) => t.tripType,
  write: (t, v) => t.copyWith(tripType: v),
);

final tripDatesField = EditField<Trip, TripDates>(
  id: 'dates',
  cardId: _header,
  read: (t) => (start: t.startDate, end: t.endDate),
  write: (t, v) => t.copyWith(startDate: v.start, endDate: v.end),
);

/// When the diver flies home, as wall-clock-as-UTC ([tripReturnFlightAt]).
final tripReturnFlightField = EditField<Trip, DateTime?>(
  id: 'returnFlightAt',
  cardId: _header,
  read: (t) => t.returnFlightAt,
  write: (t, v) => t.copyWith(returnFlightAt: v),
);

/// The larger trip this one is a side trip of (issue #3658).
final tripParentField = EditField<Trip, String?>(
  id: 'parentTripId',
  cardId: _header,
  read: (t) => t.parentTripId,
  write: (t, v) => t.copyWith(parentTripId: v),
);

final tripLocationField = EditField<Trip, String?>(
  id: 'location',
  cardId: _header,
  read: (t) => t.location,
  write: (t, v) => t.copyWith(location: _orNone(v)),
  equals: _sameText,
);

final tripResortField = EditField<Trip, String?>(
  id: 'resortName',
  cardId: _header,
  read: (t) => t.resortName,
  write: (t, v) => t.copyWith(resortName: _orNone(v)),
  equals: _sameText,
);

/// The boat's name as older versions kept it on the trip; the Vessel card
/// holds the liveaboard's details.
final tripLiveaboardNameField = EditField<Trip, String?>(
  id: 'liveaboardName',
  cardId: _header,
  read: (t) => t.liveaboardName,
  write: (t, v) => t.copyWith(liveaboardName: _orNone(v)),
  equals: _sameText,
);

/// A planning number held as the number row's value: zero or below stores
/// none.
EditField<Trip, double?> _planNumber(
  String id,
  int? Function(Trip) read,
  Trip Function(Trip, int?) write,
) => EditField<Trip, double?>(
  id: id,
  cardId: _plan,
  read: (t) => read(t)?.toDouble(),
  write: (t, v) => write(t, tripPositiveOrNull(v)),
  equals: (a, b) => tripPositiveOrNull(a) == tripPositiveOrNull(b),
);

final tripDivesPerDayField = _planNumber(
  'divesPerDayTarget',
  (t) => t.divesPerDayTarget,
  (t, v) => t.copyWith(divesPerDayTarget: v),
);

final tripExpectedDivesField = _planNumber(
  'expectedDives',
  (t) => t.expectedDives,
  (t, v) => t.copyWith(expectedDives: v),
);

final tripExpectedRuntimeField = _planNumber(
  'expectedRuntimeMinutes',
  (t) => t.expectedRuntimeMinutes,
  (t, v) => t.copyWith(expectedRuntimeMinutes: v),
);

/// Who breathes from the trip's cylinders: blank, zero or below is one.
final tripDiversSharingField = EditField<Trip, double?>(
  id: 'diversSharingCylinders',
  cardId: _plan,
  read: (t) => t.diversSharingCylinders.toDouble(),
  write: (t, v) =>
      t.copyWith(diversSharingCylinders: tripPositiveOrNull(v) ?? 1),
  equals: (a, b) =>
      (tripPositiveOrNull(a) ?? 1) == (tripPositiveOrNull(b) ?? 1),
);

/// The notes, day passages included. Trimmed at Save, as the form saved
/// them.
final tripNotesField = EditField<Trip, String>(
  id: 'notes',
  cardId: _notes,
  read: (t) => t.notes,
  write: (t, v) => t.copyWith(notes: v.trim()),
  equals: (a, b) => a.trim() == b.trim(),
);

/// Whether [name] can be saved.
bool tripNameValid(String name) => name.trim().isNotEmpty;

/// The dates after the diver picks [start]: a Day trip keeps its end on its
/// start, and a start after the end pulls the end with it.
TripDates tripStartPicked(
  DateTime start, {
  required DateTime end,
  required TripType type,
}) => (
  start: start,
  end: type == TripType.dayTrip || start.isAfter(end) ? start : end,
);

/// The dates after the diver picks [type]: a Day trip is one calendar day,
/// and leaving one leaves the dates for the diver to widen.
TripDates tripTypePicked(TripType type, TripDates dates) =>
    type == TripType.dayTrip ? (start: dates.start, end: dates.start) : dates;

/// Whether the end date is locked to the start: a Day trip of one calendar
/// day. A Day trip stored over several days keeps its end editable, so the
/// row never locks on a range it contradicts.
bool tripEndLocked(TripType type, TripDates dates) =>
    type == TripType.dayTrip &&
    calendarDaysBetween(dates.start, dates.end) == 0;

/// The return flight picked as [date] at [time]: wall-clock-as-UTC, the
/// same frame as dive times, so the no-fly arithmetic reads it the way it
/// reads dive end times.
DateTime tripReturnFlightAt(DateTime date, TimeOfDay time) =>
    DateTime.utc(date.year, date.month, date.day, time.hour, time.minute);

/// What each trip type is for, so a diver with a single local dive learns
/// that Day Trip is its home (#2625).
String tripTypeDescription(AppLocalizations l10n, TripType type) =>
    switch (type) {
      TripType.shore => l10n.trips_type_description_shore,
      TripType.liveaboard => l10n.trips_type_description_liveaboard,
      TripType.resort => l10n.trips_type_description_resort,
      TripType.dayTrip => l10n.trips_type_description_dayTrip,
    };
