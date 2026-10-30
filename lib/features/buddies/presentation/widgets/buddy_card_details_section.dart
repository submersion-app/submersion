import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What [buddy]'s own buddy card said about their diving, and when it
/// arrived (issue #3728). Nothing shows for a buddy no card has filled.
class BuddyCardDetailsSection extends ConsumerWidget {
  const BuddyCardDetailsSection({super.key, required this.buddy});

  final Buddy buddy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!buddy.hasCardDetails) return const SizedBox.shrink();
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final theme = Theme.of(context);
    final dives = buddy.cardDiveCount;
    final since = buddy.cardDivingSince;
    final last = buddy.cardLastDive;
    final received = buddy.cardReceivedAt;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.buddyCard_detail_heading(buddy.name),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (dives != null) Text(l10n.buddySwap_dives(dives)),
            if (since != null)
              Text(l10n.buddyCard_detail_since(since.year.toString())),
            if (last != null)
              Text(l10n.buddyCard_detail_last(units.formatDate(last))),
            if (received != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.buddyCard_detail_received(units.formatDate(received)),
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
