/// Reads one of Diving Log's comma separated id columns.
///
/// `Logbook.BuddyIDs`, `Logbook.UsedEquip`, `Logbook.Divetype` and
/// `Trip.BuddyIDs` all hold ids this way, for example `3,15,16`. Order is
/// kept and duplicates are not removed, because the caller decides what a
/// repeat means. Entries that are not numbers are dropped rather than
/// failing the row: one unreadable id should not cost a dive its gear.
List<int> parseDivingLogIdList(String? raw) {
  if (raw == null) return const [];
  return [
    for (final part in raw.split(','))
      if (int.tryParse(part.trim()) case final int id) id,
  ];
}
