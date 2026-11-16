import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Counts the times [field]'s stored value changed underneath a sitting
/// that follows it, for an editor whose rows keep their own text.
///
/// A row built from a value (a cylinder, a weight) shows the text it was
/// built with until its key moves. A change that arrives underneath the
/// sitting (a sync) moves a value the diver has not touched, and the row
/// would go on showing the old one, which its next keystroke writes back.
/// Key the rows with [generationOf] and they are built again then. While
/// the diver holds a change of [field], the sitting shows theirs, so the
/// rows are left alone.
class StoredFollow<T, V> {
  StoredFollow(this.field);

  final EditField<T, V> field;

  late V _seen;
  bool _hasSeen = false;
  int _generation = 0;

  /// Call when building the rows over [session].
  int generationOf(EditSession<T> session) {
    final stored = field.read(session.stored);
    if (_hasSeen &&
        !field.same(_seen, stored) &&
        field.same(session.valueOf(field), stored)) {
      _generation++;
    }
    _seen = stored;
    _hasSeen = true;
    return _generation;
  }
}
