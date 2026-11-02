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
