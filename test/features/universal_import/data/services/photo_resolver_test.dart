import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/universal_import/data/models/import_image_ref.dart';
import 'package:submersion/features/universal_import/data/services/directory_scanner.dart';
import 'package:submersion/features/universal_import/data/services/photo_resolver.dart';
import 'package:submersion/features/universal_import/data/value_objects/scanned_file.dart';

/// Fake scanner that yields a fixed list of (basename -> desktop path) and
/// counts how many times scan() is invoked.
class _FakeScanner implements DirectoryScanner {
  _FakeScanner(this._files);
  final Map<String, String> _files; // basename -> absolute path
  int scanCount = 0;

  @override
  Stream<ScannedFile> scan(GrantedFolder folder) async* {
    scanCount++;
    for (final entry in _files.entries) {
      yield ScannedFile(
        basename: entry.key,
        handle: MediaHandle.localPath(entry.value),
      );
    }
  }
}

/// Fake scanner yielding an explicit list of files (allows two files to
/// share a basename, to exercise candidate disambiguation).
class _ListScanner implements DirectoryScanner {
  _ListScanner(this._files);
  final List<ScannedFile> _files;

  @override
  Stream<ScannedFile> scan(GrantedFolder folder) async* {
    for (final f in _files) {
      yield f;
    }
  }
}

void main() {
  group('PhotoResolver via DirectoryScanner', () {
    test('rebase: recorded tail grafted onto picked root', () async {
      final scanner = _FakeScanner({
        'shark.jpg': '/picked/Photos/Diving/shark.jpg',
      });
      final resolver = PhotoResolver(
        scanner: scanner,
        folder: const GrantedFolder(path: '/picked'),
      );
      final results = await resolver.resolveAll(const [
        ImportImageRef(
          originalPath: '/Users/other/Photos/Diving/shark.jpg',
          diveSourceUuid: 'd',
        ),
      ]);
      expect(results.single.kind, PhotoResolutionKind.rebased);
      expect(
        results.single.scannedFile!.handle.localPath,
        '/picked/Photos/Diving/shark.jpg',
      );
    });

    test('filename-index match when path tail does not graft', () async {
      final scanner = _FakeScanner({'b.jpg': '/picked/deep/nested/b.jpg'});
      final resolver = PhotoResolver(
        scanner: scanner,
        folder: const GrantedFolder(path: '/picked'),
      );
      final results = await resolver.resolveAll(const [
        ImportImageRef(
          originalPath: '/other/machine/x/b.jpg',
          diveSourceUuid: 'd',
        ),
      ]);
      expect(results.single.kind, PhotoResolutionKind.filenameMatch);
      expect(
        results.single.scannedFile!.handle.localPath,
        '/picked/deep/nested/b.jpg',
      );
    });

    test('miss when basename absent from scan', () async {
      final scanner = _FakeScanner({'other.jpg': '/picked/other.jpg'});
      final resolver = PhotoResolver(
        scanner: scanner,
        folder: const GrantedFolder(path: '/picked'),
      );
      final results = await resolver.resolveAll(const [
        ImportImageRef(originalPath: '/x/missing.jpg', diveSourceUuid: 'd'),
      ]);
      expect(results.single.kind, PhotoResolutionKind.miss);
      expect(results.single.scannedFile, isNull);
      expect(results.single.ref.originalPath, '/x/missing.jpg');
    });

    test('scans exactly once for many refs', () async {
      final scanner = _FakeScanner({
        for (var i = 0; i < 10; i++) 'p$i.jpg': '/picked/p$i.jpg',
      });
      final resolver = PhotoResolver(
        scanner: scanner,
        folder: const GrantedFolder(path: '/picked'),
      );
      final refs = List.generate(
        10,
        (i) => ImportImageRef(originalPath: '/x/p$i.jpg', diveSourceUuid: 'd'),
      );
      final results = await resolver.resolveAll(refs);
      expect(
        results.every((r) => r.kind == PhotoResolutionKind.filenameMatch),
        isTrue,
      );
      expect(scanner.scanCount, 1);
    });

    test('non-image extensions are skipped and counted', () async {
      final scanner = _FakeScanner({'movie.mov': '/picked/movie.mov'});
      final resolver = PhotoResolver(
        scanner: scanner,
        folder: const GrantedFolder(path: '/picked'),
      );
      final results = await resolver.resolveAll(const [
        ImportImageRef(originalPath: '/x/movie.mov', diveSourceUuid: 'd'),
      ]);
      expect(results.single.kind, PhotoResolutionKind.skippedNonImage);
      expect(results.single.scannedFile, isNull);
    });

    test('empty input returns empty output without scanning', () async {
      final scanner = _FakeScanner({'a.jpg': '/picked/a.jpg'});
      final resolver = PhotoResolver(
        scanner: scanner,
        folder: const GrantedFolder(path: '/picked'),
      );
      final results = await resolver.resolveAll(const []);
      expect(results, isEmpty);
      expect(scanner.scanCount, 0);
    });

    test(
      'rebase prefers the candidate with the longest shared path tail',
      () async {
        final scanner = _ListScanner(const [
          ScannedFile(
            basename: 'shark.jpg',
            handle: MediaHandle.localPath('/picked/x/shark.jpg'),
          ),
          ScannedFile(
            basename: 'shark.jpg',
            handle: MediaHandle.localPath('/picked/Diving/shark.jpg'),
          ),
        ]);
        final resolver = PhotoResolver(
          scanner: scanner,
          folder: const GrantedFolder(path: '/picked'),
        );
        final results = await resolver.resolveAll(const [
          ImportImageRef(
            originalPath: '/old/Diving/shark.jpg',
            diveSourceUuid: 'd',
          ),
        ]);
        expect(results.single.kind, PhotoResolutionKind.rebased);
        expect(
          results.single.scannedFile!.handle.localPath,
          '/picked/Diving/shark.jpg',
        );
      },
    );
  });
}
