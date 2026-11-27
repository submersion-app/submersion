import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/weather/domain/services/altitude_resolver.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _log = LoggerService('DiveAltitudeFields');

/// The dive's own altitude in metres, edited on the Altitude card. A dive
/// with none reads its site's (`Dive.effectiveAltitude`, issue #5040), which
/// the card shows as the field's placeholder ([siteAltitudeOf]).
final diveAltitudeField = EditField<Dive, double?>(
  id: 'altitude',
  cardId: DiveDetailSectionId.altitude.name,
  read: (dive) => dive.altitude,
  write: (dive, value) =>
      dive.copyWith(altitude: value, clearAltitude: value == null),
);

/// The surface pressure in bar, edited on the Altitude card. The Environment
/// card shows it too, and the weather fetch can fill it.
final diveSurfacePressureField = EditField<Dive, double?>(
  id: 'surfacePressure',
  cardId: DiveDetailSectionId.altitude.name,
  alsoShownOn: {DiveDetailSectionId.environment.name},
  read: (dive) => dive.surfacePressure,
  write: (dive, value) => dive.copyWith(
    surfacePressure: value,
    clearSurfacePressure: value == null,
  ),
);

/// The key the copy of a looked-up altitude to [siteId] is held under, so
/// that picking another site can release it (`releaseWrite`).
String siteAltitudeWriteKey(String siteId) => 'siteAltitude:$siteId';

/// The note of the altitude a lookup set in this sitting, and for which
/// site: `({String? siteId, double meters})`. A change of site takes that
/// altitude back, while the diver has not changed it since.
const String altitudeFillNoteKey = 'altitudeFill';

/// The note of an altitude a lookup of the site's coordinates found in this
/// sitting, for the site to be given when the sitting is saved:
/// `({String siteId, double meters})`.
const String _siteAltitudeLookupNoteKey = 'siteAltitudeLookup';

/// The altitude of the dive's site in [session]: the one it has, else one
/// a lookup in this sitting found for it and the save will give it. What a
/// dive with no altitude of its own reads (issue #5040).
double? siteAltitudeOf(EditSession<Dive> session) {
  final site = session.working.site;
  if (site == null) return null;
  if (site.altitude != null) return site.altitude;
  if (session.isDisposed) return null;
  final found = session.recall<({String siteId, double meters})>(
    _siteAltitudeLookupNoteKey,
  );
  return found?.siteId == site.id ? found!.meters : null;
}

/// [dive] with its site carrying the altitude a lookup in [session] found
/// for it, while the site has none: what the dive page draws, so the
/// Altitude card shows a looked-up altitude before the save gives it to the
/// site (issue #5040). [dive] as it is otherwise.
Dive withLookedUpSiteAltitude(EditSession<Dive>? session, Dive dive) {
  final site = dive.site;
  if (session == null || session.isDisposed) return dive;
  if (site == null || site.altitude != null) return dive;
  final found = session.recall<({String siteId, double meters})>(
    _siteAltitudeLookupNoteKey,
  );
  if (found == null || found.siteId != site.id) return dive;
  return dive.copyWith(site: site.copyWith(altitude: found.meters));
}

/// The altitude the dive in [session] is at: its own, else its site's.
double? effectiveAltitudeOf(EditSession<Dive> session) =>
    session.valueOf(diveAltitudeField) ?? siteAltitudeOf(session);

/// Looks the altitude up when the sitting has none.
///
/// The dive's own GPS comes first, then its site's stored altitude, then a
/// lookup of the site's coordinates ([AltitudeResolver]). Only the first is
/// the dive's own, and set on it. A site's altitude is read through, not
/// copied (issue #5040): one the site has needs nothing, and one a lookup
/// of its coordinates found belongs on the site. That write is held on
/// [session] as a change of the Altitude card and made by
/// [writeSiteAltitude] when the sitting is saved, so cancelling leaves the
/// site as it was; until then [siteAltitudeOf] shows it. It is made only if
/// the diver has not typed an altitude of their own by then, and
/// [writeSiteAltitude] is the write that keeps an altitude the site gained
/// meanwhile (`SiteRepository.fillSiteAltitudeIfEmpty`).
///
/// It never replaces an altitude: one set before the call, or typed while
/// the lookup ran, stays. A result that arrives after the sitting ended,
/// while it is being saved, after [stillWanted] turned false, or after the
/// dive's locations or site changed, is dropped. A lookup that fails changes
/// nothing.
Future<void> fillAltitudeIfEmpty(
  EditSession<Dive> session, {
  required AltitudeResolver resolver,
  required Future<void> Function(String siteId, double altitudeMeters)
  writeSiteAltitude,
  bool Function()? stillWanted,
}) async {
  if (session.valueOf(diveAltitudeField) != null) return;

  final dive = session.working;
  final asked = _lookupInputs(dive);
  final AltitudeResolution resolution;
  try {
    resolution = await resolver.resolve(
      entryLocation: dive.entryLocation,
      exitLocation: dive.exitLocation,
      site: dive.site,
    );
  } catch (error, stackTrace) {
    // Filling the altitude in is a convenience; the diver can type it.
    _log.warning(
      'Altitude lookup failed',
      error: error,
      stackTrace: stackTrace,
    );
    return;
  }

  // The sitting ended, is being written, or nobody is waiting any more.
  if (session.isDisposed || session.isFrozen) return;
  if (!(stillWanted?.call() ?? true)) return;
  // The dive changed underneath while the lookup ran, a sync bringing in
  // another site, say: what was found is for the dive as it was asked about.
  if (_lookupInputs(session.working) != asked) return;
  final meters = resolution.altitudeMeters;
  if (meters == null || session.valueOf(diveAltitudeField) != null) return;

  if (resolution.isDiveOwn) {
    session.set(diveAltitudeField, meters);
    session.remember(altitudeFillNoteKey, (
      siteId: asked.siteId,
      meters: meters,
    ));
    return;
  }
  final writeBack = resolution.siteAltitudeWriteBack;
  if (writeBack == null) return;
  session.remember(_siteAltitudeLookupNoteKey, (
    siteId: writeBack.siteId,
    meters: writeBack.altitudeMeters,
  ));
  session.holdChange(
    siteAltitudeWriteKey(writeBack.siteId),
    cardId: DiveDetailSectionId.altitude.name,
    write: () async {
      // Asked as the sitting is saved: a diver who has since typed an
      // altitude of their own has not accepted the lookup, and the site
      // must not be given it.
      if (session.valueOf(diveAltitudeField) != null) return;
      await writeSiteAltitude(writeBack.siteId, writeBack.altitudeMeters);
    },
  );
}

/// What an altitude lookup for [dive] is asked about.
({
  GeoPoint? entry,
  GeoPoint? exit,
  String? siteId,
  GeoPoint? site,
  double? siteAltitude,
})
_lookupInputs(Dive dive) => (
  entry: dive.entryLocation,
  exit: dive.exitLocation,
  siteId: dive.site?.id,
  site: dive.site?.location,
  siteAltitude: dive.site?.altitude,
);
