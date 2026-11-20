import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_vision/src/ort/ort_release.dart';

void main() {
  final hex64 = RegExp(r'^[0-9a-f]{64}$');

  test('every shipped target has a pinned, checked download', () {
    for (final target in [
      ('android', 'arm64'),
      ('android', 'x64'),
      ('linux', 'x64'),
      ('windows', 'x64'),
    ]) {
      final archive = ortArchiveFor(target.$1, target.$2);
      expect(archive, isNotNull, reason: '$target');
      expect(Uri.parse(archive!.url).scheme, 'https', reason: '$target');
      expect(archive.sha256, matches(hex64), reason: '$target');
      expect(archive.libraries, isNotEmpty, reason: '$target');
      for (final library in archive.libraries) {
        expect(library.sha256, matches(hex64), reason: library.entry);
      }
      expect(
        archive.libraries.map((l) => l.assetName),
        contains(ortNativeAsset),
        reason: '$target ships ONNX Runtime',
      );
    }
  });

  test('Android takes each ABI\'s own library', () {
    expect(
      ortArchiveFor('android', 'arm64')!.libraries.single.entry,
      'jni/arm64-v8a/libonnxruntime.so',
    );
    expect(
      ortArchiveFor('android', 'x64')!.libraries.single.entry,
      'jni/x86_64/libonnxruntime.so',
    );
  });

  test('Windows and Linux take plain ONNX Runtime from one package', () {
    final windows = ortArchiveFor('windows', 'x64')!;
    final linux = ortArchiveFor('linux', 'x64')!;
    expect(windows.url, linux.url);
    expect(windows.libraries.single.entry, endsWith('/onnxruntime.dll'));
    expect(linux.libraries.single.entry, endsWith('/libonnxruntime.so'));
  });

  test('Apple platforms, the web and 32-bit Android get nothing', () {
    expect(ortArchiveFor('macos', 'arm64'), isNull);
    expect(ortArchiveFor('ios', 'arm64'), isNull);
    expect(ortArchiveFor('android', 'arm'), isNull);
    expect(ortArchiveFor('android', 'ia32'), isNull);
  });
}
