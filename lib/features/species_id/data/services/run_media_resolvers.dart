import 'dart:io';

import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Photo library lookups run at once. Each may search the library, so a
/// whole logbook asked together would flood it (issue #5127).
const int kLibraryLookupsAtOnce = 8;

/// How many of [items] have no original on this device, so a Find species
/// run would have to download them (issue #4727): a file it names that is
/// missing, or a photo library item whose original the library holds only
/// in iCloud ([libraryOriginalHere] says no). Media in [checked] (looked at
/// already with the installed model) is left out: the run does not open it
/// again.
Future<int> notOnDeviceCount(
  List<MediaItem> items, {
  required Future<bool> Function(MediaItem item) libraryOriginalHere,
  bool Function(String path)? fileExists,
  Set<String> checked = const {},
}) async {
  final exists = fileExists ?? _fileExists;
  final toOpen = [
    for (final item in items)
      if (!checked.contains(item.id)) item,
  ];
  final library = [
    for (final item in toOpen)
      if (item.platformAssetId != null) item,
  ];
  final libraryHere = await _askInTurns(library, libraryOriginalHere);
  final filesMissing = toOpen.where((item) {
    if (item.platformAssetId != null) return false;
    return !_fileHere(item, exists);
  }).length;
  return filesMissing + libraryHere.where((here) => !here).length;
}

/// Whether [item]'s original is on this device, by the rule
/// [notOnDeviceCount] counts with: a photo library item whose original the
/// library holds here, or a file that exists. An item with no file of its
/// own (a manifest or URL entry) is fetched to be read, so it is not here.
Future<bool> isOnDevice(
  MediaItem item, {
  required Future<bool> Function(MediaItem item) libraryOriginalHere,
  bool Function(String path)? fileExists,
}) async {
  if (item.platformAssetId != null) return libraryOriginalHere(item);
  return _fileHere(item, fileExists ?? _fileExists);
}

bool _fileExists(String path) => File(path).existsSync();

bool _fileHere(MediaItem item, bool Function(String path) exists) {
  final path = item.localPath;
  return path != null && path.isNotEmpty && exists(path);
}

/// [ask] over [items], at most [kLibraryLookupsAtOnce] at a time, the
/// answers in the items' order.
Future<List<bool>> _askInTurns(
  List<MediaItem> items,
  Future<bool> Function(MediaItem item) ask,
) async {
  final answers = List<bool>.filled(items.length, false);
  var next = 0;
  Future<void> worker() async {
    while (next < items.length) {
      final index = next++;
      answers[index] = await ask(items[index]);
    }
  }

  await Future.wait([
    for (var i = 0; i < kLibraryLookupsAtOnce && i < items.length; i++)
      worker(),
  ]);
  return answers;
}
