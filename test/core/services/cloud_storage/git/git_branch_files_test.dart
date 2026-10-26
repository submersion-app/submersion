import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/git/git_branch_files.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';

Uint8List _json(String s) => Uint8List.fromList(utf8.encode(s));

final GitObjectId _blob = GitObjectId.fromHex('a' * 40);

void main() {
  group('GitIndex', () {
    test('a known size round-trips', () {
      final index = GitIndex({
        'Submersion Sync/a.json': GitIndexEntry(
          blobId: _blob,
          size: 7,
          modifiedMs: 5,
        ),
      });
      final back = GitIndex.decode(index.encode());
      final entry = back.entries['Submersion Sync/a.json']!;
      expect(entry.blobId, _blob);
      expect(entry.size, 7);
      expect(entry.modifiedMs, 5);
    });

    test('an unknown size round-trips and still writes an int size', () {
      final index = GitIndex({
        'Submersion Sync/a.json': GitIndexEntry(
          blobId: _blob,
          size: null,
          modifiedMs: 5,
        ),
      });
      final bytes = index.encode();
      // A reader that predates unknown sizes requires an int size.
      final raw = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
      final file =
          (raw['files']! as Map<String, Object?>)['Submersion Sync/a.json']!
              as Map<String, Object?>;
      expect(file['size'], 0);
      expect(
        GitIndex.decode(bytes).entries['Submersion Sync/a.json']!.size,
        isNull,
      );
    });

    test('a malformed entry is skipped, keeping the others', () {
      final index = GitIndex.decode(
        _json(
          '{"version":1,"files":{'
          '"a":{"blob":"${'b' * 40}","size":"4","mtime":1},'
          '"b":{"blob":"${'b' * 40}","size":4,"mtime":1},'
          '"c":{"blob":"not hex","size":4,"mtime":1},'
          '"d":{"blob":"${'b' * 40}","size":-1,"mtime":1},'
          '"e":{"blob":"${'b' * 40}","size":4,"mtime":-1}}}',
        ),
      );
      expect(index.entries.keys, ['b']);
    });

    test('an index from a newer version is GitIndexTooNew', () {
      expect(
        () => GitIndex.decode(_json('{"version":2,"files":{}}')),
        throwsA(isA<GitIndexTooNew>()),
      );
    });

    for (final (name, content) in [
      ('not JSON', '{not json'),
      ('not an object', '[]'),
      ('without a version', '{"files":{}}'),
      ('without a files map', '{"version":1}'),
    ]) {
      test('an index $name is a FormatException', () {
        expect(
          () => GitIndex.decode(_json(content)),
          throwsA(allOf(isA<FormatException>(), isNot(isA<GitIndexTooNew>()))),
        );
      });
    }
  });
}
