import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_query_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The visible, clearable indicator of the "needs attention" scope the home
/// certifications chip opens the list with (issue #2267). Styled like the
/// equipment list's active-filter bar.
class CertificationAttentionFilterBar extends ConsumerWidget {
  const CertificationAttentionFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: InputChip(
          avatar: const Icon(Icons.notification_important_outlined, size: 18),
          label: Text(context.l10n.certifications_list_filter_needsAttention),
          onDeleted: () =>
              ref.read(certificationAttentionFilterProvider.notifier).state =
                  false,
        ),
      ),
    );
  }
}
