import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_labels.dart';

/// A mix as the board shows it. Air is a word and is translated; nitrox and
/// trimix keep their international notation (EAN32, Tx 21/35).
String tripCylinderMixLabel(AppLocalizations l10n, GasMix mix) =>
    mix.isAir ? l10n.trips_cylinders_mixAir : mix.name;

String tripCylinderStatusLabel(
  AppLocalizations l10n,
  TripCylinderStatus status,
) => switch (status) {
  TripCylinderStatus.full => l10n.trips_cylinders_status_full,
  TripCylinderStatus.partial => l10n.trips_cylinders_status_partial,
  TripCylinderStatus.empty => l10n.trips_cylinders_status_empty,
  TripCylinderStatus.unknown => l10n.trips_cylinders_status_unknown,
};

/// The status dot's colour. Always shown beside the status word, never
/// alone, so the colour is a cue and not the only signal.
Color tripCylinderStatusColor(ColorScheme scheme, TripCylinderStatus status) =>
    switch (status) {
      TripCylinderStatus.full => scheme.primary,
      TripCylinderStatus.partial => scheme.tertiary,
      TripCylinderStatus.empty => scheme.error,
      TripCylinderStatus.unknown => scheme.outline,
    };

/// Tells the diver that a cylinder change did not go through (a delete or a
/// reorder), so a failure is never silent.
void showTripCylinderChangeFailed(BuildContext context) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.common_error_tryAgain)));
}

typedef TripCylinderCounts = ({int full, int partial, int empty, int unknown});

TripCylinderCounts tripCylinderCounts(Iterable<TripCylinderState> states) {
  var full = 0, partial = 0, empty = 0, unknown = 0;
  for (final s in states) {
    switch (s.status) {
      case TripCylinderStatus.full:
        full++;
      case TripCylinderStatus.partial:
        partial++;
      case TripCylinderStatus.empty:
        empty++;
      case TripCylinderStatus.unknown:
        unknown++;
    }
  }
  return (full: full, partial: partial, empty: empty, unknown: unknown);
}

/// The slot's last timeline item in words: where it was filled, when it
/// was adjusted, or where it was dived. [centerNames] maps dive center ids
/// to names; a center that is gone or unknown reads as no station. Null for
/// a slot with no history.
String? tripCylinderLastItemText(
  AppLocalizations l10n,
  UnitFormatter units,
  TripCylinderState state, {
  Map<String, String> centerNames = const {},
}) {
  final at = state.lastEventAt;
  if (at == null) return null;
  final when = units.formatDateTime(at, l10n: l10n);
  final use = state.lastUse;
  if (use != null) {
    final site = use.siteName;
    return site == null || site.isEmpty
        ? l10n.trips_cylinders_last_dive(when)
        : l10n.trips_cylinders_last_diveAt(site, when);
  }
  final event = state.lastEvent;
  if (event == null) return null;
  switch (event.kind) {
    case TripCylinderEventKind.fill:
      final place = centerNames[event.diveCenterId];
      return place == null
          ? l10n.trips_cylinders_last_fill(when)
          : l10n.trips_cylinders_last_fillAt(place, when);
    case TripCylinderEventKind.adjustment:
      return l10n.trips_cylinders_last_adjustment(when);
  }
}

/// A linked dive tank's slot in words: "Truck 2 · Bottle 14". The bottle is
/// left out when unknown or when it is the slot's own label (an owned
/// cylinder keeps its identifier as both).
String tripCylinderTankLine(
  AppLocalizations l10n,
  TripCylinderTankLabel label,
) {
  final bottle = label.bottle;
  return bottle == null || bottle == label.label
      ? label.label
      : '${label.label} · ${l10n.trips_cylinders_bottle(bottle)}';
}

/// A slot as the tank editor's picker lists it: label, status, mix,
/// pressure, then the bottle in it. The status leads because a narrow
/// picker ellipsizes the end, and the status is what the diver chooses by.
String tripCylinderPickerLabel(
  AppLocalizations l10n,
  UnitFormatter units,
  TripCylinderState state,
) {
  final bottle = state.bottleLabel;
  return [
    state.cylinder.label,
    tripCylinderStatusLabel(l10n, state.status),
    state.mix == null ? '--' : tripCylinderMixLabel(l10n, state.mix!),
    state.pressure == null ? '--' : units.formatPressure(state.pressure),
    if (bottle != state.cylinder.label) l10n.trips_cylinders_bottle(bottle),
  ].join(' · ');
}
