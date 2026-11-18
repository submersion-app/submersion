import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/stored_follow.dart';

typedef _Rec = ({String notes, int depth});

final _notes = EditField<_Rec, String>(
  id: 'notes',
  cardId: 'notes',
  read: (r) => r.notes,
  write: (r, v) => (notes: v, depth: r.depth),
);

/// Rows that keep their own text are built again when what they show
/// changes underneath the sitting (issue #4527, plan 5).
void main() {
  test('moves when the stored value changes and the sitting follows it', () {
    final s = EditSession<_Rec>((notes: 'a', depth: 0));
    addTearDown(s.dispose);
    final follow = StoredFollow(_notes);
    expect(follow.generationOf(s), 0);

    s.rebase((notes: 'b', depth: 0));
    expect(follow.generationOf(s), 1);
    expect(follow.generationOf(s), 1);
  });

  test('stays while another value of the record changes', () {
    final s = EditSession<_Rec>((notes: 'a', depth: 0));
    addTearDown(s.dispose);
    final follow = StoredFollow(_notes)..generationOf(s);

    s.rebase((notes: 'a', depth: 4));
    expect(follow.generationOf(s), 0);
  });

  test('stays while the diver holds a change of the value', () {
    final s = EditSession<_Rec>((notes: 'a', depth: 0));
    addTearDown(s.dispose);
    final follow = StoredFollow(_notes)..generationOf(s);
    s.set(_notes, 'mine');

    s.rebase((notes: 'b', depth: 0));
    expect(follow.generationOf(s), 0);
    expect(s.valueOf(_notes), 'mine');
  });
}
