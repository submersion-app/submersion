import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_lab/domain/entities/compare_column.dart';
import 'package:submersion/features/dive_lab/presentation/lab_format.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A column's heading: its what-if's name, or the line's fixed label.
String compareColumnTitle(AppLocalizations l10n, CompareColumn column) =>
    switch (column.kind) {
      CompareLineKind.planned => l10n.diveLab_compare_line_planned,
      CompareLineKind.asDived => l10n.diveLab_compare_line_asDived,
      CompareLineKind.whatIf => column.title ?? l10n.diveLab_panel_whatIf,
    };

String compareRowLabel(AppLocalizations l10n, CompareRow row) => switch (row) {
  CompareRow.maxDepth => l10n.diveLab_compare_row_maxDepth,
  CompareRow.bottomTime => l10n.diveLab_compare_row_bottomTime,
  CompareRow.ndl => l10n.diveLab_compare_row_ndl,
  CompareRow.deco => l10n.diveLab_compare_row_deco,
  CompareRow.runtime => l10n.diveLab_metric_runtime,
  CompareRow.surfaceGf => l10n.diveLab_metric_surfaceGf,
};

/// One cell, in the diver's units. Empty when the line has no value there.
String compareCell(
  AppLocalizations l10n,
  UnitFormatter units,
  CompareRow row,
  CompareColumn column,
) {
  String minutes(int? seconds) =>
      seconds == null ? '' : formatLabMinutes(seconds);
  return switch (row) {
    CompareRow.maxDepth =>
      column.maxDepthMeters == null
          ? ''
          : units.formatDepth(column.maxDepthMeters!),
    CompareRow.bottomTime => minutes(column.bottomTimeSeconds),
    CompareRow.ndl => switch (column.ndl) {
      null => '',
      CompareNdlLeft(:final seconds) => l10n.diveLab_compare_ndlLeft(
        seconds ~/ 60,
      ),
      CompareDecoAt(:final runtimeSeconds) => l10n.diveLab_compare_decoAt(
        formatLabTime(runtimeSeconds),
      ),
    },
    CompareRow.deco => _decoCell(l10n, column),
    CompareRow.runtime => minutes(column.runtimeSeconds),
    CompareRow.surfaceGf =>
      column.surfaceGf == null
          ? ''
          : '${column.surfaceGf!.toStringAsFixed(0)}%',
  };
}

String _decoCell(AppLocalizations l10n, CompareColumn column) {
  final required = column.decoRequiredSeconds;
  final done = column.decoDoneSeconds;
  if (required == null && done == null) return '';
  if ((required ?? 0) == 0 && (done ?? 0) == 0) {
    return l10n.diveLab_compare_noDeco;
  }
  final requiredText = formatLabMinutes(required ?? 0);
  if ((done ?? 0) == 0) return requiredText;
  return l10n.diveLab_compare_decoDone(requiredText, formatLabMinutes(done!));
}
