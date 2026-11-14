import 'package:flutter/foundation.dart';

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
  });

  /// Unique within a record type, such as `'notes'`.
  final String id;

  /// The card that owns this value. A change marks that card as changed.
  final String cardId;

  final V Function(T record) read;

  /// [record] with this field set to [value]. Never mutates [record].
  final T Function(T record, V value) write;

  /// Whether two values are the same for this field. Null means `==`. A
  /// list whose order carries no meaning supplies its own.
  final bool Function(V a, V b)? equals;

  bool same(V a, V b) => equals?.call(a, b) ?? a == b;
}
