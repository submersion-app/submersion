import 'dart:typed_data';

import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart' as lat_lng_tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:submersion/core/utils/bplist/bplist_decoder.dart';
import 'package:submersion/core/utils/bplist/bplist_object.dart';
import 'package:submersion/features/universal_import/data/services/import_site_location.dart';

/// Converts MacDive's absolute dive times into Submersion's wall-clock-UTC
/// convention.
///
/// MacDive stores a dive's moment as an absolute instant (`ZRAWDATE`) and
/// the zone it was logged in separately (`ZTIMEZONE`, an
/// NSKeyedArchiver-encoded NSTimeZone). Submersion stores the digits the
/// diver saw on their watch as the components of a UTC `DateTime`, so the
/// instant has to be read in the dive's own zone first.
class MacDiveTimeZone {
  const MacDiveTimeZone._();

  /// The zone name (for example `America/Curacao`) archived in a
  /// `ZTIMEZONE` BLOB, or null when the BLOB is missing or unreadable.
  ///
  /// Only the name is used: the archived `NS.data` rules are empty in many
  /// real MacDive rows, while the name is always an IANA identifier.
  static String? nameFromBplist(Uint8List? bplist) {
    if (bplist == null) return null;
    try {
      final archive = BPlistDecoder.decode(bplist).asMap;
      final objects = archive?[r'$objects']?.asList;
      final rootRef = archive?[r'$top']?.asMap?['root'];
      if (objects == null || rootRef is! BPlistUID) return null;
      final zone = _resolve(objects, rootRef)?.asMap;
      final name = zone?['NS.name'];
      if (name == null) return null;
      return _resolve(objects, name)?.asString;
    } on FormatException {
      return null;
    } on RangeError {
      return null;
    }
  }

  /// The zone a dive site lies in, looked up offline from its coordinates,
  /// or null when the site has no usable GPS fix.
  ///
  /// This is the fallback for a dive MacDive saved without a zone. A named
  /// zone rather than a fixed offset, so the dive's date still picks the
  /// right side of a daylight-saving change.
  static String? nameForLocation(double? latitude, double? longitude) {
    final point = ImportSiteLocation.fix(latitude, longitude);
    if (point == null) return null;
    final name = lat_lng_tz.latLngToTimezoneString(
      point.latitude,
      point.longitude,
    );
    return name.isEmpty ? null : name;
  }

  /// [instant] as the wall clock of [zoneName], encoded as UTC components.
  ///
  /// A dive with no zone, or a zone the tz database does not know, falls
  /// back to the device's zone: the same wall clock MacDive itself shows
  /// for such a dive on this machine.
  static DateTime toWallClockUtc(DateTime instant, String? zoneName) {
    final location = _location(zoneName);
    final wall = location == null
        ? instant.toLocal()
        : tz.TZDateTime.from(instant, location);
    return DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
      wall.second,
      wall.millisecond,
      wall.microsecond,
    );
  }

  static tz.Location? _location(String? zoneName) {
    if (zoneName == null || zoneName.isEmpty) return null;
    // The notification service only loads the database on mobile, so the
    // importer cannot rely on it being there.
    if (!tz.timeZoneDatabase.isInitialized) tz_data.initializeTimeZones();
    try {
      return tz.getLocation(zoneName);
    } on tz.LocationNotFoundException {
      return null;
    }
  }

  /// Follows a CFKeyedArchiver UID into the archive's object table;
  /// returns any other object as is.
  static BPlistObject? _resolve(List<BPlistObject> objects, BPlistObject ref) {
    if (ref is! BPlistUID) return ref;
    if (ref.index < 0 || ref.index >= objects.length) return null;
    return objects[ref.index];
  }
}
