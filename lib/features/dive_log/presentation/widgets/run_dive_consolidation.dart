import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Applies a dive consolidation via [service] and shows the resulting
/// success-with-undo or error SnackBar.
///
/// Shared by the per-dive "Merge with another dive" flow
/// ([MergeDiveDialog]/`dive_detail_page.dart`) and the multi-select combine
/// dialog's consolidation panel ([CombineDivesDialog]) so there is a single
/// copy of the apply/undo/SnackBar logic (Task 7 review finding; moved out of
/// dive_detail_page.dart in Task 9 to avoid a widget depending on the page
/// file).
Future<void> runDiveConsolidation({
  required BuildContext context,
  required DiveConsolidationService service,
  required String targetDiveId,
  required List<String> secondaryDiveIds,
  required VoidCallback onConsolidated,
}) async {
  final l10n = context.l10n;
  final scaffoldMessenger = ScaffoldMessenger.of(context);

  final DiveConsolidationOutcome outcome;
  try {
    outcome = await service.apply(
      targetDiveId: targetDiveId,
      secondaryDiveIds: secondaryDiveIds,
    );
  } catch (e) {
    // ArgumentError carries a mappable invalid-consolidation reason;
    // anything else (DB failure, a dive deleted by sync mid-flow throwing
    // StateError, ...) degrades to the generic error text instead of
    // crashing the interaction. apply() is transactional, so nothing was
    // written either way.
    scaffoldMessenger.showSnackBar(
      SnackBar(content: Text(consolidationErrorText(l10n, e))),
    );
    return;
  }

  onConsolidated();

  scaffoldMessenger.clearSnackBars();
  scaffoldMessenger.showSnackBar(
    SnackBar(
      content: Text(l10n.diveLog_consolidate_snackbar),
      duration: const Duration(seconds: 5),
      // #406: an action defaults to persist: true; force auto-dismiss
      // and allow closing without triggering Undo.
      persist: false,
      showCloseIcon: true,
      action: SnackBarAction(
        label: l10n.diveLog_bulkDelete_undo,
        onPressed: () async {
          try {
            await service.undo(outcome.snapshot);
            onConsolidated();
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(l10n.diveLog_consolidate_undone),
                duration: const Duration(seconds: 2),
              ),
            );
          } catch (_) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(l10n.diveLog_consolidate_undoError),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        },
      ),
    ),
  );
}

/// Maps a [DiveConsolidationService.apply] failure to user-visible text.
///
/// `apply` throws [ArgumentError] whose message either starts with
/// `sameComputer` (the service's own FK-level guard) or is
/// `DiveConsolidationBuilder.build`'s `ConsolidationInvalid(reason.name)`
/// wrapper, which encodes the invalid-consolidation reason by name. Only the
/// reasons that are actually surfaced with distinct copy are matched here;
/// anything else -- including tooFewDives/mixedDivers, which do not have
/// dedicated error strings -- falls back to the generic error text.
String consolidationErrorText(AppLocalizations l10n, Object error) {
  if (error is ArgumentError) {
    final message = error.message?.toString() ?? '';
    if (message.startsWith('sameComputer')) {
      return l10n.diveLog_consolidate_error_sameComputer;
    }
    if (message.contains('notOverlapping')) {
      return l10n.diveLog_consolidate_error_notOverlapping;
    }
  }
  return l10n.diveLog_consolidate_error_generic;
}
