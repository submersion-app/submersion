import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/export/zip/zip_crypto_writer.dart';

const _password = 'correct horse';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('zip_crypto_writer_test_');
  });
  tearDown(() => dir.delete(recursive: true));

  Future<Uint8List> write(Map<String, List<int>> files) async {
    final path = p.join(dir.path, 'out.zip');
    final writer = ZipCryptoWriter(
      await File(path).open(mode: FileMode.write),
      password: _password,
      random: Random(1),
    );
    for (final e in files.entries) {
      await writer.addFile(
        e.key,
        Uint8List.fromList(e.value),
        modified: DateTime(2026, 10, 17, 9, 30),
      );
    }
    await writer.close();
    return File(path).readAsBytes();
  }

  final rng = Random(7);
  final scan = List<int>.generate(4096, (_) => rng.nextInt(256));
  final files = {
    'a.txt': 'hello'.codeUnits,
    'Dives/#142 Blue Hole 2026-10-12/scan.jpg': scan,
    'empty.txt': <int>[],
    'Certifications/Récif/card.txt': List.filled(500, 65),
  };

  test('round-trips names and content with the password', () async {
    final archive = ZipDecoder().decodeBytes(
      await write(files),
      password: _password,
    );
    expect(archive.files.map((f) => f.name), files.keys);
    for (final f in archive.files) {
      expect(f.content, files[f.name], reason: f.name);
    }
  });

  test('the wrong password does not give the content back', () async {
    final bytes = await write({'a.txt': List.filled(200, 66)});
    List<int>? content;
    try {
      content = ZipDecoder()
          .decodeBytes(bytes, password: 'wrong password')
          .files
          .single
          .content;
    } on Object {
      content = null;
    }
    expect(content, isNot(List.filled(200, 66)));
  });

  test('every header is encrypted, UTF-8 named, with no data '
      'descriptor', () async {
    final bytes = await write(files);
    final view = ByteData.sublistView(bytes);
    var local = 0;
    var central = 0;
    for (var i = 0; i + 4 <= bytes.length; i++) {
      final sig = view.getUint32(i, Endian.little);
      final int flags;
      if (sig == 0x04034b50) {
        flags = view.getUint16(i + 6, Endian.little);
        local++;
      } else if (sig == 0x02014b50) {
        flags = view.getUint16(i + 8, Endian.little);
        central++;
      } else {
        continue;
      }
      expect(flags & 0x1, 0x1, reason: 'encrypted at $i');
      expect(flags & 0x800, 0x800, reason: 'UTF-8 at $i');
      expect(flags & 0x8, 0, reason: 'no data descriptor at $i');
    }
    // Encrypted payloads could in theory contain a signature by chance;
    // the counts prove each real header was checked.
    expect(local, greaterThanOrEqualTo(files.length));
    expect(central, greaterThanOrEqualTo(files.length));
  });

  group('isValidPassword', () {
    test('needs 8 printable ASCII characters', () {
      expect(ZipCryptoWriter.isValidPassword('abcdefgh'), isTrue);
      expect(ZipCryptoWriter.isValidPassword('with space ~!'), isTrue);
      expect(ZipCryptoWriter.isValidPassword('abc'), isFalse);
      expect(ZipCryptoWriter.isValidPassword('pässwörd'), isFalse);
      expect(ZipCryptoWriter.isValidPassword('tab\there12'), isFalse);
    });

    test('an invalid password is refused up front', () async {
      final file = await File(
        p.join(dir.path, 'x.zip'),
      ).open(mode: FileMode.write);
      addTearDown(file.close);
      expect(
        () => ZipCryptoWriter(file, password: 'pässwörd'),
        throwsArgumentError,
      );
    });
  });
}
