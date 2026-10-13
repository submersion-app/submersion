import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

/// Runs [use] with a local path for [file]: its own path, or a temporary
/// copy of its bytes, named as the original, when it has none (a content
/// URI from Android's picker or some iOS providers). The copy is removed
/// afterwards.
Future<T> withLocalPath<T>(
  PlatformFile file,
  Future<T> Function(String path) use,
) async {
  final own = file.path;
  if (own != null) return use(own);
  final dir = await Directory.systemTemp.createTemp('picked_file_');
  try {
    final copy = p.join(dir.path, p.basename(file.name));
    await File(copy).writeAsBytes(await file.readAsBytes());
    return await use(copy);
  } finally {
    await dir.delete(recursive: true);
  }
}
