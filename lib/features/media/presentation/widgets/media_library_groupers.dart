import 'package:submersion/features/media/domain/entities/media_library_filter.dart';

/// A rendered section of the grouped library list.
class MediaLibraryGroup {
  const MediaLibraryGroup({required this.header, required this.entries});

  final MediaLibraryGroupHeader header;
  final List<MediaLibraryEntry> entries;
}

sealed class MediaLibraryGroupHeader {}

/// Header for the by-dive mode. A null [diveId] marks the pinned Unlinked
/// group, which always renders last.
class DiveGroupHeader extends MediaLibraryGroupHeader {
  DiveGroupHeader({
    this.diveId,
    this.diveNumber,
    this.siteName,
    this.diveDateTime,
  });

  final String? diveId;
  final int? diveNumber;
  final String? siteName;
  final DateTime? diveDateTime;
}

/// Header for the timeline mode: one group per local calendar day, with the
/// month carried alongside so the renderer can emit a month header whenever
/// it changes between consecutive groups.
class DateGroupHeader extends MediaLibraryGroupHeader {
  DateGroupHeader({required this.monthStart, required this.dayStart});

  final DateTime monthStart;
  final DateTime dayStart;
}

/// Groups an already-sorted page stream by dive id (first-seen order), with
/// header fields taken from the first entry of each dive. Unlinked entries
/// (no dive) collect into a single group appended last.
List<MediaLibraryGroup> groupByDive(List<MediaLibraryEntry> entries) {
  final byDive = <String?, List<MediaLibraryEntry>>{};
  for (final entry in entries) {
    byDive.putIfAbsent(entry.item.diveId, () => []).add(entry);
  }
  final unlinked = byDive.remove(null);
  final groups = <MediaLibraryGroup>[
    for (final MapEntry(:key, :value) in byDive.entries)
      MediaLibraryGroup(
        header: DiveGroupHeader(
          diveId: key,
          diveNumber: value.first.diveNumber,
          siteName: value.first.siteName,
          diveDateTime: value.first.diveDateTime,
        ),
        entries: value,
      ),
  ];
  if (unlinked != null && unlinked.isNotEmpty) {
    groups.add(MediaLibraryGroup(header: DiveGroupHeader(), entries: unlinked));
  }
  return groups;
}

/// Groups an already-sorted page stream into calendar days in first-seen
/// order. The timestamp is the item's takenAt (the entity defaults it from
/// createdAt at hydration).
///
/// takenAt is wall-clock-as-UTC: its components ALREADY read as the time the
/// shutter fired, so they are used directly. Calling toLocal() here would
/// shift them by the host's UTC offset and file a photo taken just after
/// midnight under the previous day.
List<MediaLibraryGroup> groupByTimeline(List<MediaLibraryEntry> entries) {
  final byDay = <DateTime, List<MediaLibraryEntry>>{};
  for (final entry in entries) {
    final at = entry.item.takenAt;
    final day = DateTime(at.year, at.month, at.day);
    byDay.putIfAbsent(day, () => []).add(entry);
  }
  return [
    for (final MapEntry(:key, :value) in byDay.entries)
      MediaLibraryGroup(
        header: DateGroupHeader(
          monthStart: DateTime(key.year, key.month),
          dayStart: key,
        ),
        entries: value,
      ),
  ];
}
