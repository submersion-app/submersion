import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/domain/table_editor_column.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Pure parsers from cell text to stored values (#3422). Numbers go through
/// the shared [readNumber], so a decimal comma is a decimal point for a
/// diver whose locale uses one, and a blank cell always means "clear".

CellParseResult parseTextCell(String text) {
  final trimmed = text.trim();
  return CellParsed(trimmed.isEmpty ? null : trimmed);
}

/// [toStored] converts the diver's unit to the stored one (kg, metres).
/// [min] and [max] bound the typed value, in the diver's unit.
CellParseResult parseNumberCell(
  String text, {
  required double Function(double value) toStored,
  double? min,
  double? max,
}) => switch (readNumber(text)) {
  NumberBlank() => const CellParsed(null),
  NumberInvalid() => const CellRejected(TableDraftFlag.unparsable),
  NumberValue(:final value) =>
    (min != null && value < min) || (max != null && value > max)
        ? const CellRejected(TableDraftFlag.unparsable)
        : CellParsed(toStored(value)),
};

CellParseResult parseIntegerCell(String text, {int? min, int? max}) =>
    switch (readNumber(text, integer: true)) {
      NumberBlank() => const CellParsed(null),
      NumberInvalid() => const CellRejected(TableDraftFlag.unparsable),
      NumberValue(:final value) =>
        (min != null && value < min) || (max != null && value > max)
            ? const CellRejected(TableDraftFlag.unparsable)
            : CellParsed(value.toInt()),
    };

/// Decimal degrees within plus or minus [limit] (90 for latitude, 180 for
/// longitude). Degrees never carry a unit, so no conversion.
CellParseResult parseDegreesCell(String text, {required double limit}) =>
    parseNumberCell(text, toStored: (v) => v, min: -limit, max: limit);

/// Matches [text] to an option's stored value or label, ignoring case. A
/// label two options share (two sites named House Reef) is refused: picking
/// one would link the wrong record with nothing to show for it.
CellParseResult parseChoiceCell(String text, List<ChoiceOption> options) {
  final needle = text.trim().toLowerCase();
  if (needle.isEmpty) return const CellParsed(null);
  for (final o in options) {
    if (o.value.toLowerCase() == needle) return CellParsed(o.value);
  }
  final named = options.where((o) => o.label.toLowerCase() == needle).toList();
  return named.length == 1
      ? CellParsed(named.single.value)
      : const CellRejected(TableDraftFlag.unknownValue);
}

/// Several choices separated by a comma or a semicolon; one unknown entry
/// rejects the whole cell. The value is a `List<String>` of stored values.
CellParseResult parseMultiChoiceCell(String text, List<ChoiceOption> options) {
  final parts = text
      .split(RegExp('[,;]'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty);
  final values = <String>[];
  for (final part in parts) {
    switch (parseChoiceCell(part, options)) {
      case CellParsed(:final value):
        if (!values.contains(value)) values.add(value! as String);
      case CellRejected(:final flag):
        return CellRejected(flag);
    }
  }
  return CellParsed(values);
}

/// Yes or no in English, as 1 or 0, or in the app's language. Blank is no.
CellParseResult parseToggleCell(String text, AppLocalizations l10n) {
  final needle = text.trim().toLowerCase();
  if (needle.isEmpty) return const CellParsed(false);
  const yes = {'yes', 'y', 'true', '1'};
  const no = {'no', 'n', 'false', '0'};
  if (yes.contains(needle) || needle == l10n.attr_flagYes.toLowerCase()) {
    return const CellParsed(true);
  }
  if (no.contains(needle) || needle == l10n.attr_flagNo.toLowerCase()) {
    return const CellParsed(false);
  }
  return const CellRejected(TableDraftFlag.unparsable);
}
