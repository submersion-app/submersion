import 'dart:io';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';
import 'package:submersion/features/universal_import/data/services/payload_merger.dart';

/// Outcome of parsing a batch of files.
class BatchParseResult {
  final List<FilePayload> parsed;
  final List<PickedImportFile> files;
  final bool cancelled;

  const BatchParseResult({
    required this.parsed,
    required this.files,
    this.cancelled = false,
  });
}

/// Sequentially parses every pending file in a batch. Each file is isolated:
/// a parse failure marks that file failed and the batch continues. Bytes are
/// read lazily per file (path-backed files are only in memory while parsing).
class BatchParseService {
  const BatchParseService();

  /// File extensions worth scanning for in a folder pick.
  static const importableExtensions = {
    'fit',
    'uddf',
    'xml',
    'ssrf',
    'db',
    'sqlite',
    'zxu',
    'zxl',
    'zip', // DiveCloud export archives, expanded at intake
    'csv', // included so CSVs surface in triage as "import individually"
  };

  Future<BatchParseResult> parseAll(
    List<PickedImportFile> files, {
    void Function(int current, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final updated = List<PickedImportFile>.of(files);
    final parsed = <FilePayload>[];
    final pendingTotal = files
        .where((f) => f.status == ImportFileStatus.pending)
        .length;
    var current = 0;

    for (var i = 0; i < updated.length; i++) {
      final file = updated[i];
      if (file.status != ImportFileStatus.pending) continue;

      if (isCancelled?.call() ?? false) {
        return BatchParseResult(
          parsed: parsed,
          files: updated,
          cancelled: true,
        );
      }

      current++;
      onProgress?.call(current, pendingTotal);

      try {
        final bytes = file.bytes ?? await File(file.path!).readAsBytes();
        final parser = parserForFormat(file.detection.format);
        final options = ImportOptions(
          sourceApp: file.detection.sourceApp ?? SourceApp.generic,
          format: file.detection.format,
          // Thread the source filename so parsers that derive data from it
          // (e.g. FIT dive naming, #507) work for batch imports too.
          fileName: file.name,
        );
        final payload = await parser.parse(bytes, options: options);

        if (payload.isEmpty) {
          final message = payload.warnings.isNotEmpty
              ? payload.warnings.first.message
              : 'No data could be parsed from the file';
          updated[i] = file.copyWith(
            status: ImportFileStatus.failed,
            error: message,
          );
          continue;
        }

        final diveCount = payload.entitiesOf(ImportEntityType.dives).length;
        parsed.add(
          FilePayload(fileId: 'f$i', fileName: file.name, payload: payload),
        );
        updated[i] = file.copyWith(
          status: ImportFileStatus.parsed,
          diveCount: diveCount,
        );
      } catch (e) {
        updated[i] = file.copyWith(
          status: ImportFileStatus.failed,
          error: e.toString(),
        );
      }
    }

    return BatchParseResult(parsed: parsed, files: updated);
  }
}

/// Recursively list files under [dirPath] whose extension is importable.
/// Any entry with a dot-prefixed path segment -- hidden files or directories --
/// is skipped. Results sorted by path for a stable batch order.
Future<List<String>> scanFolderForImportableFiles(String dirPath) async {
  final paths = <String>[];
  await for (final entity in Directory(
    dirPath,
  ).list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final relative = entity.path.substring(dirPath.length);
    final segments = relative.split(Platform.pathSeparator);
    if (segments.any((s) => s.startsWith('.'))) continue;
    final dot = entity.path.lastIndexOf('.');
    if (dot < 0) continue;
    final ext = entity.path.substring(dot + 1).toLowerCase();
    if (BatchParseService.importableExtensions.contains(ext)) {
      paths.add(entity.path);
    }
  }
  paths.sort();
  return paths;
}
