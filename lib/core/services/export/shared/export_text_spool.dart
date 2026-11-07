import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:path/path.dart' as p;

import 'package:submersion/core/platform/app_directories.dart';
import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Where an export writes its text, a piece at a time.
abstract interface class ExportTextSink {
  void write(String text);

  /// Lets a sink with a file behind it hand what it holds to the file, so
  /// a large export never waits in memory for the end.
  Future<void> flush();
}

/// An [ExportTextSink] that keeps everything, for a browser (which has no
/// file system to write to) and for tests.
class MemoryTextSink implements ExportTextSink {
  final _buffer = StringBuffer();

  @override
  void write(String text) => _buffer.write(text);

  @override
  Future<void> flush() async {}

  @override
  String toString() => _buffer.toString();
}

/// An [ExportTextSink] writing UTF-8 into [file].
class FileTextSink implements ExportTextSink {
  FileTextSink(this.file) : _sink = file.openWrite();

  final File file;
  final IOSink _sink;

  @override
  void write(String text) => _sink.write(text);

  @override
  Future<void> flush() => _sink.flush();

  /// Finishes the file; nothing may be written after.
  Future<void> close() async {
    await _sink.flush();
    await _sink.close();
  }
}

/// Text written now and read back once, in order, later.
///
/// A streamed export writes some sections before it knows what goes ahead
/// of them in the file; each such section waits in a spool.
abstract interface class ExportTextSpool implements ExportTextSink {
  bool get isEmpty;

  /// Writes everything spooled, in order, into [out].
  Future<void> copyTo(ExportTextSink out);
}

/// Hands out [ExportTextSpool]s and removes them when the export is done.
abstract class ExportSpoolStore {
  ExportSpoolStore._();

  /// Spools kept in memory, where there is no file system.
  factory ExportSpoolStore.memory() = _MemorySpoolStore;

  /// Spools kept as files in [directory].
  factory ExportSpoolStore.inDirectory(Directory directory) = _FileSpoolStore;

  ExportTextSpool create();

  /// Releases every spool this store created.
  Future<void> dispose();
}

class _MemorySpoolStore extends ExportSpoolStore {
  _MemorySpoolStore() : super._();

  @override
  ExportTextSpool create() => _MemorySpool();

  @override
  Future<void> dispose() async {}
}

class _MemorySpool implements ExportTextSpool {
  final _buffer = StringBuffer();

  @override
  bool get isEmpty => _buffer.isEmpty;

  @override
  void write(String text) => _buffer.write(text);

  @override
  Future<void> flush() async {}

  @override
  Future<void> copyTo(ExportTextSink out) async {
    out.write(_buffer.toString());
    _buffer.clear();
  }
}

class _FileSpoolStore extends ExportSpoolStore {
  _FileSpoolStore(this.directory) : super._();

  final Directory directory;
  final _spools = <_FileSpool>[];

  @override
  ExportTextSpool create() {
    final spool = _FileSpool(
      File(p.join(directory.path, 'spool_${_spools.length}.txt')),
    );
    _spools.add(spool);
    return spool;
  }

  @override
  Future<void> dispose() async {
    for (final spool in _spools) {
      await spool.discard();
    }
  }
}

class _FileSpool implements ExportTextSpool {
  _FileSpool(this._file);

  final File _file;
  IOSink? _sink;
  var _empty = true;

  @override
  bool get isEmpty => _empty;

  @override
  void write(String text) {
    if (text.isEmpty) return;
    _empty = false;
    (_sink ??= _file.openWrite()).write(text);
  }

  @override
  Future<void> flush() async => _sink?.flush();

  @override
  Future<void> copyTo(ExportTextSink out) async {
    final sink = _sink;
    if (sink == null) return;
    await sink.flush();
    await sink.close();
    _sink = null;
    await for (final text in _file.openRead().transform(utf8.decoder)) {
      out.write(text);
      await out.flush();
    }
  }

  Future<void> discard() async {
    await _sink?.close();
    _sink = null;
    if (await _file.exists()) await _file.delete();
  }
}

/// A new, empty directory for one export's working files, in the app's
/// temp space. Delete it when the export is done.
///
/// The app's own temp directory, not `Directory.systemTemp`: a sandboxed
/// macOS app may not write `/tmp` (issue #509). That one is the fallback only
/// where path_provider has no platform behind it, a unit test.
Future<Directory> createExportWorkDirectory() async {
  Directory base;
  try {
    base = Directory(await AppDirectories.temp());
    await base.create(recursive: true);
  } on MissingPluginException {
    base = Directory.systemTemp;
  } on FlutterError catch (e) {
    if (!e.toString().contains('Binding has not yet been initialized')) {
      rethrow;
    }
    base = Directory.systemTemp;
  }
  return base.createTemp('submersion_export_');
}

final _log = LoggerService.forClass(ExportTextSink);

/// Builds a text export named [fileName] with [write] and hands it on.
///
/// With a file system, the export is written to a file in a working
/// directory of its own, beside the spools [write] is given, and handed to
/// [onFile]; the directory is removed once [onFile] is done, so [onFile]
/// moves or reads what it keeps. A browser has none, so there the export is
/// built in memory and handed to [inMemory] as text.
Future<T> buildTextExport<T>(
  String fileName,
  Future<void> Function(ExportTextSink out, ExportSpoolStore spools) write, {
  required Future<T> Function(String text) inMemory,
  required Future<T> Function(File file) onFile,
}) async {
  if (HostPlatform.isWeb) {
    final out = MemoryTextSink();
    await write(out, ExportSpoolStore.memory());
    return inMemory(out.toString());
  }
  final workDir = await createExportWorkDirectory();
  try {
    final file = File(p.join(workDir.path, fileName));
    final out = FileTextSink(file);
    final spools = ExportSpoolStore.inDirectory(workDir);
    try {
      await write(out, spools);
    } finally {
      await out.close();
      await spools.dispose();
    }
    return await onFile(file);
  } finally {
    try {
      await workDir.delete(recursive: true);
    } on FileSystemException catch (e) {
      // The export itself is done; a leftover in temp space is the OS's to
      // clear, and no reason to report the export as failed.
      _log.warning('Could not remove export work dir: $e');
    }
  }
}
