import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/services/nearby/nearby_card_host.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// Asks this diver whether to swap cards with [from] (issue #3728).
/// Resolves true for Swap, false for Decline, a dismissed sheet, or
/// [closed] completing (the request expired): that removes this sheet even
/// when another page has opened over it.
Future<bool> showSwapRequestSheet(
  BuildContext context, {
  required NearbyCardPeer from,
  required String youSend,
  Future<void>? closed,
}) async {
  ModalRoute<Object?>? sheet;
  final navigator = Navigator.of(context);
  unawaited(
    closed?.then((_) {
      final route = sheet;
      if (route != null && route.isActive) navigator.removeRoute(route);
    }),
  );
  final answer = await showModalBottomSheet<bool>(
    context: context,
    builder: (context) {
      sheet ??= ModalRoute.of(context);
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
                initials: Buddy.initialsOf(from.name),
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
