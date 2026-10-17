import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/data_health_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/utils/byte_format.dart';

/// One quiet line under the status strip: how much the database holds.
/// Nothing while it loads, so the page never jumps from a placeholder.
class DataFactsLine extends ConsumerWidget {
  const DataFactsLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facts = ref.watch(dataFactsProvider).value;
    if (facts == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Text(
      [
        l10n.dataHealth_facts_dives(facts.dives),
        l10n.dataHealth_facts_sites(facts.sites),
        l10n.dataHealth_facts_media(facts.media),
        formatBytes(facts.databaseBytes),
      ].join(' · '),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
