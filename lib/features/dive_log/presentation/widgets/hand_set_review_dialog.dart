import 'package:flutter/material.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/hand_set_fields.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart'
    show GasMix;
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where a re-read dive's fresh values come from.
enum HandSetReviewSource { computer, file }

/// Asks the diver, before a re-parse or resync, which of the values they set
/// by hand to keep (issue #4909). [changes] are the values the fresh parse
/// would replace, as `previewReparse` and `previewHandSetChanges` list them.
///
/// Every value starts on Keep. Returns the fields the diver chose to
/// replace, empty when they keep them all, or null when they cancel.
Future<Set<HandSetField>?> showHandSetReviewDialog(
  BuildContext context, {
  required List<HandSetChange> changes,
  required HandSetReviewSource source,
  required UnitFormatter units,
}) => showDialog<Set<HandSetField>>(
  context: context,
  builder: (context) =>
      HandSetReviewDialog(changes: changes, source: source, units: units),
);

/// The dialog [showHandSetReviewDialog] shows.
class HandSetReviewDialog extends StatefulWidget {
  const HandSetReviewDialog({
    super.key,
    required this.changes,
    required this.source,
    required this.units,
  });

  final List<HandSetChange> changes;
  final HandSetReviewSource source;
  final UnitFormatter units;

  @override
  State<HandSetReviewDialog> createState() => _HandSetReviewDialogState();
}

class _HandSetReviewDialogState extends State<HandSetReviewDialog> {
  Set<HandSetField> _replace = const {};

  void _choose(HandSetField field, {required bool replace}) => setState(() {
    _replace = replace
        ? {..._replace, field}
        : {
            for (final f in _replace)
              if (f != field) f,
          };
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final fromComputer = widget.source == HandSetReviewSource.computer;
    return AlertDialog(
      title: Text(
        fromComputer
            ? l10n.handSetReview_reparseTitle
            : l10n.handSetReview_resyncTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.handSetReview_message),
            for (final change in widget.changes) ...[
              const SizedBox(height: 16),
              Text(
                handSetFieldLabel(change.field, l10n),
                style: textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              ...switch (handSetValueTexts(change, widget.units, l10n)) {
                (:final stored, :final parsed) => [
                  Text(l10n.handSetReview_yours(stored)),
                  Text(
                    (fromComputer
                        ? l10n.handSetReview_fromComputer
                        : l10n.handSetReview_fromFile)(parsed),
                  ),
                ],
              },
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                key: ValueKey('handSetChoice_${change.field.name}'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(l10n.handSetReview_keep),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(l10n.handSetReview_replace),
                  ),
                ],
                selected: {_replace.contains(change.field)},
                onSelectionChanged: (choice) =>
                    _choose(change.field, replace: choice.single),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_replace),
          child: Text(
            fromComputer
                ? l10n.common_action_reparse
                : l10n.handSetReview_resyncAction,
          ),
        ),
      ],
    );
  }
}

/// The name the dive page gives [field].
String handSetFieldLabel(
  HandSetField field,
  AppLocalizations l10n,
) => switch (field) {
  HandSetField.maxDepth => DiveField.maxDepth.labelFor(l10n),
  HandSetField.avgDepth => DiveField.avgDepth.labelFor(l10n),
  HandSetField.runtime => DiveField.runtime.labelFor(l10n),
  HandSetField.entryTime => l10n.settings_conflict_field_entryTime,
  HandSetField.exitTime => l10n.settings_conflict_field_exitTime,
  HandSetField.bottomTime => DiveField.bottomTime.labelFor(l10n),
  HandSetField.waterTemp => DiveField.waterTemp.labelFor(l10n),
  HandSetField.diveMode => DiveField.diveMode.labelFor(l10n),
  HandSetField.gradientFactorLow => DiveField.gradientFactorLow.labelFor(l10n),
  HandSetField.gradientFactorHigh => DiveField.gradientFactorHigh.labelFor(
    l10n,
  ),
  HandSetField.decoAlgorithm => DiveField.decoAlgorithm.labelFor(l10n),
  HandSetField.decoConservatism => DiveField.decoConservatism.labelFor(l10n),
  HandSetField.diluent => DiveField.diluentGas.labelFor(l10n),
};

/// [change]'s two values as the dialog shows them. When they would read the
/// same, a depth or temperature is shown to two decimals, so a row never
/// offers a choice between what look like equal values.
({String stored, String parsed}) handSetValueTexts(
  HandSetChange change,
  UnitFormatter units,
  AppLocalizations l10n,
) {
  String text(Object? value, {bool precise = false}) =>
      handSetValueText(change.field, value, units, l10n, precise: precise);
  final stored = text(change.storedValue);
  final parsed = text(change.parsedValue);
  if (stored != parsed) return (stored: stored, parsed: parsed);
  return (
    stored: text(change.storedValue, precise: true),
    parsed: text(change.parsedValue, precise: true),
  );
}

/// [value], in [HandSetField.valueIn]'s shape, as the diver reads it, in
/// their units; [precise] gives a depth or temperature two decimals and a
/// time its seconds.
String handSetValueText(
  HandSetField field,
  Object? value,
  UnitFormatter units,
  AppLocalizations l10n, {
  bool precise = false,
}) {
  final decimals = precise ? 2 : 1;
  DateTime instant(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  final text = switch ((field, value)) {
    (HandSetField.maxDepth || HandSetField.avgDepth, final double depth) =>
      units.formatDepth(depth, decimals: decimals),
    (HandSetField.waterTemp, final double temp) => units.formatTemperature(
      temp,
      decimals: decimals,
    ),
    (HandSetField.runtime || HandSetField.bottomTime, final int seconds) =>
      _minutesSeconds(seconds),
    // The start: the entry time, or the dive's date when it has none.
    (HandSetField.entryTime, (final int? entry, final int date)) =>
      precise
          ? '${units.formatDate(instant(entry ?? date))} '
                '${l10n.formatter_connector_at} '
                '${units.formatTimeWithSeconds(instant(entry ?? date))}'
          : units.formatDateTime(instant(entry ?? date), l10n: l10n),
    (HandSetField.exitTime, final int ms) =>
      precise
          ? units.formatTimeWithSeconds(instant(ms))
          : units.formatTime(instant(ms)),
    (HandSetField.diveMode, final String code) => switch (DiveMode.fromCode(
      code,
    )) {
      DiveMode.oc => l10n.enum_diveMode_oc,
      DiveMode.ccr => l10n.enum_diveMode_ccr,
      DiveMode.scr => l10n.enum_diveMode_scr,
      DiveMode.gauge => l10n.enum_diveMode_gauge,
    },
    (
      HandSetField.gradientFactorLow || HandSetField.gradientFactorHigh,
      final int gf,
    ) =>
      '$gf%',
    (HandSetField.diluent, (final double o2, final double he)) => GasMix(
      o2: o2,
      he: he,
    ).name,
    (_, null) || (HandSetField.diluent, _) => null,
    (_, final Object other) => '$other',
  };
  return text ?? l10n.diveLog_edit_row_notSet;
}

/// [seconds] as minutes and seconds, "40:30": a value the diver typed to
/// the second must not read the same as the parse's.
String _minutesSeconds(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
