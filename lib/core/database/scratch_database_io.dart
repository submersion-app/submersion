import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';

/// Builds a database file in a temporary folder with [fill] and returns its
/// bytes; the folder is removed whether or not the fill succeeded.
Future<Uint8List> withScratchDatabase(
  Future<void> Function(CommonDatabase scratch) fill,
) async {
  final folder = await Directory.systemTemp.createTemp('submersion-image-');
  try {
    final path = p.join(folder.path, 'image.db');
    final scratch = sqlite3.open(path);
    try {
      await fill(scratch);
    } finally {
      scratch.close();
    }
    return await File(path).readAsBytes();
  } finally {
    await folder.delete(recursive: true);
  }
}

/// Opens [image], the bytes of a SQLite file, read-only in a temporary
/// folder and returns what [read] makes of it; the folder is removed after.
Future<T> readScratchImage<T>(
  Uint8List image,
  T Function(CommonDatabase db) read,
) async {
  final folder = await Directory.systemTemp.createTemp('submersion-image-');
  try {
    final path = p.join(folder.path, 'image.db');
    await File(path).writeAsBytes(image, flush: true);
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      return read(db);
    } finally {
      db.close();
    }
  } finally {
    await folder.delete(recursive: true);
  }
}
