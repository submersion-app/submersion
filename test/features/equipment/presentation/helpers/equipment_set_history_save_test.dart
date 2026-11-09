import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/presentation/helpers/equipment_set_history_save.dart';

/// The writes that follow a set's save, then the replay of its members on
/// the dives that carry it (issue #4283): the replay runs whatever those
/// writes do, as the members are already saved.
void main() {
  test('runs the replay after the writes', () async {
    final calls = <String>[];
    await saveThenReplay(
      () async => calls.add('save'),
      () async => calls.add('replay'),
    );
    expect(calls, ['save', 'replay']);
  });

  test(
    'a failed write still replays, and its error is the one thrown',
    () async {
      final calls = <String>[];
      await expectLater(
        saveThenReplay(
          () async => throw StateError('save'),
          () async => calls.add('replay'),
        ),
        throwsA(isA<StateError>().having((e) => e.message, 'message', 'save')),
      );
      expect(calls, ['replay']);
    },
  );

  test('a replay that also fails does not hide the write error', () async {
    await expectLater(
      saveThenReplay(
        () async => throw StateError('save'),
        () async => throw StateError('replay'),
      ),
      throwsA(isA<StateError>().having((e) => e.message, 'message', 'save')),
    );
  });

  test('a failed replay after a clean write is thrown', () async {
    await expectLater(
      saveThenReplay(() async {}, () async => throw StateError('replay')),
      throwsA(isA<StateError>().having((e) => e.message, 'message', 'replay')),
    );
  });

  test('no replay step is fine', () async {
    var saved = false;
    await saveThenReplay(() async => saved = true, null);
    expect(saved, isTrue);
  });
}
