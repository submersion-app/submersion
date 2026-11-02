import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'source_mask.dart';

/// `dart:io`'s `Platform` throws in a browser, so every platform question
/// goes through `HostPlatform`, whose native file is the one place allowed
/// to read `Platform`. A new direct read anywhere else fails here.
void main() {
  const allowed = 'lib/core/platform/host_platform_io.dart';
  final read = RegExp(
    r'(?<![A-Za-z_.$])Platform\.(is[A-Z]\w*|environment|localHostname|'
    r'operatingSystem\w*|localeName|numberOfProcessors|pathSeparator|'
    r'resolvedExecutable|version|script|executable|lineTerminator|'
    r'packageConfig|executableArguments)\b',
  );

  test('the allowed file still reads dart:io Platform', () {
    final file = File(allowed);
    expect(
      file.existsSync(),
      isTrue,
      reason: '$allowed was renamed or removed',
    );
    final code = MaskedSource(file.readAsStringSync()).code;
    expect(
      read.hasMatch(code),
      isTrue,
      reason: '$allowed no longer reads Platform',
    );
  });

  test('no other file under lib/ reads dart:io Platform directly', () {
    final offenders = <String>[];
    final files =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .map((f) => f.path.replaceAll(r'\', '/'))
            .where((path) => path != allowed)
            .toList()
          ..sort();
    for (final path in files) {
      final masked = MaskedSource(File(path).readAsStringSync());
      for (final match in read.allMatches(masked.code)) {
        offenders.add('$path:${masked.lineOf(match.start)}: ${match.group(0)}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Read these through HostPlatform (lib/core/platform/host_platform.dart) '
          'instead of dart:io Platform:\n${offenders.join('\n')}',
    );
  });
}
