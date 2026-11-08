import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/platform/zlib/platform_zlib.dart';
import 'package:submersion/features/tides/data/services/fes_grid/fes_grid_layers.dart';
import 'package:submersion/features/tides/data/services/fes_grid/fes_grid_manifest.dart';
import 'package:submersion/features/tides/data/services/fes_grid/fes_grid_packing.dart';

final _fixtures = p.join('test', 'features', 'tides', 'data', 'fixtures');
final _synthetic = p.join(_fixtures, 'fes_grid');
final _bundled = p.join('assets', 'data', 'tide', 'fes');

Uint8List _read(String root, String relative) =>
    File(p.join(root, relative)).readAsBytesSync();

ByteData _view(List<int> bytes) =>
    ByteData.sublistView(Uint8List.fromList(bytes));

Map<String, String> _digests(String path) =>
    (json.decode(File(path).readAsStringSync()) as Map<String, dynamic>)
        .cast<String, String>();

Future<ByteData> _unpack(String relative, ByteData packed) =>
    relative == FesGridManifest.globalPath
    ? unpackFesGlobalLayer(packed)
    : unpackFesTile(packed);

String _sha256(ByteData data) => sha256
    .convert(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes))
    .toString();

/// A packed file's header with [body] deflated after it.
ByteData _repacked(Uint8List packed, int headerBytes, List<int> body) =>
    _view([...packed.sublist(0, headerBytes), ...PlatformZlib.deflate(body)]);

void main() {
  test('every synthetic file unpacks to its exact decoded bytes', () async {
    final digests = _digests(p.join(_synthetic, 'decoded_sha256.json'));
    expect(digests, hasLength(5));
    for (final MapEntry(key: relative, value: digest) in digests.entries) {
      final decoded = await _unpack(
        relative,
        _view(_read(_synthetic, relative)),
      );
      expect(_sha256(decoded), digest, reason: relative);
    }
  });

  test(
    'every bundled file unpacks to the exact bytes it was packed from',
    () async {
      final manifest = FesGridManifest.parse(
        File(p.join(_bundled, FesGridManifest.manifestPath)).readAsStringSync(),
      );
      final digests = _digests(
        p.join(_fixtures, 'fes_grid_decoded_sha256.json'),
      );
      expect(digests.keys.toSet(), {
        FesGridManifest.globalPath,
        for (final (row, col) in manifest.coastalTiles)
          FesGridManifest.tilePath(row, col),
      });
      for (final MapEntry(key: relative, value: digest) in digests.entries) {
        final decoded = await _unpack(
          relative,
          _view(_read(_bundled, relative)),
        );
        expect(_sha256(decoded), digest, reason: relative);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  group('unpackFesTile', () {
    final relative = FesGridManifest.tilePath(0, 0);

    test('restores the row counts the packed file leaves out', () async {
      final tile = FesTile.parse(
        await unpackFesTile(_view(_read(_synthetic, relative))),
        expectedConstituents: 2,
      );
      expect(tile.cellAt(3, 3)!.amplitudeMeters(0), closeTo(1.303, 1e-9));
    });

    test(
      'a decoded tile, a wrong version or a short header is rejected',
      () async {
        final packed = _read(_synthetic, relative);
        final decoded = await unpackFesTile(_view(packed));
        await expectLater(unpackFesTile(decoded), throwsFormatException);

        final wrongVersion = Uint8List.fromList(packed)..[4] = 3;
        await expectLater(
          unpackFesTile(_view(wrongVersion)),
          throwsFormatException,
        );
        await expectLater(
          unpackFesTile(_view(packed.sublist(0, 10))),
          throwsFormatException,
        );
      },
    );

    test('a corrupt or truncated deflate stream is rejected', () async {
      final packed = _read(_synthetic, relative);
      await expectLater(
        unpackFesTile(_view(packed.sublist(0, packed.length - 6))),
        throwsFormatException,
      );
      final flipped = Uint8List.fromList(packed)..[packed.length - 1] ^= 0xff;
      await expectLater(unpackFesTile(_view(flipped)), throwsFormatException);
    });

    test('a body that disagrees with its bitmap is rejected', () async {
      final packed = _read(_synthetic, relative);
      final body = PlatformZlib.inflate(packed.sublist(16));
      await expectLater(
        unpackFesTile(_repacked(packed, 16, body.sublist(0, body.length - 1))),
        throwsFormatException,
      );
      await expectLater(
        unpackFesTile(_repacked(packed, 16, [...body, 0])),
        throwsFormatException,
      );
    });
  });

  group('unpackFesGlobalLayer', () {
    const relative = FesGridManifest.globalPath;

    test('restores a layer the global parser reads', () async {
      final layer = FesGlobalLayer.parse(
        await unpackFesGlobalLayer(_view(_read(_synthetic, relative))),
        expectedConstituents: 2,
      );
      expect(layer.cellAt(2, 3)!.amplitudeMeters(0), closeTo(2.023, 1e-9));
      expect(layer.cellAt(0, 0), isNull);
    });

    test('a decoded layer or a body of the wrong length is rejected', () async {
      final packed = _read(_synthetic, relative);
      final decoded = await unpackFesGlobalLayer(_view(packed));
      await expectLater(unpackFesGlobalLayer(decoded), throwsFormatException);

      final body = PlatformZlib.inflate(packed.sublist(12));
      await expectLater(
        unpackFesGlobalLayer(
          _repacked(packed, 12, body.sublist(0, body.length - 2)),
        ),
        throwsFormatException,
      );
      await expectLater(
        unpackFesGlobalLayer(_repacked(packed, 12, [...body, 0, 0])),
        throwsFormatException,
      );
    });
  });
}
