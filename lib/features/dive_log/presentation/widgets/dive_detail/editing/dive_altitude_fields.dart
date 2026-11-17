import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/weather/domain/services/altitude_resolver.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _log = LoggerService('DiveAltitudeFields');

/// The dive's altitude in metres, edited on the Altitude card.
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

/// Looks the altitude up when the sitting has none, and sets it.
///
/// The dive's own GPS comes first, then its site's stored altitude, then a
/// lookup of the site's coordinates ([AltitudeResolver]). When that last one
/// is what answered, the altitude belongs on the site as well: the write is
/// held on [session] and made by [writeSiteAltitude] when the sitting is
/// saved, so cancelling leaves the site as it was. It is made only if the
/// dive still has that altitude by then, and [writeSiteAltitude] is the
/// write that keeps an altitude the site gained meanwhile
/// (`SiteRepository.fillSiteAltitudeIfEmpty`).
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

  session.set(diveAltitudeField, meters);
  session.remember(altitudeFillNoteKey, (siteId: asked.siteId, meters: meters));
  final writeBack = resolution.siteAltitudeWriteBack;
  if (writeBack != null) {
    session.holdWrite(siteAltitudeWriteKey(writeBack.siteId), () async {
      // Asked as the sitting is saved: a diver who has since typed another
      // altitude, or taken this one out, has not accepted the lookup, and
      // the site must not be given it.
      if (session.valueOf(diveAltitudeField) != meters) return;
      await writeSiteAltitude(writeBack.siteId, writeBack.altitudeMeters);
    });
  }
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
