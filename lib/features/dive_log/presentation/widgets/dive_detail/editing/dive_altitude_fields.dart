import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
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

/// Looks the altitude up when the sitting has none, and sets it.
///
/// The dive's own GPS comes first, then its site's stored altitude, then a
/// lookup of the site's coordinates ([AltitudeResolver]). When that last one
/// is what answered, the altitude belongs on the site as well: the write is
/// held on [session] and made by [writeSiteAltitude] when the sitting is
/// saved, so cancelling leaves the site as it was.
///
/// It never replaces an altitude: one set before the call, or typed while
/// the lookup ran, stays. A result that arrives after the sitting ended, or
/// after [stillWanted] turned false, is dropped. A lookup that fails changes
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

  if (session.isDisposed || !(stillWanted?.call() ?? true)) return;
  final meters = resolution.altitudeMeters;
  if (meters == null || session.valueOf(diveAltitudeField) != null) return;

  session.set(diveAltitudeField, meters);
  final writeBack = resolution.siteAltitudeWriteBack;
  if (writeBack != null) {
    session.holdWrite(
      'siteAltitude:${writeBack.siteId}',
      () => writeSiteAltitude(writeBack.siteId, writeBack.altitudeMeters),
    );
  }
}
