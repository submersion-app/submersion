import 'package:submersion/features/media/domain/entities/media_item.dart';
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

/// Header for the by-dive mode's group of rows attached to a site but to no
/// dive, such as a site map (issue #4149). Before it existed they read as
/// Unlinked, which they are not.
class SiteGroupHeader extends MediaLibraryGroupHeader {
  SiteGroupHeader({required this.siteId, this.siteName});

  final String siteId;
  final String? siteName;
}

/// Header for the by-dive mode's group of rows attached to an equipment item
/// but to no dive or site.
class EquipmentGroupHeader extends MediaLibraryGroupHeader {
  EquipmentGroupHeader({required this.equipmentId, this.name});

  final String equipmentId;
  final String? name;
}

/// Header for the timeline mode: one group per local calendar day, with the
/// month carried alongside so the renderer can emit a month header whenever
/// it changes between consecutive groups.
class DateGroupHeader extends MediaLibraryGroupHeader {
  DateGroupHeader({required this.monthStart, required this.dayStart});

  final DateTime monthStart;
  final DateTime dayStart;
}

/// Groups an already-sorted page stream by what each row belongs to, in
/// first-seen order, with header fields taken from the group's first entry.
///
/// A row goes under its dive; with no dive, under the site it is attached
/// to; with neither, under its equipment item (issue #4149). Rows attached to
/// none of them collect into a single Unlinked group appended last.
List<MediaLibraryGroup> groupByDive(List<MediaLibraryEntry> entries) {
  final groups = <_GroupKey, List<MediaLibraryEntry>>{};
  final unlinked = <MediaLibraryEntry>[];
  for (final entry in entries) {
    final key = _groupKeyOf(entry.item);
    if (key == null) {
      unlinked.add(entry);
    } else {
      groups.putIfAbsent(key, () => []).add(entry);
    }
  }
  return [
    for (final MapEntry(:key, :value) in groups.entries)
      MediaLibraryGroup(header: _headerFor(key, value.first), entries: value),
    if (unlinked.isNotEmpty)
      MediaLibraryGroup(header: DiveGroupHeader(), entries: unlinked),
  ];
}

typedef _GroupKey = ({_GroupKind kind, String id});

enum _GroupKind { dive, site, equipment }

_GroupKey? _groupKeyOf(MediaItem item) {
  if (item.diveId case final id?) return (kind: _GroupKind.dive, id: id);
  if (item.siteId case final id?) return (kind: _GroupKind.site, id: id);
  if (item.equipmentId case final id?) {
    return (kind: _GroupKind.equipment, id: id);
  }
  return null;
}

MediaLibraryGroupHeader _headerFor(_GroupKey key, MediaLibraryEntry first) =>
    switch (key.kind) {
      _GroupKind.dive => DiveGroupHeader(
        diveId: key.id,
        diveNumber: first.diveNumber,
        siteName: first.siteName,
        diveDateTime: first.diveDateTime,
      ),
      _GroupKind.site => SiteGroupHeader(
        siteId: key.id,
        siteName: first.attachedSiteName,
      ),
      _GroupKind.equipment => EquipmentGroupHeader(
        equipmentId: key.id,
        name: first.attachedEquipmentName,
      ),
    };

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
