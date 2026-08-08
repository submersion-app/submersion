import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/services/volume_status.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/pages/media_repair_history_view.dart';
import 'package:submersion/features/media/presentation/pages/media_repair_wizard_page.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_grid.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Paged missing rows: the Phase 1 library notifier pinned to the missing
/// health filter, live via its media-change stream.
final missingViewProvider =
    StateNotifierProvider<MediaLibraryNotifier, MediaLibraryState>((ref) {
      final repo = ref.watch(mediaLibraryRepositoryProvider);
      final diverId = ref.watch(currentDiverIdProvider);
      return MediaLibraryNotifier(
        repo,
        diverId,
        const MediaLibraryFilter(health: MediaHealthFilter.missing),
      );
    });

/// Of the visible missing rows, how many live on currently-offline volumes
/// (informational: those are unmounted, not broken, and the wizard skips
/// them).
final missingOfflineCountProvider = FutureProvider<int>((ref) async {
  final state = ref.watch(missingViewProvider);
  // One probe per mount root per pass: a page of rows from the same
  // unreachable share must not stat it once per row. A fresh probe each
  // time the provider recomputes, so remounting is picked up.
  final isOnline = VolumeStatus().newPassProbe();
  var offline = 0;
  for (final entry in state.entries) {
    final path = entry.item.localPath ?? entry.item.filePath;
    if (path == null || path.isEmpty) continue;
    if (!await isOnline(path)) offline++;
  }
  return offline;
});

/// The Missing console section: orphaned rows with an offline-volumes info
/// banner and the entry point to the repair wizard.
class MediaMissingView extends ConsumerWidget {
  const MediaMissingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(missingViewProvider);
    final offline = ref.watch(missingOfflineCountProvider).value ?? 0;

    if (state.isLoading && state.entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final isEmpty = state.entries.isEmpty;

    return Column(
      children: [
        Padding(
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
              // An empty missing list means nothing to repair, but the
              // history behind it is exactly what the user wants to check
              // then -- so only the wizard entry point disappears.
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
        ),
        Expanded(
          child: isEmpty
              ? Center(child: Text(context.l10n.media_missing_empty))
              : MediaLibraryGrid(
                  entries: state.entries,
                  hasMore: state.hasMore,
                  onLoadMore: () =>
                      ref.read(missingViewProvider.notifier).loadMore(),
                  onTileTap: (entry, index) {},
                ),
        ),
      ],
    );
  }
}
