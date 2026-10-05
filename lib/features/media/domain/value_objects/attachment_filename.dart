/// Why a proposed attachment name was refused.
enum AttachmentNameError { blank, forbiddenCharacter }

/// An attachment's filename split for renaming (issue #1039): the stem the
/// diver edits and the extension that stays fixed.
///
/// The extension is fixed because the app reads a document's kind from it
/// (`MediaItem.isPdf`, the share MIME type), so a rename must not be able to
/// turn a PDF into an unopenable file. The split matches
/// `MediaItem.documentExtension`: on the last dot, with a trailing dot
/// counting as part of the stem.
class AttachmentFilename {
  const AttachmentFilename({required this.stem, required this.extension});

  factory AttachmentFilename.split(String? name) {
    if (name == null) return const AttachmentFilename(stem: '', extension: '');
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) {
      return AttachmentFilename(stem: name, extension: '');
    }
    return AttachmentFilename(
      stem: name.substring(0, dot),
      extension: name.substring(dot + 1),
    );
  }

  /// The editable part.
  final String stem;

  /// The fixed part, without the dot and in its original case; '' when the
  /// name has none.
  final String extension;

  /// [newStem], trimmed, with this name's extension re-attached.
  String compose(String newStem) {
    final trimmed = newStem.trim();
    return extension.isEmpty ? trimmed : '$trimmed.$extension';
  }

  /// Characters no common filesystem accepts in a name. The name becomes a
  /// temp file when the attachment is shared, on whatever device it has
  /// synced to, so the strictest platform (Windows) sets the list.
  static final _forbidden = RegExp(r'[/\\:*?"<>|]');

  /// Why [stem] cannot be saved, or null when it can.
  static AttachmentNameError? validate(String stem) {
    final trimmed = stem.trim();
    if (trimmed.isEmpty) return AttachmentNameError.blank;
    if (_forbidden.hasMatch(trimmed) ||
        trimmed.codeUnits.any((unit) => unit < 0x20)) {
      return AttachmentNameError.forbiddenCharacter;
    }
    return null;
  }
}
