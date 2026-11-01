import 'package:flutter/foundation.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// How a cell is edited (#3422).
enum CellEditorKind {
  text,
  number,
  integer,
  choice,
  multiChoice,
  toggle,
  reference,
}

/// One entry of a list column: the stored value and the label shown for it.
@immutable
class ChoiceOption {
  final String value;
  final String label;
  const ChoiceOption(this.value, this.label);
}

/// What a column made of a cell's text.
sealed class CellParseResult {
  const CellParseResult();
}

/// The stored value to write; null clears the field.
class CellParsed extends CellParseResult {
  final Object? value;
  const CellParsed(this.value);
}

/// The text cannot become a value, and why.
class CellRejected extends CellParseResult {
  final TableDraftFlag flag;
  const CellRejected(this.flag);
}

/// An editable column of one tab of the table editor: how its cell opens,
/// what it holds, and how typed text becomes the stored value.
///
/// Values are stored values (metric, enum names, ids), never display text, so
/// a draft's original can be compared with a fresh row at save time.
@immutable
class TableEditorColumn<T, F extends EntityField> {
  final F field;
  final CellEditorKind kind;

  /// The stored value this column edits on [entity].
  final Object? Function(T entity) valueOf;

  /// The text the cell opens with, in the diver's units.
  final String Function(T entity, UnitFormatter units) editText;

  /// Typed or pasted text to the stored value.
  final CellParseResult Function(
    String text,
    UnitFormatter units,
    AppLocalizations l10n,
  )
  parse;

  /// The list a choice, multi-choice or reference cell offers.
  final List<ChoiceOption> Function(AppLocalizations l10n) choices;

  /// Whether this cell may be edited on [entity].
  final bool Function(T entity) isEditable;

  /// The unit the cell is typed in, for the header; null for non-numbers.
  final String? Function(UnitFormatter units) unitSymbol;

  /// Why the cell is read-only on [entity], for a tooltip; null when editable.
  final String? Function(T entity, AppLocalizations l10n) readOnlyReason;

  /// How a stored value of this column reads in a drafted cell; null leaves
  /// it to the entity's adapter.
  final String Function(Object value, UnitFormatter units)? displayValue;

  TableEditorColumn({
    required this.field,
    required this.kind,
    required this.valueOf,
    required this.parse,
    String Function(T entity, UnitFormatter units)? editText,
    List<ChoiceOption> Function(AppLocalizations l10n)? choices,
    bool Function(T entity)? isEditable,
    String? Function(UnitFormatter units)? unitSymbol,
    String? Function(T entity, AppLocalizations l10n)? readOnlyReason,
    this.displayValue,
  }) : editText = editText ?? ((_, _) => ''),
       choices = choices ?? ((_) => const []),
       isEditable = isEditable ?? ((_) => true),
       unitSymbol = unitSymbol ?? ((_) => null),
       readOnlyReason = readOnlyReason ?? ((_, _) => null);

  /// The draft [text] makes of this column's cell on [entityId]: the parsed
  /// value, or the text flagged with [original] kept as the value.
  TableDraft draftFor(
    String entityId,
    String text, {
    required Object? original,
    required UnitFormatter units,
    required AppLocalizations l10n,
  }) => switch (parse(text, units, l10n)) {
    CellParsed(:final value) => TableDraft(
      entityId: entityId,
      fieldName: field.name,
      original: original,
      value: value,
      rawText: text,
    ),
    CellRejected(:final flag) => TableDraft(
      entityId: entityId,
      fieldName: field.name,
      original: original,
      value: original,
      rawText: text,
      flag: flag,
    ),
  };
}
