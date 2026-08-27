import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/presentation/pages/media_repair_history_view.dart';
import 'package:submersion/features/media/presentation/pages/media_repair_wizard_page.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shown above the Library while the Missing files chip is active: the
/// offline-volume count, the repair wizard, and the repair history.
class MediaMissingBanner extends ConsumerWidget {
  const MediaMissingBanner({super.key, required this.isEmpty});

  /// Whether the filtered list has nothing in it. The wizard needs rows;
  /// the history is exactly what the user checks when there are none.
  final bool isEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(missingOfflineCountProvider).value ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          if (offline > 0)
            Expanded(
              child: Text(
                context.l10n.media_missing_offlineVolumes(offline),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            const Spacer(),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: context.l10n.media_repairHistory_title,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MediaRepairHistoryView(),
              ),
            ),
          ),
          if (!isEmpty)
            FilledButton.tonalIcon(
              icon: const Icon(Icons.build_outlined),
              label: Text(context.l10n.media_missing_repair),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MediaRepairWizardPage(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
