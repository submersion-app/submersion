import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/record_editing/held_write_undo.dart';

/// Taking back what a sitting's held writes did outside the database when
/// its save fails (issue #4527): one helper for the dive's media and the
/// photo's relink.
void main() {
  test('a save that goes through takes nothing back', () async {
    var asked = 0;

    final result = await undoHeldWritesOnFailure(
      () async => 7,
      takeUndo: () {
        asked++;
        return [() async {}];
      },
      what: 'a test write',
    );

    expect(result, 7);
    expect(asked, 0);
  });

  test('a save that fails runs every step, each on its own, then lets the '
      'failure through', () async {
    final ran = <String>[];

    final run = undoHeldWritesOnFailure<void>(
      () async => throw StateError('disk full'),
      takeUndo: () => [
        () async => ran.add('first'),
        () async => throw StateError('bookmark gone'),
        () async => ran.add('third'),
      ],
      what: 'a test write',
    );

    await expectLater(
      run,
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', 'disk full'),
      ),
    );
    expect(ran, ['first', 'third']);
  });

  test('a failure with nothing to take back is let through', () async {
    await expectLater(
      undoHeldWritesOnFailure<void>(
        () async => throw StateError('disk full'),
        takeUndo: () => null,
        what: 'a test write',
      ),
      throwsStateError,
    );
  });
}
