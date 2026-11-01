import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/table_editor/domain/cell_parsers.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/domain/table_editor_column.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// Factories for the common column shapes (#3422), so each entity's column
/// list reads as a table of fields rather than a wall of closures.

typedef Editable<T> = bool Function(T entity);
typedef ReadOnlyReason<T> = String? Function(T entity, AppLocalizations l10n);

/// A free-text column. With [required], a blank cell is rejected instead of
/// clearing the field (a site or center cannot lose its name).
TableEditorColumn<T, F> textColumn<T, F extends EntityField>(
  F field,
  String? Function(T entity) get, {
  bool required = false,
  Editable<T>? isEditable,
  ReadOnlyReason<T>? readOnlyReason,
}) => TableEditorColumn<T, F>(
  field: field,
  kind: CellEditorKind.text,
  valueOf: get,
  editText: (e, _) => get(e) ?? '',
  parse: (text, _, _) => switch (parseTextCell(text)) {
    CellParsed(value: null) when required => const CellRejected(
      TableDraftFlag.unparsable,
    ),
    final r => r,
  },
  isEditable: isEditable,
  readOnlyReason: readOnlyReason,
);

/// A number typed in the diver's unit and stored converted. [toDisplay] and
/// [toStored] are the two directions of that conversion. The cell opens at
/// two decimals, since a conversion leaves a long tail no one can edit; an
/// untouched cell writes nothing, so the rounding never reaches the store.
TableEditorColumn<T, F> numberColumn<T, F extends EntityField>(
  F field,
  double? Function(T entity) get, {
  required double Function(UnitFormatter units, double value) toDisplay,
  required double Function(UnitFormatter units, double value) toStored,
  String? Function(UnitFormatter units)? symbol,
  double? min,
  double? max,
  Editable<T>? isEditable,
  ReadOnlyReason<T>? readOnlyReason,
}) => TableEditorColumn<T, F>(
  field: field,
  kind: CellEditorKind.number,
  valueOf: get,
  editText: (e, u) {
    final v = get(e);
    return v == null ? '' : formatRoundedForInput(toDisplay(u, v), 2);
  },
  parse: (text, u, _) => parseNumberCell(
    text,
    toStored: (v) => toStored(u, v),
    min: min,
    max: max,
  ),
  unitSymbol: symbol,
  isEditable: isEditable,
  readOnlyReason: readOnlyReason,
);

/// A number with no unit (a rating, a percentage, a pressure in bar).
TableEditorColumn<T, F> plainNumberColumn<T, F extends EntityField>(
  F field,
  double? Function(T entity) get, {
  String? symbol,
  double? min,
  double? max,
  Editable<T>? isEditable,
  ReadOnlyReason<T>? readOnlyReason,
}) => numberColumn<T, F>(
  field,
  get,
  toDisplay: (_, v) => v,
  toStored: (_, v) => v,
  symbol: (_) => symbol,
  min: min,
  max: max,
  isEditable: isEditable,
  readOnlyReason: readOnlyReason,
);

TableEditorColumn<T, F> integerColumn<T, F extends EntityField>(
  F field,
  int? Function(T entity) get, {
  int? min,
  int? max,
  Editable<T>? isEditable,
  ReadOnlyReason<T>? readOnlyReason,
}) => TableEditorColumn<T, F>(
  field: field,
  kind: CellEditorKind.integer,
  valueOf: get,
  editText: (e, _) => get(e)?.toString() ?? '',
  parse: (text, _, _) => parseIntegerCell(text, min: min, max: max),
  isEditable: isEditable,
  readOnlyReason: readOnlyReason,
  // An int reads as itself; the adapter may expect another type (a
  // Duration for a surface interval) and show the placeholder instead.
  displayValue: (v, _) => v.toString(),
);

/// Decimal degrees: 90 for a latitude, 180 for a longitude.
TableEditorColumn<T, F> degreesColumn<T, F extends EntityField>(
  F field,
  double? Function(T entity) get, {
  required double limit,
  Editable<T>? isEditable,
  ReadOnlyReason<T>? readOnlyReason,
}) => TableEditorColumn<T, F>(
  field: field,
  kind: CellEditorKind.number,
  valueOf: get,
  editText: (e, _) {
    final v = get(e);
    return v == null ? '' : formatDecimalForInput(v);
  },
  parse: (text, _, _) => parseDegreesCell(text, limit: limit),
  unitSymbol: (_) => '°',
  isEditable: isEditable,
  readOnlyReason: readOnlyReason,
);

TableEditorColumn<T, F> toggleColumn<T, F extends EntityField>(
  F field,
  bool Function(T entity) get, {
  Editable<T>? isEditable,
  ReadOnlyReason<T>? readOnlyReason,
}) => TableEditorColumn<T, F>(
  field: field,
  kind: CellEditorKind.toggle,
  valueOf: get,
  parse: (text, _, l) => parseToggleCell(text, l),
  isEditable: isEditable,
  readOnlyReason: readOnlyReason,
);

/// One value of an enum, stored by its name.
TableEditorColumn<T, F> choiceColumn<T, F extends EntityField, E extends Enum>(
  F field,
  E? Function(T entity) get,
  List<E> values,
  String Function(E value, AppLocalizations l10n) label, {
  Editable<T>? isEditable,
  ReadOnlyReason<T>? readOnlyReason,
}) {
  List<ChoiceOption> options(AppLocalizations l) => [
    for (final v in values) ChoiceOption(v.name, label(v, l)),
  ];
  return TableEditorColumn<T, F>(
    field: field,
    kind: CellEditorKind.choice,
    valueOf: (e) => get(e)?.name,
    choices: options,
    parse: (text, _, l) => parseChoiceCell(text, options(l)),
    isEditable: isEditable,
    readOnlyReason: readOnlyReason,
  );
}

/// Several values of an enum, stored as a list of names.
TableEditorColumn<T, F>
multiChoiceColumn<T, F extends EntityField, E extends Enum>(
  F field,
  List<E> Function(T entity) get,
  List<E> values,
  String Function(E value, AppLocalizations l10n) label, {
  Editable<T>? isEditable,
  ReadOnlyReason<T>? readOnlyReason,
}) {
  List<ChoiceOption> options(AppLocalizations l) => [
    for (final v in values) ChoiceOption(v.name, label(v, l)),
  ];
  return TableEditorColumn<T, F>(
    field: field,
    kind: CellEditorKind.multiChoice,
    valueOf: (e) => [for (final v in get(e)) v.name],
    choices: options,
    parse: (text, _, l) => parseMultiChoiceCell(text, options(l)),
    isEditable: isEditable,
    readOnlyReason: readOnlyReason,
  );
}

/// A link to another record, stored by id and picked from [options].
TableEditorColumn<T, F> referenceColumn<T, F extends EntityField>(
  F field,
  String? Function(T entity) get,
  List<ChoiceOption> options, {
  Editable<T>? isEditable,
  ReadOnlyReason<T>? readOnlyReason,
}) => TableEditorColumn<T, F>(
  field: field,
  kind: CellEditorKind.reference,
  valueOf: get,
  choices: (_) => options,
  parse: (text, _, _) => parseChoiceCell(text, options),
  isEditable: isEditable,
  readOnlyReason: readOnlyReason,
);
