import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/demo_mode/data/demo_paths.dart';

/// Unpacks a verified sample logbook package into the demo directory.
///
/// The package holds exactly `submersion_demo.db` and image files under
/// `photos/`. Anything else, including a path that would land outside the
/// demo directory, rejects the whole package before a byte is written.
class DemoPackageExtractor {
  DemoPackageExtractor({this.maxExtractedBytes = 256 * 1024 * 1024});

  /// The most the package may expand to. The published one is about 15 MB.
  final int maxExtractedBytes;

  static const databaseEntry = 'submersion_demo.db';
  static const _photoExtensions = {'.jpg', '.jpeg', '.png', '.webp'};

  Future<void> extract(File zip, DemoPaths paths) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(await zip.readAsBytes(), verify: true);
    } catch (e) {
      throw FormatException('Sample logbook is not a valid zip: $e');
    }

    final files = archive.files.where((f) => f.isFile).toList();
    for (final f in files) {
      _check(f.name);
    }
    if (!files.any((f) => f.name == databaseEntry)) {
      throw const FormatException('Sample logbook has no database');
    }
    // The sizes the archive declares, before anything is inflated; the
    // bytes each entry really inflates to are counted again as it is written.
    if (files.fold<int>(0, (sum, f) => sum + f.size) > maxExtractedBytes) {
      throw const FormatException('Sample logbook expands past its limit');
    }

    await Directory(paths.photosDir).create(recursive: true);
    var written = 0;
    for (final f in files) {
      final bytes = f.content;
      written += bytes.length;
      if (written > maxExtractedBytes) {
        throw const FormatException('Sample logbook expands past its limit');
      }
      final target = f.name == databaseEntry
          ? paths.databaseFile
          : p.join(paths.photosDir, p.posix.basename(f.name));
      await File(target).writeAsBytes(bytes, flush: true);
    }
  }

  static void _check(String name) {
    final parts = p.posix.split(name);
    final isDatabase = name == databaseEntry;
    final isPhoto =
        parts.length == 2 &&
        parts.first == 'photos' &&
        !parts.last.startsWith('.') &&
        _photoExtensions.contains(p.posix.extension(parts.last).toLowerCase());
    if (!isDatabase && !isPhoto) {
      throw FormatException('Unexpected entry in sample logbook: $name');
    }
  }
}
