import 'package:submersion/core/text/join_sentences.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

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
  final parts = [first];
  if (result.handedOverCount > 0) {
    parts.add(l10n.divers_delete_handedOver(result.handedOverCount));
  }
  if (!result.hasKeptEquipment) return joinSentences(parts, l10n.localeName);
  final heirs = result.keptEquipmentHeirNames;
  parts.add(
    heirs.length == 1
        ? l10n.divers_delete_keptEquipment_toOne(
            result.keptEquipmentCount,
            heirs.single,
          )
        : l10n.divers_delete_keptEquipment_toMany(result.keptEquipmentCount),
  );
  return joinSentences(parts, l10n.localeName);
}
