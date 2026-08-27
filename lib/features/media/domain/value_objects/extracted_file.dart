import 'dart:io';

import 'package:equatable/equatable.dart';

import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';

/// A file selected by the user in the Files tab, after EXIF / metadata
/// extraction but before being committed as a [MediaItem].
///
/// Carries the original picker path, a [File] handle (for display
/// thumbnails and later commit), and the extracted [metadata].
/// [warning] is set if metadata extraction surfaced something the user
/// should see on the review pane (e.g., "EXIF unreadable, using mtime").
class ExtractedFile extends Equatable {
  final String sourcePath;
  final File file;
  final MediaSourceMetadata metadata;
  final String? warning;

  const ExtractedFile({
    required this.sourcePath,
    required this.file,
    required this.metadata,
    this.warning,
  });

  @override
  List<Object?> get props => [sourcePath, file.path, metadata, warning];
}
