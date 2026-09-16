import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/other_gear_retype.dart';
import 'package:submersion/features/equipment/presentation/providers/other_gear_retype_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Retypes [candidates] (#1886), refreshes what that changes, and reports
/// the result with Undo. Returns the receipt.
///
/// Works through [container] rather than a `WidgetRef` so Undo still works
/// after the page that ran the retype is gone.
Future<RetypeReceipt> applyOtherGearRetype({
  required ProviderContainer container,
  required ScaffoldMessengerState messenger,
  required AppLocalizations l10n,
  required List<RetypeCandidate> candidates,
}) async {
  final service = container.read(otherGearRetypeServiceProvider);
  final receipt = await service.apply(candidates);
  refreshAfterOtherGearRetype(container);
  final retyped = receipt.retyped.length;
  final parts = [
    if (retyped > 0) l10n.equipment_retypeOther_retypedSnackbar(retyped),
    if (receipt.failed > 0)
      l10n.equipment_retypeOther_failedSnackbar(receipt.failed),
  ];
  // Nothing written and nothing failed: every item changed since the page
  // listed it, and the page has already reloaded without them.
  if (parts.isEmpty) return receipt;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(parts.join(' · ')),
        duration: const Duration(seconds: 5),
        // #406: an action defaults to persist: true; force auto-dismiss and
        // allow closing without triggering Undo.
        persist: false,
        showCloseIcon: true,
        action: retyped == 0
            ? null
            : SnackBarAction(
                label: l10n.diveLog_bulkDelete_undo,
                onPressed: () async {
                  final result = await service.undo(receipt);
                  refreshAfterOtherGearRetype(container);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(_undoMessage(l10n, result)),
                      duration: Duration(
                        seconds: result.skipped + result.failed == 0 ? 2 : 5,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  return receipt;
}

/// "Retype undone", or what Undo left alone and why.
String _undoMessage(AppLocalizations l10n, RetypeUndoResult result) => [
  if (result.restored > 0) l10n.equipment_retypeOther_undone,
  if (result.skipped > 0)
    l10n.equipment_retypeOther_undoSkipped(result.skipped),
  if (result.failed > 0) l10n.equipment_retypeOther_undoFailed(result.failed),
].join(' · ');
