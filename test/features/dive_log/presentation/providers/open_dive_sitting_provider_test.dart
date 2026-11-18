import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/open_dive_sitting_provider.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// What a file dropped on a dive does under the dive's lock (issue #4527,
/// plan 6).
void main() {
  final dive = Dive(id: 'dive-1', dateTime: DateTime.utc(2026));

  OpenDiveSitting open(EditSession<Dive> session) =>
      OpenDiveSitting(diveId: 'dive-1', session: session, showMediaCard: () {});
  test('a locked dive, page or pane: refused', () {
    expect(diveDropAnswer(open: null, diveId: 'dive-1'), DiveDropAnswer.refuse);
  });

  test("in a sitting on that dive: held; on another dive's: refused", () {
    final session = EditSession<Dive>(dive);
    addTearDown(session.dispose);
    expect(
      diveDropAnswer(open: open(session), diveId: 'dive-1'),
      DiveDropAnswer.hold,
    );
    expect(
      diveDropAnswer(open: open(session), diveId: 'dive-2'),
      DiveDropAnswer.refuse,
    );
  });

  test('a sitting being saved, or ended: refused', () {
    final saving = EditSession<Dive>(dive)..freeze();
    addTearDown(saving.dispose);
    expect(
      diveDropAnswer(open: open(saving), diveId: 'dive-1'),
      DiveDropAnswer.refuse,
    );
    final ended = EditSession<Dive>(dive)..dispose();
    expect(
      diveDropAnswer(open: open(ended), diveId: 'dive-1'),
      DiveDropAnswer.refuse,
    );
  });
}
