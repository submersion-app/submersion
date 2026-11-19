import 'package:flutter/foundation.dart';

import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// One editable value of a record of type [T].
///
/// A field knows how to read its value from a record and how to write a new
/// one onto it, so an [EditSession] can track what the diver changed value
/// by value and apply only that to the record as it is stored at save time.
@immutable
class EditField<T, V> {
  const EditField({
    required this.id,
    required this.cardId,
    required this.read,
    required this.write,
    this.equals,
    this.alsoShownOn = const {},
  });

  /// Unique within a record type, such as `'notes'`.
  final String id;

  /// The card that owns this value. A change marks that card as changed.
  final String cardId;

  /// Other cards that show this value without owning it. They are not
  /// marked as changed, but they are redrawn when it changes.
  final Set<String> alsoShownOn;

  final V Function(T record) read;

  /// [record] with this field set to [value]. Never mutates [record].
  final T Function(T record, V value) write;

  /// Whether two values are the same for this field. Null means `==`. A
  /// list whose order carries no meaning supplies its own.
  final bool Function(V a, V b)? equals;

  bool same(V a, V b) => equals?.call(a, b) ?? a == b;

  /// Sets this field in [session] to its value in [from], as a change:
  /// a new record copied from another (a duplicate, issue #4527). Through
  /// the field's own value type, which a field held in a list of fields of
  /// mixed types has lost, so [EditSession.set] cannot be called on it.
  void copyFrom(EditSession<T> session, T from) =>
      session.set<V>(this, read(from));
}
