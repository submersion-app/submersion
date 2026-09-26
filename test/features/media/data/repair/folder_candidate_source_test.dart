import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/services/repair/folder_candidate_source.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('folder-source-test');
    await Directory(p.join(root.path, '2026')).create();
    await File(
      p.join(root.path, '2026', 'Blue-Hole.JPG'),
    ).writeAsString('aaaa');
    await File(p.join(root.path, 'octopus.mp4')).writeAsString('bb');
  });

  tearDown(() => root.delete(recursive: true));

  test(
    'harvest indexes files by lowercase name with sizes and paths',
    () async {
      final source = FolderCandidateSource(roots: [root.path]);
      final harvest = await source.harvest(const []);

      expect(
        harvest.byFilename.keys,
        containsAll(['blue-hole.jpg', 'octopus.mp4']),
      );
      final photo = harvest.byFilename['blue-hole.jpg']!.single;
      expect(photo.path, p.join(root.path, '2026', 'Blue-Hole.JPG'));
      expect(photo.sizeBytes, 4);
      expect(photo.hash, isNull); // hashing is on-demand, never during harvest
      expect(
        harvest.foundPaths,
        containsAll([
          p.join(root.path, '2026', 'Blue-Hole.JPG'),
          p.join(root.path, 'octopus.mp4'),
        ]),
      );
    },
  );

  test('withHash fills the store-identical sha256 lazily', () async {
    final candidate = RepairCandidate.file(
      path: p.join(root.path, 'octopus.mp4'),
      sizeBytes: 2,
    );
    final hashed = await FolderCandidateSource.withHash(candidate);
    final expected = await sha256OfFile(File(p.join(root.path, 'octopus.mp4')));
    expect(hashed.hash, expected.hash);
    expect(hashed.sizeBytes, expected.sizeBytes);
  });

  test('a nonexistent root harvests nothing rather than throwing', () async {
    final source = FolderCandidateSource(roots: [p.join(root.path, 'missing')]);
    final harvest = await source.harvest(const []);
    expect(harvest.byFilename, isEmpty);
  });
}
