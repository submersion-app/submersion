import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/open_dive_sitting_provider.dart';
import 'package:submersion/features/media/presentation/helpers/media_move_to_dive.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Move to dive refuses a dive that is open for editing, the opposite of a
/// dropped file, which is held by an open dive and refused by a locked one
/// (issue #4527, media library plan 1).
void main() {
  OpenDiveSitting open(String diveId, EditSession<Dive> session) =>
      OpenDiveSitting(diveId: diveId, session: session, showMediaCard: () {});

  EditSession<Dive> session(String diveId) {
    final s = EditSession<Dive>(Dive(id: diveId, dateTime: DateTime.utc(2026)));
    addTearDown(() {
      if (!s.isDisposed) s.dispose();
    });
    return s;
  }

  test('no open dive never refuses', () {
    expect(
      moveTouchesOpenDive(
        open: null,
        targetDiveId: 'd2',
        fromDiveIds: ['d1', null],
      ),
      isFalse,
    );
  });

  test('the target open, with no changes, refuses', () {
    expect(
      moveTouchesOpenDive(
        open: open('d2', session('d2')),
        targetDiveId: 'd2',
        fromDiveIds: ['d1'],
      ),
      isTrue,
    );
  });

  test('a source dive open refuses', () {
    expect(
      moveTouchesOpenDive(
        open: open('d1', session('d1')),
        targetDiveId: 'd2',
        fromDiveIds: ['d1', null],
      ),
      isTrue,
    );
  });

  test('another dive open does not refuse', () {
    expect(
      moveTouchesOpenDive(
        open: open('d9', session('d9')),
        targetDiveId: 'd2',
        fromDiveIds: ['d1'],
      ),
      isFalse,
    );
  });

  test('a row on no dive never matches', () {
    expect(
      moveTouchesOpenDive(
        open: open('d9', session('d9')),
        targetDiveId: 'd2',
        fromDiveIds: [null],
      ),
      isFalse,
    );
  });

  test('a dive being saved still refuses', () {
    final saving = session('d2')..freeze();
    expect(
      moveTouchesOpenDive(
        open: open('d2', saving),
        targetDiveId: 'd2',
        fromDiveIds: const [],
      ),
      isTrue,
    );
  });

  test('a disposed sitting is not open', () {
    final ended = session('d2')..dispose();
    expect(
      moveTouchesOpenDive(
        open: open('d2', ended),
        targetDiveId: 'd2',
        fromDiveIds: const [],
      ),
      isFalse,
    );
  });
}
