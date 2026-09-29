/// How a fill merges when one side is a copy read from an NFC tag.
///
/// A fill imported from a tag (source `nfc`) shares the id of the fill it
/// was written from, logged on some device. The copy carries less: values
/// rounded for the tag, a station name cut to 40 characters, no notes. So
/// whichever clock is newer, the original wins, on every device, and a
/// diver's own fill never turns into its tag copy (spec section 11).
enum TagFillCopyMerge { keepLocal, takeRemote }

/// The merge for a fill row present on both sides, or null when neither or
/// both are tag copies and the clocks decide as usual.
TagFillCopyMerge? tagFillCopyMerge(
  Map<String, dynamic>? local,
  Map<String, dynamic> remote,
) {
  if (local == null) return null;
  final localIsCopy = local['source'] == _tagSource;
  final remoteIsCopy = remote['source'] == _tagSource;
  if (localIsCopy == remoteIsCopy) return null;
  return localIsCopy ? TagFillCopyMerge.takeRemote : TagFillCopyMerge.keepLocal;
}

/// FillSource.nfc as the row stores it.
const _tagSource = 'nfc';
