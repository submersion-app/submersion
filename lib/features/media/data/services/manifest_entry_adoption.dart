import 'package:drift/drift.dart' show Value;

import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// How a batch of manifest entries that its subscription does not hold yet
/// splits up: rows a deleted subscription left behind for the same URL,
/// which are taken over, and entries nothing in the library has seen.
class ManifestAdoptionPlan {
  const ManifestAdoptionPlan({required this.adoptable, required this.fresh});

  /// Detached rows and the entry each one now belongs to, keyed by row id.
  final Map<String, ({MediaItem row, ManifestEntry entry})> adoptable;

  /// Entries with no row anywhere; these go through the normal import.
  final List<ManifestEntry> fresh;

  static const empty = ManifestAdoptionPlan(adoptable: {}, fresh: []);
}

/// Splits [entries] into rows to take over and entries to import.
///
/// A row is matched by its media URL, which the feed publishes for each
/// entry. The stored form can be the parsed and re-serialized URL, so both
/// spellings are looked up. Each row is taken over at most once.
Future<ManifestAdoptionPlan> planManifestAdoption(
  MediaRepository mediaRepo,
  List<ManifestEntry> entries,
) async {
  if (entries.isEmpty) return ManifestAdoptionPlan.empty;
  final spellings = <ManifestEntry, List<String>>{
    for (final e in entries) e: _spellings(e.url),
  };
  final detached = await mediaRepo.getDetachedManifestEntriesByUrl(
    spellings.values.expand((s) => s),
  );
  final adoptable = <String, ({MediaItem row, ManifestEntry entry})>{};
  final fresh = <ManifestEntry>[];
  for (final entry in entries) {
    MediaItem? row;
    for (final url in spellings[entry]!) {
      final candidate = detached[url];
      if (candidate != null && !adoptable.containsKey(candidate.id)) {
        row = candidate;
        break;
      }
    }
    if (row == null) {
      fresh.add(entry);
    } else {
      adoptable[row.id] = (row: row, entry: entry);
    }
  }
  return ManifestAdoptionPlan(adoptable: adoptable, fresh: fresh);
}

/// Moves the plan's rows under [subscriptionId]. A row the old subscription
/// had marked missing is in the feed again, so the mark comes off, guarded
/// on the verification stamp the plan read (see
/// [MediaRepository.markOrphaned]). Returns the number of rows taken over.
Future<int> applyManifestAdoption(
  MediaRepository mediaRepo,
  ManifestAdoptionPlan plan,
  String subscriptionId,
) async {
  if (plan.adoptable.isEmpty) return 0;
  await mediaRepo.adoptManifestEntries({
    for (final MapEntry(key: id, value: v) in plan.adoptable.entries)
      id: v.entry.entryKey,
  }, subscriptionId);
  for (final v in plan.adoptable.values) {
    if (v.row.isOrphaned) {
      await mediaRepo.markOrphaned(
        v.row.id,
        false,
        ifLastVerifiedAt: Value(v.row.lastVerifiedAt),
      );
    }
  }
  return plan.adoptable.length;
}

/// [entries] minus the ones [subscriptionId] already holds, matched on the
/// entry key the same way the poller matches them.
Future<List<ManifestEntry>> entriesNotYetIn(
  MediaRepository mediaRepo,
  String subscriptionId,
  List<ManifestEntry> entries,
) async {
  final existing = await mediaRepo.getAllBySubscription(subscriptionId);
  final known = {
    for (final m in existing)
      if (m.entryKey != null) m.entryKey!,
  };
  return [
    for (final e in entries)
      if (!known.contains(e.entryKey)) e,
  ];
}

List<String> _spellings(String url) {
  final reparsed = Uri.tryParse(url)?.toString();
  return [url, if (reparsed != null && reparsed != url) reparsed];
}
