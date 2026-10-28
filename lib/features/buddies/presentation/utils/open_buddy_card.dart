import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/buddies/domain/services/buddy_card_codec.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';
import 'package:submersion/features/demo_mode/presentation/demo_seal_guard.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where every received buddy card goes (issue #3728): a readable card to
/// the import preview, anything else to a short message. Completes when the
/// preview closes, so several cards can open one after another.
Future<void> openBuddyCard(
  BuildContext context,
  BuddyCardDecodeResult result,
) async {
  // Demo mode (issue #3708): a card has nowhere to go but the sample
  // logbook, so the diver is told why nothing opens.
  if (!demoSealGuard(context, DemoSealedFeature.fileImport)) return;
  switch (result) {
    case BuddyCardDecoded():
      await context.push<void>('/buddies/card', extra: result);
    case BuddyCardRejected(:final reason):
      final l10n = context.l10n;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            reason == BuddyCardRejectReason.notACard
                ? l10n.buddyCard_error_notACard
                : l10n.buddyCard_error_unreadable,
          ),
        ),
      );
  }
}
