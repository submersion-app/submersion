import 'package:flutter/material.dart';

import 'package:submersion/core/services/nearby/nearby_card_host.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// Asks this diver whether to swap cards with [from] (issue #3728).
/// Resolves true for Swap, false for Decline or a dismissed sheet.
Future<bool> showSwapRequestSheet(
  BuildContext context, {
  required NearbyCardPeer from,
  required String youSend,
}) async {
  final answer = await showModalBottomSheet<bool>(
    context: context,
    builder: (context) {
      final l10n = context.l10n;
      final theme = Theme.of(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProfileAvatar(
                photo: from.photo,
                initials: _initials(from.name),
                radius: 32,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.buddySwap_request_title(from.name),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.buddySwap_request_youSend(youSend),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l10n.buddySwap_request_decline),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l10n.buddySwap_request_swap),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return answer ?? false;
}

String _initials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .where((p) => p.isNotEmpty)
    .take(2)
    .map((p) => p.characters.first.toUpperCase())
    .join();
