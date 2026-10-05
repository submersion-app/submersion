import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';
import 'package:submersion/features/import_wizard/data/adapters/cloud_computer_identity.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';

/// Writes a Suunto dive's recorded route (issue #1445) onto the dive it was
/// imported with, for both the Suunto Cloud and the Suunto JSON file
/// import.
///
/// The dive is already saved when this runs, so a failure is logged and
/// swallowed: losing the route must never fail the import or stop the
/// dives after this one.
class SuuntoRouteWriter {
  SuuntoRouteWriter({NavTrackRepository? repository})
    : _repository = repository ?? NavTrackRepository();

  static final _log = LoggerService.forClass(SuuntoRouteWriter);

  final NavTrackRepository _repository;

  /// A key that is the same every time the same dive is imported: the
  /// device (serial, else model name) and the dive's start.
  static String sourceRefFor(SuuntoParsedDive parsed) {
    final device =
        normalizedIdentityPart(parsed.serialNumber) ??
        normalizedIdentityPart(parsed.deviceName) ??
        'unknown';
    return 'suunto:$device:${parsed.dive.startTime.toIso8601String()}';
  }

  /// Links [parsed]'s route to [diveId]. A Suunto route from an earlier
  /// import of the same dive is replaced (handing over its primary role)
  /// rather than duplicated. Returns the new route id, or null when there
  /// is no route or the write failed.
  Future<String?> attach(String diveId, SuuntoParsedDive parsed) async {
    final route = parsed.route;
    if (route == null) return null;
    try {
      final sourceRef = sourceRefFor(parsed);
      final previous = [
        for (final r in await _repository.getForDive(diveId))
          if (r.source == NavTrackSource.suuntoRoute &&
              r.sourceRef == sourceRef)
            r.id,
      ];
      final id = await _repository.insertImportedRoute(
        points: route.points,
        source: NavTrackSource.suuntoRoute,
        sourceRef: sourceRef,
        deviceName: parsed.deviceName,
        diveId: diveId,
        anchorLatitude: route.originLatitude,
        anchorLongitude: route.originLongitude,
      );
      for (final oldId in previous) {
        await _repository.replace(oldId, withRouteId: id);
      }
      return id;
    } catch (e, st) {
      _log.error(
        'Could not attach the Suunto route to dive $diveId',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Links [parsed]'s route to [diveId] only when that dive has no Suunto
  /// route yet: the backfill for a duplicate the diver chose to skip, so a
  /// dive imported before routes were read still gains its route without
  /// its own data being touched. Returns the new route id, or null when
  /// nothing was linked.
  Future<String?> attachIfMissing(
    String diveId,
    SuuntoParsedDive parsed,
  ) async {
    if (parsed.route == null) return null;
    try {
      final existing = await _repository.getForDive(diveId);
      if (existing.any((r) => r.source == NavTrackSource.suuntoRoute)) {
        return null;
      }
    } catch (e, st) {
      _log.error(
        'Could not check dive $diveId for a Suunto route',
        error: e,
        stackTrace: st,
      );
      return null;
    }
    return attach(diveId, parsed);
  }
}
