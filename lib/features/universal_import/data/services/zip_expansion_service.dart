import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Result of expanding a file selection that may contain ZIP archives.
class ArchiveExpansion {
  /// Importable file paths: original non-ZIP paths plus extracted members.
  final List<String> filePaths;

  /// Extracted photo paths keyed by the dive file's basename (without
  /// extension) they belong to. DiveCloud exports name photos with the
  /// dive's DUID prefix or place them in a folder named after the DUID.
  final Map<String, List<String>> photoPathsByBaseName;

  /// Photos in the archive that matched no dive file.
  final List<String> unmatchedPhotoPaths;

  /// Archive entries skipped as junk (hidden files, unsupported types).
  final int skippedEntryCount;

  const ArchiveExpansion({
    required this.filePaths,
    this.photoPathsByBaseName = const {},
    this.unmatchedPhotoPaths = const [],
    this.skippedEntryCount = 0,
  });
}

/// Expands ZIP archives at file-intake time so their members flow through
/// the normal detection/parse pipeline (a DiveCloud export ZIP becomes a
/// bulk batch of .zxu files plus a photo index).
class ZipExpansionService {
  const ZipExpansionService();

  /// Total uncompressed size cap: guards against zip bombs.
  static const maxUncompressedBytes = 500 * 1024 * 1024;

  static const _diveFileExtensions = {'.zxu', '.zxl'};
  static const _photoExtensions = {'.jpg', '.jpeg', '.png', '.heic', '.heif'};

  static bool isZipBytes(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4B &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04;

  /// Expands any ZIPs in [paths]; non-ZIP paths pass through unchanged and
  /// keep their position. Results from multiple ZIPs are merged.
  Future<ArchiveExpansion> expandAll(List<String> paths) async {
    final filePaths = <String>[];
    final photos = <String, List<String>>{};
    final unmatched = <String>[];
    var skipped = 0;

    for (final path in paths) {
      final file = File(path);
      Uint8List header;
      try {
        final raf = await file.open();
        header = await raf.read(4);
        await raf.close();
      } catch (_) {
        filePaths.add(path); // unreadable: let downstream report the error
        continue;
      }
      if (!isZipBytes(header)) {
        filePaths.add(path);
        continue;
      }
      final expansion = await expandZipBytes(
        await file.readAsBytes(),
        p.basename(path),
      );
      filePaths.addAll(expansion.filePaths);
      expansion.photoPathsByBaseName.forEach(
        (key, value) => (photos[key] ??= []).addAll(value),
      );
      unmatched.addAll(expansion.unmatchedPhotoPaths);
      skipped += expansion.skippedEntryCount;
    }

    return ArchiveExpansion(
      filePaths: filePaths,
      photoPathsByBaseName: photos,
      unmatchedPhotoPaths: unmatched,
      skippedEntryCount: skipped,
    );
  }

  /// Extracts [bytes] (a ZIP archive) to a temp directory and classifies
  /// members into dive files and photos.
  ///
  /// Throws [FormatException] when the archive cannot be read (corrupt or
  /// password-protected) or exceeds [maxUncompressedBytes].
  Future<ArchiveExpansion> expandZipBytes(
    Uint8List bytes,
    String archiveName,
  ) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (e) {
      throw FormatException(
        'Could not read archive "$archiveName" '
        '(corrupt or password-protected): $e',
      );
    }

    var totalSize = 0;
    for (final entry in archive) {
      if (entry.isFile) totalSize += entry.size;
    }
    if (totalSize > maxUncompressedBytes) {
      throw FormatException(
        'Archive "$archiveName" is too large to expand '
        '(${totalSize ~/ (1024 * 1024)} MB uncompressed)',
      );
    }

    final tempDir = await Directory.systemTemp.createTemp('submersion_zip_');
    final diveFiles = <String, String>{}; // baseName -> extracted path
    final photoEntries = <({String entryName, String extractedPath})>[];
    var skipped = 0;

    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      final segments = p.split(name);
      if (segments.any((s) => s.startsWith('.') || s == '__MACOSX')) {
        skipped++;
        continue;
      }
      final ext = p.extension(name).toLowerCase();
      final isDiveFile = _diveFileExtensions.contains(ext);
      final isPhoto = _photoExtensions.contains(ext);
      if (!isDiveFile && !isPhoto) {
        skipped++;
        continue;
      }
      // Flatten to the basename; disambiguate collisions with a counter.
      var outName = p.basename(name);
      var outPath = p.join(tempDir.path, outName);
      var counter = 1;
      while (File(outPath).existsSync()) {
        outName =
            '${p.basenameWithoutExtension(name)}_${counter++}${p.extension(name)}';
        outPath = p.join(tempDir.path, outName);
      }
      await File(outPath).writeAsBytes(entry.content as List<int>);

      if (isDiveFile) {
        diveFiles[p.basenameWithoutExtension(outName)] = outPath;
      } else {
        photoEntries.add((entryName: name, extractedPath: outPath));
      }
    }

    // Match photos to dive files: parent-folder name first, then longest
    // dive-file basename that prefixes the photo's own basename.
    final photos = <String, List<String>>{};
    final unmatched = <String>[];
    final baseNames = diveFiles.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final photo in photoEntries) {
      final parentName = p.basename(p.dirname(photo.entryName));
      final photoBase = p.basenameWithoutExtension(photo.entryName);
      String? match;
      if (diveFiles.containsKey(parentName)) {
        match = parentName;
      } else {
        for (final base in baseNames) {
          if (photoBase.startsWith(base)) {
            match = base;
            break;
          }
        }
      }
      if (match != null) {
        (photos[match] ??= []).add(photo.extractedPath);
      } else {
        unmatched.add(photo.extractedPath);
      }
    }

    return ArchiveExpansion(
      filePaths: diveFiles.values.toList(),
      photoPathsByBaseName: photos,
      unmatchedPhotoPaths: unmatched,
      skippedEntryCount: skipped,
    );
  }
}
