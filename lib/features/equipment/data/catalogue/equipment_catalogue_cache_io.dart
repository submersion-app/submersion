import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:submersion/core/platform/app_directories.dart';

Future<File> _file(String? supportDir) async => File(
  p.join(
    supportDir ?? await AppDirectories.support(),
    'equipment_catalogue',
    'equipment_catalogue.json',
  ),
);

/// The downloaded copy, or null when there is none or it cannot be read.
Future<String?> readEquipmentCatalogueCache({String? supportDir}) async {
  try {
    final file = await _file(supportDir);
    if (!await file.exists()) return null;
    return await file.readAsString();
  } on FileSystemException {
    return null;
  }
}

/// Keeps [json] as the downloaded copy. Written beside the old one and
/// renamed over it, so a crash mid-write never leaves half a file.
Future<void> writeEquipmentCatalogueCache(
  String json, {
  String? supportDir,
}) async {
  final file = await _file(supportDir);
  await file.parent.create(recursive: true);
  final partial = File('${file.path}.partial');
  await partial.writeAsString(json, flush: true);
  await partial.rename(file.path);
}
