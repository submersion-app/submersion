import 'dart:typed_data';

import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart' as lat_lng_tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:submersion/core/util/time_zone_database.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/core/utils/bplist/bplist_decoder.dart';
import 'package:submersion/core/utils/bplist/bplist_object.dart';
import 'package:submersion/features/universal_import/data/services/import_site_location.dart';
import 'package:submersion/features/universal_import/data/services/macdive_raw_types.dart';

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

  /// `GMT+0100`, `GMT-05:30`: how NSTimeZone names a fixed-offset zone.
  static final _fixedOffsetName = RegExp(
    r'^(?:GMT|UTC)([+-])(\d{1,2})(?::?(\d{2}))?$',
  );

  /// The zone name (for example `America/Curacao`) archived in a
  /// `ZTIMEZONE` BLOB, or null when the BLOB is missing or unreadable.
  ///
  /// Only the name is used: the archived `NS.data` rules are empty in many
  /// real MacDive rows, while the name is always present.
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
      // The decoder reports every kind of malformed stream this way.
      return null;
    }
  }

  /// The zone a dive site lies in, looked up offline from its coordinates,
  /// or null when the site has no usable GPS fix.
  ///
  /// This is the fallback for a dive MacDive saved without a zone. A named
  /// zone rather than a fixed offset, so the dive's date still picks the
  /// right side of a daylight-saving change. Offshore points resolve to the
  /// nearest land zone.
  static String? nameForLocation(double? latitude, double? longitude) {
    final point = ImportSiteLocation.fix(latitude, longitude);
    if (point == null) return null;
    final name = lat_lng_tz.latLngToTimezoneString(
      point.latitude,
      point.longitude,
    );
    return name.isEmpty ? null : name;
  }

  /// The zone called [name]: an IANA zone, or one of the fixed-offset
  /// names NSTimeZone gives a zone made from a GMT offset. Null when the
  /// name is missing or neither, so the caller can try its next source.
  static tz.Location? locationNamed(String? name) {
    if (name == null || name.isEmpty) return null;
    ensureTimeZoneDatabase();
    try {
      return tz.getLocation(name);
    } on tz.LocationNotFoundException {
      return _fixedOffset(name);
    }
  }

  /// [instant] as the wall clock of [location], encoded as UTC components.
  ///
  /// A dive with no zone falls back to the device's zone: the same wall
  /// clock MacDive itself shows for such a dive on this machine.
  static DateTime toWallClockUtc(DateTime instant, tz.Location? location) {
    final wall = location == null
        ? instant.toLocal()
        : tz.TZDateTime.from(instant, location);
    return asWallClockUtc(wall);
  }

  static tz.Location? _fixedOffset(String name) {
    final match = _fixedOffsetName.firstMatch(name);
    if (match == null) return null;
    final hours = int.parse(match.group(2)!);
    final minutes = int.parse(match.group(3) ?? '0');
    // Real offsets run from -12:00 to +14:00.
    if (hours > 14 || minutes > 59) return null;
    final sign = match.group(1) == '-' ? -1 : 1;
    final offset = Duration(hours: hours, minutes: minutes) * sign;
    return tz.Location(name, const [], const [], [
      tz.TimeZone(offset, isDst: false, abbreviation: name),
    ]);
  }

  /// Follows a CFKeyedArchiver UID into the archive's object table;
  /// returns any other object as is.
  static BPlistObject? _resolve(List<BPlistObject> objects, BPlistObject ref) {
    if (ref is! BPlistUID) return ref;
    if (ref.index < 0 || ref.index >= objects.length) return null;
    return objects[ref.index];
  }
}

/// Picks the zone for each dive of one MacDive import and reads its time
/// in it.
///
/// The order is the stored `ZTIMEZONE` first, then the zone of the dive's
/// site, then the device's zone. The stored zone wins because MacDive
/// derived `ZRAWDATE` from the dive computer's clock with it, so only it
/// gives back the time MacDive shows. Every dive carries its own copy of the
/// archive and most sites serve several dives, so both are resolved once
/// per import.
class MacDiveZoneResolver {
  final Map<String, tz.Location?> _byArchive = {};
  final Map<int, tz.Location?> _bySite = {};
  int _deviceZoneDives = 0;

  /// How many dives had neither a usable stored zone nor a site with a
  /// GPS fix, and so were read in the device's zone.
  int get deviceZoneDives => _deviceZoneDives;

  /// [instant] as the wall clock of the dive's zone, encoded as UTC
  /// components. [archive] is the dive's `ZTIMEZONE` BLOB and [site] the
  /// site it links to, either of which may be missing.
  DateTime wallClockUtc(
    DateTime instant, {
    Uint8List? archive,
    MacDiveRawSite? site,
  }) {
    final location = _storedZone(archive) ?? _siteZone(site);
    if (location == null) _deviceZoneDives++;
    return MacDiveTimeZone.toWallClockUtc(instant, location);
  }

  tz.Location? _storedZone(Uint8List? archive) {
    if (archive == null) return null;
    return _byArchive.putIfAbsent(
      String.fromCharCodes(archive),
      () => MacDiveTimeZone.locationNamed(
        MacDiveTimeZone.nameFromBplist(archive),
      ),
    );
  }

  tz.Location? _siteZone(MacDiveRawSite? site) {
    if (site == null) return null;
    return _bySite.putIfAbsent(
      site.pk,
      () => MacDiveTimeZone.locationNamed(
        MacDiveTimeZone.nameForLocation(site.latitude, site.longitude),
      ),
    );
  }
}
