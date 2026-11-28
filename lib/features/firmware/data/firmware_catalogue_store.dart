import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:submersion/features/firmware/domain/firmware_catalogue.dart';

/// The last good firmware catalogue and when it was fetched, kept in a
/// `firmware` folder under [root] (the app support directory) so checks
/// work offline and the daily limit survives a restart (issue #5104).
class FirmwareCatalogueStore {
  FirmwareCatalogueStore(this.root);

  final Directory root;

  File get _catalogue =>
      File(p.join(root.path, 'firmware', 'firmware_catalogue.json'));
  File get _attempted =>
      File(p.join(root.path, 'firmware', 'firmware_catalogue.attempted'));
  File get _fetched =>
      File(p.join(root.path, 'firmware', 'firmware_catalogue.fetched'));

  /// The stored catalogue, or null when there is none or it cannot be read.
  Future<FirmwareCatalogue?> load() async {
    try {
      if (!await _catalogue.exists()) return null;
      return FirmwareCatalogue.parse(await _catalogue.readAsString());
    } on FileSystemException {
      return null;
    }
  }

  /// When the stored catalogue was last fetched, or null.
  Future<DateTime?> lastFetchedAt() async {
    try {
      if (!await _fetched.exists()) return null;
      return DateTime.tryParse((await _fetched.readAsString()).trim());
    } on FileSystemException {
      return null;
    }
  }

  /// When a fetch was last tried, whether or not it brought a catalogue, or
  /// null. Gates retries, so an unreachable or unpublished catalogue is not
  /// asked for again until a day has passed.
  Future<DateTime?> lastAttemptAt() async {
    try {
      if (!await _attempted.exists()) return null;
      return DateTime.tryParse((await _attempted.readAsString()).trim());
    } on FileSystemException {
      return null;
    }
  }

  /// Records that a fetch was tried at [at].
  Future<void> markAttempt(DateTime at) async {
    await _attempted.parent.create(recursive: true);
    await _attempted.writeAsString(at.toUtc().toIso8601String());
  }

  /// Keeps [raw] as fetched at [fetchedAt]. The catalogue is written to a
  /// temporary file and renamed, so a crash mid-write never leaves a torn
  /// file in place of the last good one.
  Future<void> save(String raw, DateTime fetchedAt) async {
    await _catalogue.parent.create(recursive: true);
    final tmp = File('${_catalogue.path}.tmp');
    await tmp.writeAsString(raw, flush: true);
    await tmp.rename(_catalogue.path);
    await _fetched.writeAsString(fetchedAt.toUtc().toIso8601String());
  }
}
