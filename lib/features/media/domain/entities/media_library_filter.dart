import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

/// Library health facet: rows whose backing file is missing (persisted
/// orphan flag). Every row carries a dive or site link, so there is no
/// "unlinked" facet; an album saved with one decodes to no constraint.
enum MediaHealthFilter { missing }

/// Cross-dive library filter. Compiled to SQL by MediaLibraryRepository;
/// all fields combine with AND. Phase 5 serializes this for smart albums.
class MediaLibraryFilter {
  const MediaLibraryFilter({
    this.mediaType,
    this.siteId,
    this.tripId,
    this.diveId,
    this.fromDate,
    this.toDate,
    this.sourceType,
    this.health,
  });

  final MediaType? mediaType;
  final String? siteId;
  final String? tripId;
  final String? diveId;

  /// Inclusive bounds applied to the sort key (takenAt, falling back to
  /// createdAt).
  final DateTime? fromDate;
  final DateTime? toDate;

  final MediaSourceType? sourceType;
  final MediaHealthFilter? health;

  static const MediaLibraryFilter none = MediaLibraryFilter();

  bool get isEmpty =>
      mediaType == null &&
      siteId == null &&
      tripId == null &&
      diveId == null &&
      fromDate == null &&
      toDate == null &&
      sourceType == null &&
      health == null;

  /// Sentinel-based copyWith so callers can explicitly clear a field back to
  /// null (the plain `??` idiom cannot).
  MediaLibraryFilter copyWith({
    Object? mediaType = _undefined,
    Object? siteId = _undefined,
    Object? tripId = _undefined,
    Object? diveId = _undefined,
    Object? fromDate = _undefined,
    Object? toDate = _undefined,
    Object? sourceType = _undefined,
    Object? health = _undefined,
  }) {
    return MediaLibraryFilter(
      mediaType: mediaType == _undefined
          ? this.mediaType
          : mediaType as MediaType?,
      siteId: siteId == _undefined ? this.siteId : siteId as String?,
      tripId: tripId == _undefined ? this.tripId : tripId as String?,
      diveId: diveId == _undefined ? this.diveId : diveId as String?,
      fromDate: fromDate == _undefined ? this.fromDate : fromDate as DateTime?,
      toDate: toDate == _undefined ? this.toDate : toDate as DateTime?,
      sourceType: sourceType == _undefined
          ? this.sourceType
          : sourceType as MediaSourceType?,
      health: health == _undefined ? this.health : health as MediaHealthFilter?,
    );
  }

  static const Object _undefined = Object();

  /// Serialized form stored by smart albums. Ids and enum names mean the
  /// same thing on every device, which is why an album can sync.
  ///
  /// The dates are written as wall-clock-as-UTC millis rather than as the
  /// local instant. [fromDate] and [toDate] are calendar bounds -- what
  /// matters is the day the user picked, and MediaLibraryRepository already
  /// compares them against `taken_at`, which is itself stored wall-clock.
  /// Encoding the instant would hand a device in another timezone a bound
  /// shifted by the offset between them, quietly moving an album's day
  /// boundary by up to a day.
  Map<String, dynamic> toJson() => {
    'mediaType': mediaType?.name,
    'siteId': siteId,
    'tripId': tripId,
    'diveId': diveId,
    'fromDate': _dateToMillis(fromDate),
    'toDate': _dateToMillis(toDate),
    'sourceType': sourceType?.name,
    'health': health?.name,
  };

  /// Decodes leniently: an album written by a newer version (or a value
  /// this build no longer knows) degrades to "no constraint" rather than
  /// throwing and taking the library view down with it.
  static MediaLibraryFilter fromJson(Map<String, dynamic> json) {
    return MediaLibraryFilter(
      mediaType: _enumByName(MediaType.values, json['mediaType']),
      siteId: json['siteId'] as String?,
      tripId: json['tripId'] as String?,
      diveId: json['diveId'] as String?,
      fromDate: _dateFromMillis(json['fromDate']),
      toDate: _dateFromMillis(json['toDate']),
      sourceType: _enumByName(MediaSourceType.values, json['sourceType']),
      health: _enumByName(MediaHealthFilter.values, json['health']),
    );
  }

  static T? _enumByName<T extends Enum>(List<T> values, Object? raw) {
    if (raw is! String) return null;
    for (final value in values) {
      if (value.name == raw) return value;
    }
    return null;
  }

  static int? _dateToMillis(DateTime? date) =>
      date == null ? null : asWallClockUtc(date).millisecondsSinceEpoch;

  static DateTime? _dateFromMillis(Object? raw) => raw is int
      ? fromWallClockUtc(DateTime.fromMillisecondsSinceEpoch(raw, isUtc: true))
      : null;

  @override
  bool operator ==(Object other) {
    return other is MediaLibraryFilter &&
        other.mediaType == mediaType &&
        other.siteId == siteId &&
        other.tripId == tripId &&
        other.diveId == diveId &&
        other.fromDate == fromDate &&
        other.toDate == toDate &&
        other.sourceType == sourceType &&
        other.health == health;
  }

  @override
  int get hashCode => Object.hash(
    mediaType,
    siteId,
    tripId,
    diveId,
    fromDate,
    toDate,
    sourceType,
    health,
  );
}

/// Keyset cursor: the last entry's value for the active sort key, plus its
/// row id as the tiebreaker.
///
/// [sortKey] is an int for the date and size fields and a String for the name
/// field. It is always non-null: the repository coalesces every sort
/// expression, because a NULL key makes the keyset predicate (`key < ?`)
/// evaluate to NULL, which is falsy, and silently truncates the result set at
/// the first NULL row.
class MediaLibraryCursor {
  const MediaLibraryCursor({required this.sortKey, required this.id});

  final Object sortKey;
  final String id;
}

/// One library row: the media item plus denormalized dive header fields for
/// the by-dive and timeline groupers.
class MediaLibraryEntry {
  const MediaLibraryEntry({
    required this.item,
    this.diveNumber,
    this.diveDateTime,
    this.siteName,
  });

  final MediaItem item;
  final int? diveNumber;
  final DateTime? diveDateTime;
  final String? siteName;
}

/// One page of library results. [nextCursor] is null on the last page.
class MediaLibraryPageResult {
  const MediaLibraryPageResult({required this.entries, this.nextCursor});

  final List<MediaLibraryEntry> entries;
  final MediaLibraryCursor? nextCursor;
}
