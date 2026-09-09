import 'package:flutter/material.dart';

import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Applies a dive consolidation via [service] and shows the resulting
/// success-with-undo or error SnackBar.
///
/// Two callers share this: the multi-select combine dialog's consolidation
/// panel (`combine_dives_dialog.dart`, which pops itself and then calls this
/// without awaiting) and the data quality inbox's "consolidate duplicate"
/// repair (`data_quality_inbox_page.dart`, which awaits it). It lives in its
/// own file rather than in the dialog so the apply/undo/SnackBar logic is not
/// tied to one widget.
///
/// Only [context] is read synchronously, before the first `await`, so a caller
/// may dismiss its own route first.
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
  // Re-scan the surviving dive after the fold (fire-and-forget).
  scheduleQualityScan([targetDiveId, ...secondaryDiveIds]);

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
            scheduleQualityScan([targetDiveId, ...secondaryDiveIds]);
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
/// `sameComputer` (the service's own FK-level guard) or embeds
/// `DiveConsolidationBuilder.build`'s `ConsolidationInvalid(reason.name)`
/// wrapper, which encodes the invalid-consolidation reason by name. Both
/// shapes are matched by substring: the wrapper prefixes the reason with
/// `build() requires a consolidatable selection; got `, so a `startsWith`
/// test could never see it, and a same-computer re-download -- which
/// `classify` rejects on serial, long before the service reaches the
/// computer FK -- reported only the generic "nothing was changed" text.
///
/// Only the reasons that are actually surfaced with distinct copy are
/// matched here; anything else -- including tooFewDives/mixedDivers, which
/// do not have dedicated error strings -- falls back to the generic text.
String consolidationErrorText(AppLocalizations l10n, Object error) {
  if (error is ArgumentError) {
    final message = error.message?.toString() ?? '';
    if (message.contains('sameComputer')) {
      return l10n.diveLog_consolidate_error_sameComputer;
    }
    if (message.contains('notOverlapping')) {
      return l10n.diveLog_consolidate_error_notOverlapping;
    }
  }
  return l10n.diveLog_consolidate_error_generic;
}
