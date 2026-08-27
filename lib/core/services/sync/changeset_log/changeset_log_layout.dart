// Flat, filename-encoded layout for the v1 changeset log. Everything lives in
// the single existing sync folder; the device id and file kind are encoded in
// the name so discovery needs only listFiles(folder, namePattern) -- uniform
// across S3 (recursive prefix), iCloud and Google Drive. Device ids are UUIDs
// (no '.'), so '.' is a safe field separator. Seqs are zero-padded so lexical
// name order matches numeric seq order.
class ChangesetLogLayout {
  static const String prefix = 'ssv1.';
  static const String _manifestSuffix = '.manifest.json';
  static const String _retiredSuffix = '.retired.json';
  static const String _csMarker = '.cs.';
  static const String _baseMarker = '.base.';
  static const int seqPad = 12;
  static const int partPad = 4;

  /// namePattern to pass to listFiles to fetch only this format's files.
  static const String listPattern = prefix;

  static String manifestName(String deviceId) =>
      '$prefix$deviceId$_manifestSuffix';

  static String changesetName(String deviceId, int seq) =>
      '$prefix$deviceId$_csMarker${_pad(seq, seqPad)}.json';

  static String basePartName(String deviceId, int baseSeq, int part) =>
      '$prefix$deviceId$_baseMarker${_pad(baseSeq, seqPad)}.p${_pad(part, partPad)}';

  static bool isOurs(String name) => name.startsWith(prefix);

  static bool isManifest(String name) =>
      isOurs(name) && name.endsWith(_manifestSuffix);

  /// Durable marker that [deviceId]'s log was retired (see RetirementMarker).
  /// Ignored by the compaction pruner (no .cs./.base. marker in the name) and
  /// wiped with everything else on a library replace (prefix match).
  static String retiredMarkerName(String deviceId) =>
      '$prefix$deviceId$_retiredSuffix';

  static bool isRetiredMarker(String name) =>
      isOurs(name) && name.endsWith(_retiredSuffix);

  /// The device id encoded in [name], or null if [name] is not ours.
  static String? deviceIdOf(String name) {
    if (!isOurs(name)) return null;
    final rest = name.substring(prefix.length);
    final dot = rest.indexOf('.');
    if (dot <= 0) return null;
    return rest.substring(0, dot);
  }

  /// The changeset seq encoded in [name], or null if [name] is not a changeset.
  static int? changesetSeqOf(String name) {
    if (!isOurs(name)) return null;
    final i = name.indexOf(_csMarker);
    if (i < 0) return null;
    final after = name.substring(i + _csMarker.length);
    final end = after.indexOf('.');
    if (end < 0) return null;
    return int.tryParse(after.substring(0, end));
  }

  /// The (baseSeq, part) encoded in [name], or null if not a base part.
  static ({int baseSeq, int part})? basePartOf(String name) {
    if (!isOurs(name)) return null;
    final i = name.indexOf(_baseMarker);
    if (i < 0) return null;
    final after = name.substring(i + _baseMarker.length);
    final pIdx = after.indexOf('.p');
    if (pIdx < 0) return null;
    final baseSeq = int.tryParse(after.substring(0, pIdx));
    final part = int.tryParse(after.substring(pIdx + 2));
    if (baseSeq == null || part == null) return null;
    return (baseSeq: baseSeq, part: part);
  }

  /// Distinct peer device ids present in [fileNames], excluding [selfId].
  static Set<String> peerDeviceIds(Iterable<String> fileNames, String selfId) {
    final ids = <String>{};
    for (final name in fileNames) {
      final id = deviceIdOf(name);
      if (id != null && id != selfId) ids.add(id);
    }
    return ids;
  }

  static String _pad(int v, int width) => v.toString().padLeft(width, '0');
}
