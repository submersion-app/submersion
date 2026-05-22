import 'package:equatable/equatable.dart';

/// A photo referenced by a dive in the source dataset. Carries the
/// original filesystem path (absolute on the machine that wrote the
/// export), the caption (if any), the dive it belongs to (by source
/// UUID), and a display position for ordering.
///
/// Populated by format-specific readers:
/// - [MacDiveDbReader] reads `ZDIVEIMAGE.ZPATH`/`ZORIGINALPATH`
/// - [MacDiveXmlReader] reads `<photos><photo><path>`
///
/// Consumed by the post-import photo-linking pipeline (PhotoResolver ->
/// LocalMediaLinker via ImportPhotoLinkController).
class ImportImageRef extends Equatable {
  /// Absolute path as recorded in the source (may not exist on the
  /// machine running the import — the resolver handles misses).
  final String originalPath;

  /// The dive this photo is attached to, matched by source UUID on the
  /// dive map.
  final String diveSourceUuid;

  /// Optional caption from the source.
  final String? caption;

  /// Display position among a dive's photos (0-based). Sources that
  /// don't record ordering default to 0.
  final int position;

  /// Optional stable UUID the source assigned to this photo
  /// (MacDive's `ZDIVEIMAGE.ZUUID`). Null when the source has no
  /// per-photo ID.
  final String? sourceUuid;

  const ImportImageRef({
    required this.originalPath,
    required this.diveSourceUuid,
    this.caption,
    this.position = 0,
    this.sourceUuid,
  });

  /// Filename component of [originalPath]. Used for filename-fallback
  /// resolution when the original absolute path doesn't exist on the
  /// local filesystem.
  String get filename {
    // Handle both POSIX and Windows separators — MacDive paths on a Mac
    // use /, but a Windows-generated export might use \.
    final slash = originalPath.lastIndexOf('/');
    final bslash = originalPath.lastIndexOf(r'\');
    final split = slash > bslash ? slash : bslash;
    return split >= 0 ? originalPath.substring(split + 1) : originalPath;
  }

  @override
  List<Object?> get props => [
    originalPath,
    diveSourceUuid,
    caption,
    position,
    sourceUuid,
  ];
}
