import 'package:flutter/foundation.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_equipment_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_set_use.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_rules.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_weights_fields.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/services/equipment_set_selector.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _log = LoggerService('DiveGearGeofence');

/// What the last site's location set left, for the next site to take back.
const _appliedKey = 'geofenceApplied';
const _suggestionKey = 'geofenceSuggestion';
const _dismissedKey = 'geofenceDismissed';

/// The latest lookup, which the next one waits for, and its token.
const _lookupKey = 'geofenceLookup';
const _lookupTokenKey = 'geofenceLookupToken';

/// The location set the sitting suggests, as something to listen to: the
/// suggestion arrives after a lookup, and the Equipment card shows it
/// whether open or closed. Made on first use; dropped with the sitting.
ValueListenable<EquipmentSet?> geofenceSuggestionListenable(
  EditSession<Dive> session,
) => _suggestion(session);

ValueNotifier<EquipmentSet?> _suggestion(EditSession<Dive> session) {
  final kept = session.recall<ValueNotifier<EquipmentSet?>>(_suggestionKey);
  if (kept != null) return kept;
  final made = ValueNotifier<EquipmentSet?>(null);
  session.remember(_suggestionKey, made);
  return made;
}

/// The set the sitting suggests for its site, or null.
EquipmentSet? geofenceSuggestion(EditSession<Dive> session) =>
    _suggestion(session).value;

/// The diver turned the suggestion down: that set is not suggested again
/// in this sitting.
void dismissGeofenceSuggestion(EditSession<Dive> session) {
  final set = geofenceSuggestion(session);
  if (set == null) return;
  session.remember(_dismissedKey, {..._dismissed(session), set.id});
  _suggestion(session).value = null;
}

/// The suggestion was taken: it goes, and is not offered again.
void geofenceSuggestionUsed(EditSession<Dive> session) =>
    dismissGeofenceSuggestion(session);

Set<String> _dismissed(EditSession<Dive> session) =>
    session.recall<Set<String>>(_dismissedKey) ?? const {};

/// Where the dive was: its site, and its own entry and exit.
List<GeoPoint> _divePoints(Dive dive) => [
  ?dive.site?.location,
  ?dive.entryLocation,
  ?dive.exitLocation,
];

/// After the dive's site changed in [session] (issue #4527, plan 5): what the
/// previous site's location set applied (gear, weights, cylinders) is taken
/// back where it is still as the set left it, the suggestion goes, and the
/// location sets are asked again, as the old dive form did: a dive with no gear
/// gets the best set, applied without asking or overwriting; one with gear is
/// offered the matching set when it is not dismissed and brings an item the
/// dive lacks.
///
/// Called by whoever puts a site on the sitting (`readDiveSiteAssigner`),
/// so the site rules stay free of gear. Lookups run one after another: one
/// still putting its set on when the site changes again stops, what it put
/// on is taken back, and only then is the next site looked up. A lookup is
/// dropped when a later one has started, when the site has changed, or when
/// the sitting ended or is being saved. Tracked.
void reevaluateGearForSite(
  EditSession<Dive> session, {
  required ProviderRead read,
}) {
  if (session.isDisposed || session.isFrozen) return;
  _takeBack(session);
  _suggestion(session).value = null;
  final siteId = session.working.site?.id;
  // Its own token, so a lookup for A started before the site went to B and
  // back to A is not taken for this one.
  final token = Object();
  final previous = session.recall<Future<void>>(_lookupKey);
  session.remember(_lookupTokenKey, token);
  bool stillWanted() =>
      !session.isDisposed &&
      !session.isFrozen &&
      identical(session.recall<Object>(_lookupTokenKey), token) &&
      session.working.site?.id == siteId;
  final run = _lookUp(session, read, previous, stillWanted);
  session
    ..remember(_lookupKey, run)
    ..track(run);
}

Future<void> _lookUp(
  EditSession<Dive> session,
  ProviderRead read,
  Future<void>? previous,
  bool Function() stillWanted,
) async {
  // The previous lookup's failure was its own to log.
  if (previous != null) await previous.then((_) {}, onError: (_) {});
  if (session.isDisposed || session.isFrozen) return;
  // What the previous lookup put on after this site was picked.
  _takeBack(session);
  if (!stillWanted()) return;
  final EquipmentSetSelectionInputs inputs;
  try {
    inputs = await read(equipmentSetSelectionInputsProvider.future);
  } catch (error, stackTrace) {
    // Sets unavailable: no location set this time.
    _log.warning(
      'Reading the location sets failed',
      error: error,
      stackTrace: stackTrace,
    );
    return;
  }
  if (!stillWanted()) return;
  final points = _divePoints(session.working);
  final gear = session.valueOf(diveGearField);
  if (gear.isEmpty) {
    final best = EquipmentSetSelector.bestSetFor(
      divePoints: points,
      sets: inputs.sets,
      geofences: inputs.geofences,
    );
    final items = best?.items ?? const <EquipmentItem>[];
    if (best == null || (items.isEmpty && !best.carriesBeyondGear)) return;
    final before = setUseCardsOf(session);
    await useSetInSitting(
      session,
      best,
      items,
      read: read,
      auto: true,
      stillWanted: stillWanted,
    );
    if (session.isDisposed || session.isFrozen) return;
    // Remembered even when the site changed meanwhile and the use stopped
    // part way: the next lookup takes back whatever it put on.
    session.remember(
      _appliedKey,
      _Applied(
        SetUseResult(before: before, after: setUseCardsOf(session)),
        revisions: _revisionsOf(session),
      ),
    );
    return;
  }
  final match = EquipmentSetSelector.matchingGeofenceSet(
    divePoints: points,
    sets: inputs.sets,
    geofences: inputs.geofences,
  );
  if (match == null || _dismissed(session).contains(match.id)) return;
  final onDive = {for (final link in gear) link.item.id};
  final bringsNew = (match.items ?? const <EquipmentItem>[]).any(
    (item) => !onDive.contains(item.id),
  );
  if (bringsNew) _suggestion(session).value = match;
}

/// What a location set left, with how often its three values had been
/// changed by then ([EditSession.fieldRevisionOf]).
@immutable
class _Applied {
  const _Applied(this.result, {required this.revisions});

  final SetUseResult result;
  final ({int gear, int weights, int tanks}) revisions;
}

({int gear, int weights, int tanks}) _revisionsOf(EditSession<Dive> session) =>
    (
      gear: session.fieldRevisionOf(diveGearField.id),
      weights: session.fieldRevisionOf(diveWeightsField.id),
      tanks: session.fieldRevisionOf(diveTanksField.id),
    );

/// What the last location set applied goes back, value by value, where it
/// is still as the set left it and nothing has changed it since: a value
/// the diver changed is theirs, even one changed back to the set's.
void _takeBack(EditSession<Dive> session) {
  final applied = session.recall<_Applied>(_appliedKey);
  if (applied == null) return;
  session.remember(_appliedKey, null);
  final before = applied.result.before;
  final after = applied.result.after;
  final now = _revisionsOf(session);
  if (now.gear == applied.revisions.gear &&
      diveGearField.same(session.valueOf(diveGearField), after.gear)) {
    session.set(diveGearField, before.gear);
  }
  if (now.weights == applied.revisions.weights &&
      diveWeightsField.same(session.valueOf(diveWeightsField), after.weights)) {
    session.set(diveWeightsField, before.weights);
  }
  if (now.tanks == applied.revisions.tanks &&
      diveTanksField.same(session.valueOf(diveTanksField), after.tanks)) {
    setTanks(session, before.tanks, replaced: true);
  }
}
