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

  test('Linux takes plain ONNX Runtime', () {
    expect(
      ortArchiveFor('linux', 'x64')!.libraries.single.entry,
      'runtimes/linux-x64/native/libonnxruntime.so',
    );
  });

  test("Windows takes Windows ML's package: ONNX Runtime, DirectML and the "
      'catalogue, each bound or loaded by its own name', () {
    final windows = ortArchiveFor('windows', 'x64')!;
    expect(
      windows.url,
      contains('microsoft.windows.ai.machinelearning/2.5.96/'),
    );
    expect(
      {for (final l in windows.libraries) l.assetName: l.entry},
      {
        ortNativeAsset: 'runtimes/win-x64/native/onnxruntime.dll',
        winMlNativeAsset:
            'runtimes/win-x64/native/Microsoft.Windows.AI.MachineLearning.dll',
        directMlAsset: 'runtimes/win-x64/native/DirectML.dll',
      },
    );
  });

  test('Apple platforms, the web and 32-bit Android get nothing', () {
    expect(ortArchiveFor('macos', 'arm64'), isNull);
    expect(ortArchiveFor('ios', 'arm64'), isNull);
    expect(ortArchiveFor('android', 'arm'), isNull);
    expect(ortArchiveFor('android', 'ia32'), isNull);
  });
}
