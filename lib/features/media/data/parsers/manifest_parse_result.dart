import 'package:equatable/equatable.dart';

import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';

/// Outcome of parsing a manifest body. Always returned successfully — per-
/// item parse failures are reported in [warnings] rather than thrown so the
/// preview UI can show "imported 47 of 50 entries; 3 skipped".
class ManifestParseResult extends Equatable {
  final ManifestFormat format;

  /// Optional feed title (Atom `<title>`, JSON `title`, CSV — null).
  final String? title;

  final List<ManifestEntry> entries;

  /// Per-item warnings (e.g. "row 7: missing url"). Caller decides whether
  /// to surface in UI.
  final List<String> warnings;

  const ManifestParseResult({
    required this.format,
    required this.entries,
    this.title,
    this.warnings = const [],
  });

  @override
  List<Object?> get props => [format, title, entries, warnings];
}
