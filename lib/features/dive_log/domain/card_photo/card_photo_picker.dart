import 'package:meta/meta.dart';

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
@visibleForTesting
int cardPhotoHash(String s) => _fnv1a(s);

int _fnv1a(String s) {
  var hash = 0x811c9dc5;
  for (final unit in s.codeUnits) {
    hash ^= unit;
    // hash * 16777619, the FNV prime (2^24 + 2^8 + 2^7 + 2^4 + 2^1 + 1), as
    // shifts and adds. The plain product reaches 2^56, past what a web build
    // holds exactly, so web and native chose different photos; every term
    // here stays exact on both, and the mask keeps the same low 32 bits.
    hash =
        (hash +
            (hash << 1) +
            (hash << 4) +
            (hash << 7) +
            (hash << 8) +
            (hash << 24)) &
        0xffffffff;
  }
  return hash;
}
