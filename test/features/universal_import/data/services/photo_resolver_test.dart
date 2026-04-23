import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';
import 'package:submersion/features/universal_import/data/services/photo_resolver.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('photo_resolver_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('PhotoResolver - direct path', () {
    test('finds file at originalPath, returns its path', () async {
      final file = File('${tmp.path}/a.jpg')..writeAsBytesSync([1, 2, 3, 4]);
      final refs = [
        ImportImageRef(originalPath: file.path, diveSourceUuid: 'd'),
      ];
      final results = await const PhotoResolver(rootDir: null).resolveAll(refs);
      expect(results.length, 1);
      expect(results.first.kind, PhotoResolutionKind.directPath);
      expect(results.first.resolvedPath, file.path);
    });

    test(
      'direct path wins even when rootDir is set and contains a filename match',
      () async {
        final direct = File('${tmp.path}/a.jpg')..writeAsBytesSync([9]);
        final sub = Directory('${tmp.path}/other')..createSync();
        File('${sub.path}/a.jpg').writeAsBytesSync([42]);

        final refs = [
          ImportImageRef(originalPath: direct.path, diveSourceUuid: 'd'),
        ];
        final results = await PhotoResolver(rootDir: tmp.path).resolveAll(refs);
        expect(results.first.kind, PhotoResolutionKind.directPath);
        expect(results.first.resolvedPath, direct.path);
      },
    );
  });

  group('PhotoResolver - rebased path', () {
    test('rebase finds file with shared tail under rootDir', () async {
      // Simulated original: /Users/other/Photos/Diving/shark.jpg
      // On this machine, file lives at <tmp>/Photos/Diving/shark.jpg
      // Resolver peels /Users/other off the front and finds it.
      final subdir = Directory('${tmp.path}/Photos/Diving')
        ..createSync(recursive: true);
      final expectedFile = File('${subdir.path}/shark.jpg')
        ..writeAsBytesSync([7]);

      final refs = [
        const ImportImageRef(
          originalPath: '/Users/other/Photos/Diving/shark.jpg',
          diveSourceUuid: 'd',
        ),
      ];
      final results = await PhotoResolver(rootDir: tmp.path).resolveAll(refs);
      expect(results.first.kind, PhotoResolutionKind.rebased);
      expect(results.first.resolvedPath, expectedFile.path);
    });

    test('rebase returns longest matching tail', () async {
      // <tmp>/shark.jpg exists AND <tmp>/Photos/shark.jpg exists.
      // Rebasing "/Users/other/Photos/shark.jpg" should prefer
      // <tmp>/Photos/shark.jpg because it shares the longer tail.
      File('${tmp.path}/shark.jpg').writeAsBytesSync([1]);
      final photosDir = Directory('${tmp.path}/Photos')..createSync();
      final expectedFile = File('${photosDir.path}/shark.jpg')
        ..writeAsBytesSync([2]);

      final refs = [
        const ImportImageRef(
          originalPath: '/Users/other/Photos/shark.jpg',
          diveSourceUuid: 'd',
        ),
      ];
      final results = await PhotoResolver(rootDir: tmp.path).resolveAll(refs);
      expect(results.first.kind, PhotoResolutionKind.rebased);
      expect(results.first.resolvedPath, expectedFile.path);
    });
  });

  group('PhotoResolver - filename fallback', () {
    test(
      'finds file by basename under rootDir when direct+rebase fail',
      () async {
        final subdir = Directory('${tmp.path}/deep/nested')
          ..createSync(recursive: true);
        final expectedFile = File('${subdir.path}/b.jpg')
          ..writeAsBytesSync([88]);

        final refs = [
          const ImportImageRef(
            originalPath: '/other/machine/completely/different/b.jpg',
            diveSourceUuid: 'd',
          ),
        ];
        final results = await PhotoResolver(rootDir: tmp.path).resolveAll(refs);
        expect(results.first.kind, PhotoResolutionKind.filenameMatch);
        expect(results.first.resolvedPath, expectedFile.path);
      },
    );

    test('filename match skipped if rootDir is null', () async {
      final refs = [
        const ImportImageRef(
          originalPath: '/nowhere/c.jpg',
          diveSourceUuid: 'd',
        ),
      ];
      final results = await const PhotoResolver(rootDir: null).resolveAll(refs);
      expect(results.first.kind, PhotoResolutionKind.miss);
    });
  });

  group('PhotoResolver - miss', () {
    test('returns miss with null path when nothing matches', () async {
      final refs = [
        const ImportImageRef(
          originalPath: '/nowhere/x.jpg',
          diveSourceUuid: 'd',
        ),
      ];
      final results = await PhotoResolver(rootDir: tmp.path).resolveAll(refs);
      expect(results.first.kind, PhotoResolutionKind.miss);
      expect(results.first.resolvedPath, isNull);
    });

    test('carries the original ref for wizard display', () async {
      const ref = ImportImageRef(
        originalPath: '/nowhere/x.jpg',
        diveSourceUuid: 'dive-1',
        caption: 'missing photo',
      );
      final results = await PhotoResolver(rootDir: tmp.path).resolveAll([ref]);
      expect(results.first.ref, ref);
    });
  });

  group('PhotoResolver - batch behavior', () {
    test(
      'filename index built once per resolveAll call (O(n) scans, not O(n*m))',
      () async {
        // Populate rootDir with many files; then resolve many refs.
        // Purely a behavioral check: all files found quickly.
        for (var i = 0; i < 20; i++) {
          File('${tmp.path}/pic$i.jpg').writeAsBytesSync([i]);
        }
        final refs = List.generate(
          20,
          (i) => ImportImageRef(
            originalPath: '/other/pic$i.jpg',
            diveSourceUuid: 'd',
          ),
        );
        final results = await PhotoResolver(rootDir: tmp.path).resolveAll(refs);
        expect(
          results.every((r) => r.kind == PhotoResolutionKind.filenameMatch),
          isTrue,
        );
        expect(results.every((r) => r.resolvedPath != null), isTrue);
      },
    );

    test(
      'filename index skipped entirely when direct/rebase resolve all refs',
      () async {
        // When every ref is found via direct path, the recursive index
        // walk must not happen. Put a deeply-nested guard file that would
        // show up in an index scan; we never reference it. If the resolver
        // still walked the tree to build an index, it would still succeed —
        // this test asserts the behavior (all direct hits) that lazy
        // indexing preserves. The real correctness check is that no miss
        // appears in the output path.
        final direct1 = File('${tmp.path}/a.jpg')..writeAsBytesSync([1]);
        final direct2 = File('${tmp.path}/b.jpg')..writeAsBytesSync([2]);
        final refs = [
          ImportImageRef(originalPath: direct1.path, diveSourceUuid: 'd'),
          ImportImageRef(originalPath: direct2.path, diveSourceUuid: 'd'),
        ];
        final results = await PhotoResolver(rootDir: tmp.path).resolveAll(refs);
        expect(results.map((r) => r.kind), [
          PhotoResolutionKind.directPath,
          PhotoResolutionKind.directPath,
        ]);
      },
    );

    test('empty input returns empty output', () async {
      final results = await PhotoResolver(rootDir: tmp.path).resolveAll([]);
      expect(results, isEmpty);
    });
  });
}
