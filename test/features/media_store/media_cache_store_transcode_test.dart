import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late MediaCacheStore cache;

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('cache_transcode');
    cache = MediaCacheStore(database: db, root: root);
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  test('transcodeFile is deterministic per hash and level', () async {
    final a = await cache.transcodeFile('h1', 'balanced');
    final b = await cache.transcodeFile('h1', 'balanced');
    expect(a.path, b.path);
    expect(a.path, endsWith('transcode/h1_balanced.mp4'));
    expect(await a.parent.exists(), isTrue);
  });

  test('deleteTranscodeArtifacts removes all levels and tmp debris', () async {
    final balanced = await cache.transcodeFile('h1', 'balanced');
    await balanced.writeAsBytes([1]);
    final small = await cache.transcodeFile('h1', 'small');
    await small.writeAsBytes([2]);
    await File('${small.path}.tmp').writeAsBytes([3]);
    final other = await cache.transcodeFile('h2', 'small');
    await other.writeAsBytes([4]);

    await cache.deleteTranscodeArtifacts('h1');

    expect(await balanced.exists(), isFalse);
    expect(await small.exists(), isFalse);
    expect(await File('${small.path}.tmp').exists(), isFalse);
    expect(await other.exists(), isTrue, reason: 'other hashes untouched');
  });
}
