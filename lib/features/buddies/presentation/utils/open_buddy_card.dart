import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/buddies/domain/services/buddy_card_codec.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where every received buddy card goes (issue #3728): a readable card to
/// the import preview, anything else to a short message.
void openBuddyCard(BuildContext context, BuddyCardDecodeResult result) {
  switch (result) {
    case BuddyCardDecoded():
      context.push('/buddies/card', extra: result);
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
