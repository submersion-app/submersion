import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/in_memory_logbook.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/media_row_mapper.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Photos and videos being identified without being kept (issue #5122).
///
/// The session holds its own logbook and local cache in memory, a copy of
/// the diver's species catalogue in it, and a temporary folder for crops.
/// Species identification runs against these exactly as it does against
/// the diver's logbook, with the same repositories, so nothing it writes
/// (results, tags, a species the catalogue lacked) reaches the logbook,
/// sync or History. Keeping a file copies what it needs across
/// (`ScratchKeeper`); [dispose] throws the rest away.
class ScratchSession {
  ScratchSession._({
    required this.logbook,
    required this.cache,
    required this.cropRoot,
    required List<MediaItem> items,
  }) : _items = List.unmodifiable(items);

  /// The session's own logbook: never the diver's.
  final AppDatabase logbook;

  /// The session's own local cache, for embeddings.
  final LocalCacheDatabase cache;

  /// Where crops are written while the session lasts.
  final Directory cropRoot;

  List<MediaItem> _items;
  final _changes = StreamController<void>.broadcast();
  bool _disposed = false;

  /// Marks an id as a file the diver has not kept. A row's id is a uuid
  /// and never carries it.
  static const String idPrefix = 'scratch:';

  static String newId() => '$idPrefix${const Uuid().v4()}';

  /// Whether [id] names a file the diver has not kept.
  static bool isScratchId(String id) => id.startsWith(idPrefix);

  /// The files not kept yet, in the order they were added.
  List<MediaItem> get items => _items;

  /// Ticks when a file is added or kept.
  Stream<void> get changes => _changes.stream;

  /// Opens a session for [items], with the species catalogue of [source]
  /// (the diver's logbook) copied in, so the names it shows and the
  /// species it finds are the diver's own.
  static Future<ScratchSession> open({
    required List<MediaItem> items,
    required AppDatabase source,
    Directory? tempRoot,
  }) async {
    final logbook = openInMemoryLogbook();
    final cache = openInMemoryLocalCache();
    final cropRoot = await (tempRoot ?? Directory.systemTemp).createTemp(
      'submersion-identify-',
    );
    final session = ScratchSession._(
      logbook: logbook,
      cache: cache,
      cropRoot: cropRoot,
      items: const [],
    );
    try {
      final species = await source.select(source.species).get();
      await logbook.batch(
        (batch) => batch.insertAll(
          logbook.species,
          species,
          mode: InsertMode.insertOrIgnore,
        ),
      );
      for (final item in items) {
        await session.add(item);
      }
      return session;
    } catch (_) {
      await session.dispose();
      rethrow;
    }
  }

  /// Adds [item] (a camera capture, say) to the session.
  Future<void> add(MediaItem item) async {
    assert(isScratchId(item.id), 'a scratch item needs a scratch id');
    final now = DateTime.now().millisecondsSinceEpoch;
    await logbook
        .into(logbook.media)
        .insert(
          MediaCompanion(
            id: Value(item.id),
            filePath: Value(item.filePath ?? item.localPath ?? ''),
            fileType: Value(mediaTypeToDbString(item.mediaType)),
            platformAssetId: Value(item.platformAssetId),
            originalFilename: Value(item.originalFilename),
            latitude: Value(item.latitude),
            longitude: Value(item.longitude),
            takenAt: Value(item.takenAt.millisecondsSinceEpoch),
            width: Value(item.width),
            height: Value(item.height),
            durationSeconds: Value(item.durationSeconds),
            sourceType: Value(item.sourceType.name),
            localPath: Value(item.localPath),
            bookmarkRef: Value(item.bookmarkRef),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
    _items = List.unmodifiable([
      for (final i in _items)
        if (i.id != item.id) i,
      item,
    ]);
    if (!_disposed) _changes.add(null);
  }

  final Set<String> _kept = {};

  /// Whether [id] has been kept: keeping it again would make a second row.
  bool isKept(String id) => _kept.contains(id);

  /// Every id kept in this session.
  Set<String> get keptIds => Set.unmodifiable(_kept);

  /// Records [id] as kept. It stays in the session, and on screen, with
  /// what was found on it.
  void markKept(String id) {
    _kept.add(id);
    if (!_disposed) _changes.add(null);
  }

  /// Takes [id] out of the session: it is no longer shown.
  void forget(String id) {
    _items = List.unmodifiable([
      for (final i in _items)
        if (i.id != id) i,
    ]);
    if (!_disposed) _changes.add(null);
  }

  /// Closes both databases and deletes the crops folder. Safe to call twice.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _changes.close();
    await logbook.close();
    await cache.close();
    if (await cropRoot.exists()) await cropRoot.delete(recursive: true);
  }
}
