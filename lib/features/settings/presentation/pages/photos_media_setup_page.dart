import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/media/presentation/providers/lightroom_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Live status for the guided setup steps. Invalidated after returning
/// from a step so the checklist reflects what the user just configured.
final setupGuideStatusProvider =
    FutureProvider.autoDispose<({bool sources, bool storage, bool sync})>((
      ref,
    ) async {
      final lightroom = await ref.watch(lightroomAccountProvider.future);
      // Aligned with the step's route (/settings/media-sources): ANY
      // attached media - gallery, files, URLs, or Lightroom - counts as
      // "photo sources set up", not just a Lightroom connection.
      final hasMedia = await ref.watch(mediaRepositoryProvider).hasAnyMedia();
      final attached = await ref
          .watch(mediaStoreAttachStateProvider)
          .attachedStoreId();
      final syncProvider = await ref
          .watch(syncRepositoryProvider)
          .getCloudProvider();
      return (
        sources: lightroom != null || hasMedia,
        storage: attached != null,
        sync: syncProvider != null,
      );
    });

/// Guided, re-runnable setup checklist (program spec section 7): three
/// steps with live status, each opening the page that actually does the
/// work. Deliberately a checklist rather than a modal wizard so it can be
/// entered and left at any point without losing state.
class PhotosMediaSetupPage extends ConsumerWidget {
  const PhotosMediaSetupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(setupGuideStatusProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_setupGuide_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              l10n.settings_setupGuide_intro,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          _StepCard(
            icon: Icons.photo_library_outlined,
            title: l10n.settings_setupGuide_stepSources,
            description: l10n.settings_setupGuide_stepSources_desc,
            done: status?.sources ?? false,
            route: '/settings/media-sources',
          ),
          _StepCard(
            icon: Icons.perm_media_outlined,
            title: l10n.settings_setupGuide_stepStorage,
            description: l10n.settings_setupGuide_stepStorage_desc,
            done: status?.storage ?? false,
            route: '/settings/media-storage',
          ),
          _StepCard(
            icon: Icons.cloud_sync,
            title: l10n.settings_setupGuide_stepSync,
            description: l10n.settings_setupGuide_stepSync_desc,
            done: status?.sync ?? false,
            route: '/settings/cloud-sync',
          ),
        ],
      ),
    );
  }
}

class _StepCard extends ConsumerWidget {
  const _StepCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.done,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool done;
  final String route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                    done ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18,
                    color: done ? colorScheme.primary : colorScheme.outline,
                  ),
                  label: Text(
                    done
                        ? l10n.settings_setupGuide_statusDone
                        : l10n.settings_setupGuide_statusTodo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: () async {
                  await context.push(route);
                  ref.invalidate(setupGuideStatusProvider);
                },
                child: Text(l10n.settings_setupGuide_open),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
