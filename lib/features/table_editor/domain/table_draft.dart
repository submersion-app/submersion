import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Why a draft cannot be saved as it stands (#3422).
enum TableDraftFlag {
  /// The text did not parse as the column's kind.
  unparsable,

  /// The text matched no entry of a list column.
  unknownValue,

  /// One half of a coordinate pair drafted on a record without the other.
  pairIncomplete,

  /// The stored value moved since the draft was made (a sync or import).
  changedElsewhere,
}

/// One cell of the sheet: a record and a column, by `EntityField.name`.
@immutable
class CellPosition extends Equatable {
  final String entityId;
  final String fieldName;

  const CellPosition(this.entityId, this.fieldName);

  @override
  List<Object?> get props => [entityId, fieldName];
}

/// A pending edit to one cell. [original] is the stored value the cell
/// showed when the draft was made (metric, enum name or id, never display
/// text) and [value] the stored value to write; null clears the field.
/// [rawText] keeps what was typed or pasted so a flagged cell can show it.
@immutable
class TableDraft extends Equatable {
  final String entityId;
  final String fieldName;
  final Object? original;
  final Object? value;
  final String? rawText;
  final TableDraftFlag? flag;

  const TableDraft({
    required this.entityId,
    required this.fieldName,
    required this.original,
    required this.value,
    this.rawText,
    this.flag,
  });

  CellPosition get position => CellPosition(entityId, fieldName);

  bool get isSaveable => flag == null;

  /// Whether saving replaces a value rather than filling an empty one.
  bool get overwrites =>
      original != null &&
      original != '' &&
      !(original is List && (original! as List).isEmpty);

  /// Whether [value] is what is already stored.
  bool get isUnchanged =>
      const DeepCollectionEquality().equals(value, original);

  TableDraft copyWith({
    Object? value,
    bool clearValue = false,
    Object? original,
    bool clearOriginal = false,
    String? rawText,
    TableDraftFlag? flag,
    bool clearFlag = false,
  }) => TableDraft(
    entityId: entityId,
    fieldName: fieldName,
    original: clearOriginal ? null : (original ?? this.original),
    value: clearValue ? null : (value ?? this.value),
    rawText: rawText ?? this.rawText,
    flag: clearFlag ? null : (flag ?? this.flag),
  );

  @override
  List<Object?> get props => [
    entityId,
    fieldName,
    original,
    value,
    rawText,
    flag,
  ];
}
