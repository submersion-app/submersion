import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'source_mask.dart';

/// The web app compiles lib/ to JavaScript, where an int is a double and two
/// things that work on the VM go wrong without a word from any VM test
/// (issue #4194):
///
/// - A shift by 32 or more, in decimal or hex, is zero: `1 << 62` folds to
///   0, and `Random().nextInt(1 << 32)` throws. Write the value as a
///   literal (`0x100000000`), which is exact up to 2^53.
/// - ByteData's 64-bit accessors (`getInt64`, `setUint64` and the rest)
///   and the 64-bit typed lists (`Int64List`, `Uint64List`) throw "not
///   supported by dart2js". Write a uint64 with `setUint64Halves`
///   (lib/core/utils/uint64_halves.dart).
///
/// A file the browser never reaches may keep them, listed in [nativeOnly]
/// with the capability that keeps it off the web.
void main() {
  const nativeOnly = <String, String>{
    'lib/features/media/data/services/isobmff_boxes.dart':
        'mediaAttach is false in DeviceCapabilities.web',
    'lib/features/media/data/services/gpmf_gps_reader.dart':
        'mediaAttach is false in DeviceCapabilities.web',
  };
  final trap = RegExp(
    r'(?:<<|>>>?)=?\s*(?:3[2-9]|[4-9]\d|\d{3,}|'
    r'0[xX]0*(?:[2-9a-fA-F][0-9a-fA-F]|[1-9a-fA-F][0-9a-fA-F]{2,}))\b|'
    r'\.(?:get|set)U?[Ii]nt64\(|'
    r'(?:\b|as)(?:Int|Uint)64List\b',
  );

  List<String> trapsIn(String path) {
    final masked = MaskedSource(File(path).readAsStringSync());
    return [
      for (final match in trap.allMatches(masked.code))
        '$path:${masked.lineOf(match.start)}: ${match.group(0)}',
    ];
  }

  test('every native-only file still needs its exemption', () {
    for (final path in nativeOnly.keys) {
      expect(File(path).existsSync(), isTrue, reason: '$path was moved');
      expect(
        trapsIn(path),
        isNotEmpty,
        reason: '$path no longer needs an entry in nativeOnly',
      );
    }
  });

  test('no file the browser runs shifts by 32 or uses 64-bit ByteData', () {
    final files =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .map((f) => f.path.replaceAll(r'\', '/'))
            .where((path) => !nativeOnly.containsKey(path))
            .toList()
          ..sort();
    final offenders = [for (final path in files) ...trapsIn(path)];
    expect(
      offenders,
      isEmpty,
      reason:
          'These break in the web app (see this test for the fix), or add '
          'the file to nativeOnly if no browser can reach it:\n'
          '${offenders.join('\n')}',
    );
  });
}
