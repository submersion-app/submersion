import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion_vision/onnx_runtime.dart';

/// Runs a one-node model through the real ONNX Runtime. On Linux and
/// Windows the build hook's library is loaded, so the test never skips there
/// (CI runs both); elsewhere it needs `SUBMERSION_ORT_LIBRARY` naming the
/// library, and skips without it.
void main() {
  final libraryPath = Platform.environment['SUBMERSION_ORT_LIBRARY'];
  final hookShips = Platform.isLinux || Platform.isWindows;
  final skip = !hookShips && libraryPath == null
      ? 'no ONNX Runtime library on this machine'
      : null;
  final model = p.join('test', 'fixtures', 'add_one.onnx');

  OrtRuntime open() =>
      OrtRuntime.open(libraryPath: hookShips ? null : libraryPath);

  test('runs a model through ONNX Runtime', () {
    final runtime = open();
    addTearDown(runtime.close);
    final session = runtime.openSession(model);
    addTearDown(session.close);

    final out = session.run(OrtTensor([1, 3], Float32List.fromList([1, 2, 3])));

    expect(out.single.shape, [1, 3]);
    expect(out.single.data, [2, 3, 4]);
    expect(session.device, 'cpu');
  }, skip: skip);

  test('a missing model file throws OrtException', () {
    final runtime = open();
    addTearDown(runtime.close);

    expect(
      () => runtime.openSession(p.join('test', 'fixtures', 'missing.onnx')),
      throwsA(isA<OrtException>()),
    );
  }, skip: skip);

  test('a session runs many times and closes cleanly', () {
    final runtime = open();
    addTearDown(runtime.close);
    final session = runtime.openSession(
      model,
      settings: const OrtSessionSettings(intraOpThreads: 1),
    );
    for (var i = 0; i < 20; i++) {
      final out = session.run(
        OrtTensor([1, 3], Float32List.fromList([i.toDouble(), 0, -1])),
      );
      expect(out.single.data, [i + 1, 1, 0]);
    }
    session.close();
  }, skip: skip);
}
