import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_objects.dart';

import '../../../../helpers/git_cli.dart';

void main() {
  group('hashGitObject', () {
    test('empty blob and empty tree hash to Git\'s well-known ids', () {
      expect(
        hashGitObject(GitObjectType.blob, const []).hex,
        'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391',
      );
      expect(
        hashGitObject(GitObjectType.tree, encodeTree(const [])).hex,
        '4b825dc642cb6eb9a060e54bf8d69288fbee4904',
      );
    });

    test('a multi-megabyte blob hashes like git hash-object', () async {
      final dir = tempDirForTest('git_hash_');
      final r = Random(5);
      final body = Uint8List.fromList(
        List.generate(3 * 1024 * 1024 + 7, (_) => r.nextInt(256)),
      );
      final file = File(joinPath(dir, 'big.bin'))..writeAsBytesSync(body);
      expect(
        hashGitObject(GitObjectType.blob, body).hex,
        await runGit(dir, ['hash-object', file.path]),
      );
    }, skip: skipUnlessGit());

    test('blob "hello\\n" hashes like git hash-object', () {
      expect(
        hashGitObject(GitObjectType.blob, utf8.encode('hello\n')).hex,
        'ce013625030ba8dba906f756967f9e9ca394464a',
      );
    });
  });

  group('GitCommit', () {
    test('an author name cannot break the author line', () {
      final commit = GitCommit(
        tree: hashGitObject(GitObjectType.tree, encodeTree(const [])),
        parents: const [],
        authorName: ' Eric <work>\nphone ',
        authorEmail: 'sync@submersion.invalid',
        when: DateTime.utc(2026, 10, 18),
        message: 'Sync',
      );
      final text = utf8.decode(commit.encode());
      expect(
        text,
        contains('author Eric work phone <sync@submersion.invalid> '),
      );
      expect(GitCommit.decode(commit.encode()).authorName, 'Eric work phone');
    });
  });

  group('GitObjectId', () {
    test('round-trips through hex and compares by value', () {
      const hex = 'ce013625030ba8dba906f756967f9e9ca394464a';
      final id = GitObjectId.fromHex(hex);
      expect(id.hex, hex);
      expect(id, GitObjectId.fromHex(hex.toUpperCase()));
      expect(id.hashCode, GitObjectId.fromHex(hex).hashCode);
      expect(GitObjectId.zero.hex, '0' * 40);
    });

    test('rejects hex of the wrong length or alphabet', () {
      expect(() => GitObjectId.fromHex('abc'), throwsFormatException);
      expect(() => GitObjectId.fromHex('z' * 40), throwsFormatException);
      // int.parse would read a sign as part of the number.
      expect(() => GitObjectId.fromHex('+f${'0' * 38}'), throwsFormatException);
      expect(() => GitObjectId.fromHex('-f${'0' * 38}'), throwsFormatException);
    });
  });

  group('GitObjectType', () {
    test('maps pack codes both ways', () {
      for (final type in GitObjectType.values) {
        expect(GitObjectType.fromPackCode(type.packCode), type);
      }
      expect(GitObjectType.blob.wireName, 'blob');
      expect(() => GitObjectType.fromPackCode(6), throwsFormatException);
    });
  });

  group('trees', () {
    test('sorts a directory after a same-prefixed file the way Git does', () {
      // Git orders "a.b" (file) before "a" (tree, compared as "a/") before
      // "a0".
      final blob = hashGitObject(GitObjectType.blob, const []);
      final names = decodeTree(
        encodeTree([
          GitTreeEntry(name: 'a0', mode: kGitModeFile, id: blob),
          GitTreeEntry(name: 'a', mode: kGitModeTree, id: blob),
          GitTreeEntry(name: 'a.b', mode: kGitModeFile, id: blob),
        ]),
      ).map((e) => e.name);
      expect(names, ['a.b', 'a', 'a0']);
    });

    test('round-trips entries, modes and ids', () {
      final blob = hashGitObject(GitObjectType.blob, utf8.encode('x'));
      final entries = decodeTree(
        encodeTree([
          GitTreeEntry(name: 'Submersion Sync', mode: kGitModeTree, id: blob),
          GitTreeEntry(name: 'README.md', mode: kGitModeFile, id: blob),
        ]),
      );
      expect(entries.map((e) => e.name), ['README.md', 'Submersion Sync']);
      expect(entries.first.isTree, isFalse);
      expect(entries.last.isTree, isTrue);
      expect(entries.last.id, blob);
    });
  });

  group('commits', () {
    test('round-trips through encode and decode', () {
      final tree = hashGitObject(GitObjectType.tree, encodeTree(const []));
      final parent = GitObjectId.fromHex(
        'ce013625030ba8dba906f756967f9e9ca394464a',
      );
      for (final parents in [
        <GitObjectId>[],
        [parent],
      ]) {
        final commit = GitCommit(
          tree: tree,
          parents: parents,
          authorName: 'Submersion 1234abcd',
          authorEmail: 'sync@submersion.invalid',
          when: DateTime.utc(2026, 10, 18, 12),
          message: 'Sync from Submersion 1234abcd',
        );
        final back = GitCommit.decode(commit.encode());
        expect(back.tree, tree);
        expect(back.parents, parents);
        expect(back.authorName, 'Submersion 1234abcd');
        expect(back.authorEmail, 'sync@submersion.invalid');
        expect(back.when, DateTime.utc(2026, 10, 18, 12));
        expect(back.message, 'Sync from Submersion 1234abcd');
        expect(back.landedAt, DateTime.utc(2026, 10, 18, 12));
      }
    });

    test('a rebased commit lands at its committer time', () {
      final tree = hashGitObject(GitObjectType.tree, encodeTree(const []));
      final body = utf8.encode(
        'tree ${tree.hex}\n'
        'author A <a@example.test> 1600000000 +0200\n'
        'committer C <c@example.test> 1700000000 -0500\n'
        '\n'
        'rebased\n',
      );
      final commit = GitCommit.decode(Uint8List.fromList(body));
      expect(commit.when.millisecondsSinceEpoch, 1600000000 * 1000);
      expect(commit.landedAt.millisecondsSinceEpoch, 1700000000 * 1000);
    });
  });

  group('interop with stock git', () {
    test('blob, tree and commit ids match git', () async {
      final repo = await initTempRepo();
      final blobHex = await runGit(repo, [
        'hash-object',
        '-w',
        '--stdin',
      ], stdin: 'dive log\n');
      final blob = hashGitObject(GitObjectType.blob, utf8.encode('dive log\n'));
      expect(blob.hex, blobHex);

      final treeHex = await runGit(
        repo,
        ['mktree'],
        stdin:
            '100644 blob $blobHex\tnotes.txt\n100644 blob $blobHex\tz.json\n',
      );
      final tree = hashGitObject(
        GitObjectType.tree,
        encodeTree([
          GitTreeEntry(name: 'z.json', mode: kGitModeFile, id: blob),
          GitTreeEntry(name: 'notes.txt', mode: kGitModeFile, id: blob),
        ]),
      );
      expect(tree.hex, treeHex);

      final commitHex = await runGit(repo, [
        'commit-tree',
        treeHex,
        '-m',
        'Sync from Test Diver',
      ]);
      final commit = GitCommit(
        tree: tree,
        parents: const [],
        authorName: 'Test Diver',
        authorEmail: 'diver@example.test',
        when: DateTime.fromMillisecondsSinceEpoch(
          1700000000 * 1000,
          isUtc: true,
        ),
        message: 'Sync from Test Diver',
      );
      expect(
        hashGitObject(GitObjectType.commit, commit.encode()).hex,
        commitHex,
      );
    }, skip: skipUnlessGit());
  });
}
