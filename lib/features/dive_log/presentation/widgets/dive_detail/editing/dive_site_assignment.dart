import 'dart:async';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/utils/dive_type_autofill.dart';
import 'package:submersion/features/dive_log/presentation/utils/entry_exit_autofill.dart';
import 'package:submersion/features/dive_log/presentation/utils/water_type_autofill.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_environment_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/weather/domain/services/altitude_resolver.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

// Picking a site for a dive in a sitting, and the rules that sets off on the
// other cards (issue #4527). One principle runs through them: what a site
// set, the next site (or clearing it) takes back, unless the diver changed
// it since. A value the dive had before the sitting is never taken back.

const _log = LoggerService('DiveSiteAssignment');

/// The key a location added to [siteId] from the site suggestion is held
/// under, as a change of the header card.
String siteLocationChangeKey(String siteId) => 'siteLocation:$siteId';

const _sitesLocatedKey = 'sitesLocated';

/// Notes that a held write has just stored [point] as the location of
/// [siteId], a site with no altitude, so the altitude is looked up once the
/// save has committed (issue #4527): the lookup goes to the network, and
/// the write runs inside the save's transaction.
void noteSiteLocated(EditSession<Dive> session, String siteId, GeoPoint point) {
  if (session.isDisposed) return;
  session.remember(_sitesLocatedKey, {
    ...sitesLocatedInSave(session),
    siteId: point,
  });
}

/// The sites the last save gave a location ([noteSiteLocated]), by id.
Map<String, GeoPoint> sitesLocatedInSave(EditSession<Dive> session) =>
    session.isDisposed
    ? const {}
    : session.recall<Map<String, GeoPoint>>(_sitesLocatedKey) ?? const {};

/// Forgets what an earlier save, one that did not commit, noted.
void forgetSitesLocated(EditSession<Dive> session) {
  if (!session.isDisposed) session.remember(_sitesLocatedKey, null);
}

/// The key a dismissed site suggestion is held under, as a change of the
/// header card. It is about the dive, so a change of site keeps it.
const String siteSuggestionDismissKey = 'siteSuggestionDismissed';

/// What a site set on one field: the value before and the value it set.
typedef _Snap = ({Object? before, Object? after});

String _snapKey(String fieldId) => 'siteSnap:$fieldId';
const _siteAddedTypesKey = 'siteAddedDiveTypes';
const _exitEditedKey = 'exitEditedDirectly';
const _exitFollowsKey = 'exitFollowsEntry';

/// Puts [site] on the dive in [session] and applies the site's rules to the
/// values other cards own: water type (Details), entry and exit method
/// (Environment), altitude (Altitude) and dive types (Details).
///
/// What the previous site set in this sitting is taken back first, unless
/// the diver changed it since; values the dive had before the sitting are
/// never taken. An altitude a lookup filled for the previous site goes back
/// to what it was before the lookup, which only fills an empty one, and its
/// site write is released, as is a location held for that site.
///
/// [siteDiveTypeIds] and [resolver] run after; each drops its result if the
/// sitting ended, is being saved, or has another site by then. The dive
/// types read is tracked, so a save waits for it; the altitude lookup,
/// which needs the network, is not.
void assignDiveSite(
  EditSession<Dive> session,
  DiveSite? site, {
  required Future<List<String>> Function(String siteId) siteDiveTypeIds,
  required AltitudeResolver resolver,
  required Future<void> Function(String siteId, double altitudeMeters)
  writeSiteAltitude,
}) {
  if (session.isDisposed || session.isFrozen) return;
  final previous = session.valueOf(diveSiteField);
  if (previous?.id == site?.id) return;
  // Whether the exit mirrors the entry is settled before anything moves.
  final edited = session.recall<bool>(_exitEditedKey) ?? false;

  if (previous != null) {
    session
      ..releaseWrite(siteAltitudeWriteKey(previous.id))
      ..releaseWrite(siteLocationChangeKey(previous.id));
  }
  session.set(diveSiteField, site);

  final water = _base(session, diveWaterTypeField);
  _snap(
    session,
    diveWaterTypeField,
    water,
    waterTypeAfterSiteAssign(water, site),
  );

  final entry = _base(session, diveEntryMethodField);
  final exit = _base(session, diveExitMethodField);
  final snapped = entryExitAfterSiteAssign(
    currentEntry: entry,
    currentExit: exit,
    currentLinked: !edited && (exit == null || exit == entry),
    site: site,
  );
  _snap(session, diveEntryMethodField, entry, snapped.entry);
  _snap(session, diveExitMethodField, exit, snapped.exit);
  if (!edited) session.remember(_exitFollowsKey, snapped.linked);

  final filled = session.recall<({String? siteId, double meters})>(
    altitudeFillNoteKey,
  );
  if (filled != null && session.valueOf(diveAltitudeField) == filled.meters) {
    // A lookup fills only an empty altitude, so before it there was none.
    // Not the stored altitude: one the diver cleared must stay cleared.
    session.set(diveAltitudeField, null);
    session.remember(altitudeFillNoteKey, null);
  }
  if (session.valueOf(diveAltitudeField) == null) {
    unawaited(
      fillAltitudeIfEmpty(
        session,
        resolver: resolver,
        writeSiteAltitude: writeSiteAltitude,
      ),
    );
  }

  session.track(_snapDiveTypes(session, site, siteDiveTypeIds));
}

