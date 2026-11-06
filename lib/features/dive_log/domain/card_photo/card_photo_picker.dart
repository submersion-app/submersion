import 'package:submersion/features/dive_log/domain/card_photo/card_photo.dart';

/// The photo shown behind [diveId]'s card, or null when it has none.
///
/// Random across dives, but the same for one dive every time it is drawn:
/// a choice made afresh on each build would swap photos as the list
/// scrolls. The photos are ordered by id first, so the order they were
/// loaded in does not matter; adding or removing one of the dive's photos
/// may move the choice.
CardPhoto? pickCardPhoto(String diveId, List<CardPhoto> photos) {
  if (photos.isEmpty) return null;
  if (photos.length == 1) return photos.first;
  final sorted = [...photos]..sort((a, b) => a.mediaId.compareTo(b.mediaId));
  return sorted[_fnv1a(diveId) % sorted.length];
}

/// 32-bit FNV-1a over [s]'s code units. String.hashCode is not specified to
/// be stable between runs, and the choice should survive a restart.
int _fnv1a(String s) {
  var hash = 0x811c9dc5;
  for (final unit in s.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}
