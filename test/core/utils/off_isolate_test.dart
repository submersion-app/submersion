import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/off_isolate.dart';

String? _isolateName() => Isolate.current.debugName;

void main() {
  test('below the threshold it runs on this isolate', () async {
    final name = await runOffIsolate(
      _isolateName,
      bytes: kOffIsolateMinBytes - 1,
    );
    expect(name, Isolate.current.debugName);
  });

  test('at the threshold it runs on another isolate', () async {
    final name = await runOffIsolate(_isolateName, bytes: kOffIsolateMinBytes);
    expect(name, isNot(Isolate.current.debugName));
  });

  test('a caller can lift the threshold', () async {
    final name = await runOffIsolate(
      _isolateName,
      bytes: kOffIsolateMinBytes,
      minBytes: kOffIsolateMinBytes + 1,
    );
    expect(name, Isolate.current.debugName);
  });

  test('an expected error is rethrown without running inline', () async {
    var inlineRuns = 0;
    await expectLater(
      runOffIsolate<int>(
        () {
          inlineRuns++;
          return 1;
        },
        bytes: kOffIsolateMinBytes,
        isExpected: (e) => e is FormatException,
        runner: <R>(work) async => throw const FormatException('bad'),
      ),
      throwsFormatException,
    );
    expect(inlineRuns, 0);
  });

  test('a spawn failure reruns inline', () async {
    final value = await runOffIsolate(
      () => 7,
      bytes: kOffIsolateMinBytes,
      runner: <R>(work) async => throw IsolateSpawnException('no isolate'),
    );
    expect(value, 7);
  });

  test('an isolate that dies reruns inline', () async {
    final value = await runOffIsolate(
      () => 7,
      bytes: kOffIsolateMinBytes,
      runner: <R>(work) async => throw RemoteError('ended', ''),
    );
    expect(value, 7);
  });

  test('a closure that cannot be sent reruns inline', () async {
    final port = ReceivePort();
    addTearDown(port.close);
    final value = await runOffIsolate(
      () => port.hashCode.isEven ? 7 : 7,
      bytes: kOffIsolateMinBytes,
    );
    expect(value, 7);
  });

  test('a real failure surfaces from the inline rerun', () async {
    await expectLater(
      runOffIsolate<int>(
        () => throw StateError('real'),
        bytes: kOffIsolateMinBytes,
      ),
      throwsStateError,
    );
  });
}
