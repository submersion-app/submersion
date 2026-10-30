import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';
import 'package:submersion/core/services/cloud_storage/git/pack_inflater.dart';
import 'package:submersion/core/services/cloud_storage/git/pack_reader.dart';

final _fixtures = p.join('test', 'fixtures', 'git');

Uint8List _fixture(String name) =>
    File(p.join(_fixtures, name)).readAsBytesSync();

Set<String> _ids(String name) => File(
  p.join(_fixtures, name),
).readAsLinesSync().where((l) => l.trim().isNotEmpty).toSet();

void main() {
  group('inflateAt', () {
    test('reports the exact length of each of 200 back-to-back streams', () {
      // A reader that over-reads by even one byte loses its place in a pack,
      // and tiny objects packed together are where that shows.
      final out = BytesBuilder();
      final starts = <int>[];
      final payloads = <String>[];
      for (var i = 0; i < 200; i++) {
        final text = 'object $i ${'x' * (i % 7)}';
        starts.add(out.length);
        payloads.add(text);
        out.add(ZLibEncoder().convert(utf8.encode(text)));
      }
      final buf = out.takeBytes();
      for (var i = 0; i < 200; i++) {
        final r = inflateAt(buf, starts[i]);
        expect(utf8.decode(r.data), payloads[i]);
        final end = i + 1 < 200 ? starts[i + 1] : buf.length;
        expect(r.consumed, end - starts[i], reason: 'stream $i');
      }
    });

    test('a corrupt stream throws a GitException', () {
      final buf = Uint8List.fromList(ZLibEncoder().convert(utf8.encode('hi')));
      buf[buf.length - 1] ^= 0xff; // break the Adler-32 trailer
      expect(() => inflateAt(buf, 0), throwsA(isA<GitException>()));
    });
  });

  group('readPack', () {
    test(
      'stores exactly the objects stock git packed, each self-hashing',
      () async {
        final store = MemoryGitObjectStore();
        final ids = await readPack(_fixture('full.pack'), store);
        expect(ids.map((id) => id.hex).toSet(), _ids('full_ids.txt'));
        for (final id in ids) {
          final object = (await store.get(id))!;
          expect(hashGitObject(object.type, object.body), id);
        }
      },
    );

    test(
      'resolves a thin REF_DELTA pack against objects already stored',
      () async {
        final store = MemoryGitObjectStore();
        await readPack(_fixture('full.pack'), store);
        final ids = await readPack(_fixture('thin_refdelta.pack'), store);
        expect(ids.map((id) => id.hex).toSet(), _ids('thin_ids.txt'));
      },
    );

    test('a thin pack whose delta bases are missing throws', () async {
      await expectLater(
        readPack(_fixture('thin_refdelta.pack'), MemoryGitObjectStore()),
        throwsA(isA<GitException>()),
      );
    });

    test('a flipped trailer byte throws', () async {
      final pack = _fixture('full.pack');
      pack[pack.length - 1] ^= 0x01;
      await expectLater(
        readPack(pack, MemoryGitObjectStore()),
        throwsA(isA<GitException>()),
      );
    });

    test('a buffer that is not a pack throws', () async {
      await expectLater(
        readPack(
          Uint8List.fromList(ascii.encode('<html>')),
          MemoryGitObjectStore(),
        ),
        throwsA(isA<GitException>()),
      );
    });
  });
}
