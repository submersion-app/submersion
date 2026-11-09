/// A file-imported tank with no serial that a registry entry matches by
/// computer, slot and date (issue #4347).
class SlotCandidate {
  final String tankId;
  final String diveId;
  final String computerId;

  /// The dive is older than every download that showed the slot, so the
  /// match assumes the pairing had not changed since.
  final bool olderThanFirstDownload;

  /// That first download's dive date, when [olderThanFirstDownload].
  final DateTime? firstDownload;

  const SlotCandidate({
    required this.tankId,
    required this.diveId,
    required this.computerId,
    this.olderThanFirstDownload = false,
    this.firstDownload,
  });
}

/// What matching an entry by slot would touch, for the Apply dialog.
class TransmitterSlotPreview {
  final List<SlotCandidate> candidates;

  /// Dives with a slot tank skipped because downloads before and after them
  /// show different serials in that slot.
  final Set<String> changedHandsDiveIds;

  /// Dives on the entry's computers with a transmitter-fed tank that has
  /// neither a serial nor a slot, so nothing can match them.
  final Set<String> noSlotDiveIds;

  /// Display names of the computers [candidates] are on, by id.
  final Map<String, String> computerNames;

  const TransmitterSlotPreview({
    this.candidates = const [],
    this.changedHandsDiveIds = const {},
    this.noSlotDiveIds = const {},
    this.computerNames = const {},
  });

  static const empty = TransmitterSlotPreview();

  Iterable<SlotCandidate> _included(bool includeOlder) =>
      candidates.where((c) => includeOlder || !c.olderThanFirstDownload);

  /// The tank ids Apply writes with the dialog's switch at [includeOlder].
  Set<String> tankIds({required bool includeOlder}) => {
    for (final c in _included(includeOlder)) c.tankId,
  };

  /// The dives those tanks are on.
  Set<String> diveIds({required bool includeOlder}) => {
    for (final c in _included(includeOlder)) c.diveId,
  };
}
