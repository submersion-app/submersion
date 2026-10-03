import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Sentence-final punctuation, including the CJK full stop, after which the
/// kept-gear sentence follows with only a space.
final _sentenceEnd = RegExp(r'[.!?。]$');

/// The message after a profile delete: what went to whom (issues #2594,
/// #2852).
String deleteDiverSnackbarText(
  AppLocalizations l10n,
  DeleteDiverResult result,
) {
  final first = result.hasReassignments
      ? l10n.divers_delete_reassigned_snackbar(
          result.reassignedTripsCount,
          result.reassignedSitesCount,
          result.reassignedToDiverName ?? '',
        )
      : l10n.settings_profileHub_deleted;
  if (!result.hasKeptEquipment) return first;
  final heirs = result.keptEquipmentHeirNames;
  final kept = heirs.length == 1
      ? l10n.divers_delete_keptEquipment_toOne(
          result.keptEquipmentCount,
          heirs.single,
        )
      : l10n.divers_delete_keptEquipment_toMany(result.keptEquipmentCount);
  final trimmed = first.trimRight();
  final joiner = _sentenceEnd.hasMatch(trimmed) ? ' ' : '. ';
  return '$trimmed$joiner$kept';
}
