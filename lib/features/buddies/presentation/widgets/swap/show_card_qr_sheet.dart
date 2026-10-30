import 'package:flutter/material.dart';

import 'package:submersion/features/buddies/domain/entities/buddy_card.dart';
import 'package:submersion/features/buddies/domain/services/buddy_card_codec.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_qr_view.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The longest link a buddy card QR code carries; past this the code gets
/// too dense for a phone camera across a boat cabin.
const int buddyCardQrMaxBytes = 2000;

/// Shows [card] as a QR code of its compact link (issue #3728).
Future<void> showCardQrSheet(BuildContext context, BuddyCard card) {
  final link = BuddyCardCodec.encodeLink(card, maxBytes: buddyCardQrMaxBytes);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final l10n = context.l10n;
      final theme = Theme.of(context);
      final size = (MediaQuery.sizeOf(context).shortestSide - 64).clamp(
        160.0,
        360.0,
      );
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.buddySwap_qr_title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              ColoredBox(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: PassportQrView(
                    data: link,
                    size: size,
                    semanticLabel: l10n.buddySwap_qr_title,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.buddySwap_qr_hint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    },
  );
}
