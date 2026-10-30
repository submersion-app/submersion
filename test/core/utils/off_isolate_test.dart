import 'dart:isolate';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/utils/bounded_inflate.dart';
import 'package:submersion/core/utils/off_isolate.dart';

String? _isolateName() => Isolate.current.debugName;

/// Statics are per isolate, so this counts inline runs alone: a run on a worker
/// increments the worker's own copy.
var _runsOnThisIsolate = 0;

Never _throwing(Object error) {
  _runsOnThisIsolate++;
  throw error;
}

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

  group('a real isolate', () {
    setUp(() => _runsOnThisIsolate = 0);

    // An error that cannot cross the isolate boundary arrives as a RemoteError,
    // which reads as "the isolate died" and reruns the work on this isolate:
    // right answer, UI stall. These are the errors the callers name.
    for (final (name, error) in <(String, Object)>[
      ('SecretBoxAuthenticationError', SecretBoxAuthenticationError()),
      ('BoundedInflateException', const BoundedInflateException('too big')),
      (
        'GitException',
        GitException(
          'bad pack',
          code: GitErrorCode.unexpected,
          cause: 'a reason',
        ),
      ),
      (
        'GitDeltaBaseMissingException',
        GitDeltaBaseMissingException(GitObjectId.zero),
      ),
    ]) {
      test('carries $name across, with no rerun here', () async {
        await expectLater(
          runOffIsolate<int>(
            () => _throwing(error),
            bytes: kOffIsolateMinBytes,
            isExpected: (e) => e.runtimeType == error.runtimeType,
          ),
          throwsA(predicate<Object>((e) => e.runtimeType == error.runtimeType)),
        );
        expect(_runsOnThisIsolate, 0);
      });
    }

    test('reruns here for an error nobody expected', () async {
      await expectLater(
        runOffIsolate<int>(
          () => _throwing(StateError('real')),
          bytes: kOffIsolateMinBytes,
        ),
        throwsStateError,
      );
      expect(_runsOnThisIsolate, 1);
    });
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