/// The value [field] would have if the previous site had not set it: the
/// value before that site, while the field still holds what it set.
V _base<V>(EditSession<Dive> session, EditField<Dive, V> field) {
  final current = session.valueOf(field);
  final snap = session.recall<_Snap>(_snapKey(field.id));
  if (snap != null && field.same(current, snap.after as V)) {
    return snap.before as V;
  }
  return current;
}

void _snap<V>(
  EditSession<Dive> session,
  EditField<Dive, V> field,
  V before,
  V after,
) {
  session
    ..set(field, after)
    ..remember(_snapKey(field.id), (before: before, after: after));
}

Future<void> _snapDiveTypes(
  EditSession<Dive> session,
  DiveSite? site,
  Future<List<String>> Function(String siteId) read,
) async {
  var siteTypeIds = const <String>[];
  if (site != null) {
    try {
      siteTypeIds = await read(site.id);
    } catch (error, stackTrace) {
      // A convenience: the diver can still set the types by hand.
      _log.warning(
        'Could not read the dive types of site ${site.id}',
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }
  }
  if (session.isDisposed || session.isFrozen) return;
  // Another site was picked while this one was read.
  if (session.valueOf(diveSiteField)?.id != site?.id) return;
  final result = diveTypesAfterSiteAssign(
    currentTypeIds: session.valueOf(diveTypeIdsField),
    previousSiteAddedIds:
        session.recall<Set<String>>(_siteAddedTypesKey) ?? const {},
    siteDiveTypeIds: siteTypeIds,
  );
  session
    ..set(diveTypeIdsField, result.typeIds)
    ..remember(_siteAddedTypesKey, result.siteAddedIds);
}

/// Whether the exit method follows the entry method in [session].
///
/// Settled the first time it is asked in the sitting, from the dive as it
/// is then (`exitFollowsEntry`), so a change arriving underneath later does
/// not link the two. A site that sets the methods settles it again from
/// what it set. Once the diver edits the exit directly it is false for the
/// rest of the sitting, however often the card is opened.
bool exitFollows(EditSession<Dive> session) {
  if (session.recall<bool>(_exitEditedKey) ?? false) return false;
  final settled = session.recall<bool>(_exitFollowsKey);
  if (settled != null) return settled;
  final follows = exitFollowsEntry(session.working);
  session.remember(_exitFollowsKey, follows);
  return follows;
}

/// Call when the diver edits the exit method directly.
void exitEditedDirectly(EditSession<Dive> session) =>
    session.remember(_exitEditedKey, true);

/// Call when the diver sets the dive types by hand: a type a site added
/// that the diver unticks is theirs from then on, even ticked again.
void diveTypesEditedByHand(EditSession<Dive> session, List<String> typeIds) {
  final added = session.recall<Set<String>>(_siteAddedTypesKey);
  if (added == null) return;
  session.remember(
    _siteAddedTypesKey,
    siteAddedAfterManualEdit(siteAddedIds: added, selectedTypeIds: typeIds),
  );
}
