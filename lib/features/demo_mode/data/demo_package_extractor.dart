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

  /// [onProgress] hears the bytes written after each entry, out of the total
  /// the archive declares.
  Future<void> extract(
    File zip,
    DemoPaths paths, {
    void Function(int done, int total)? onProgress,
  }) async {
    final Archive archive;
    try {
      // The download was already checked against the manifest's SHA-256.
      archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
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
    // The sizes the archive declares, before anything is inflated. A header
    // can understate them, so each entry also inflates into a sink that
    // stops at whatever the limit has left.
    final declared = files.fold<int>(0, (sum, f) => sum + f.size);
    if (declared > maxExtractedBytes) {
      throw const FormatException('Sample logbook expands past its limit');
    }

    await Directory(paths.photosDir).create(recursive: true);
    var written = 0;
    for (final f in files) {
      final out = BoundedOutput(maxExtractedBytes - written);
      f.decompress(out);
      final bytes = out.getBytes();
      written += bytes.length;
      final target = f.name == databaseEntry
          ? paths.databaseFile
          : p.join(paths.photosDir, p.posix.basename(f.name));
      await File(target).writeAsBytes(bytes, flush: true);
      onProgress?.call(written, declared);
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

/// An in-memory sink that refuses to grow past [limit] bytes, so an entry is
/// inflated only as far as the package may expand.
class BoundedOutput extends OutputMemoryStream {
  BoundedOutput(this.limit);

  final int limit;

  void _room(int bytes) {
    if (length + bytes > limit) {
      throw const FormatException('Sample logbook expands past its limit');
    }
  }

  @override
  void writeByte(int value) {
    _room(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _room(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _room(stream.length);
    super.writeStream(stream);
  }
}
