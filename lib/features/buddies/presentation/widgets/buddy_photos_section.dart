import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/media_tag_navigation.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The photos and videos a buddy is tagged in (issue #1745), on the buddy
/// page beside "Shared dives": the newest [maxTiles] in a three-column grid
/// that opens the viewer, and "View All" for the rest in the library.
/// Hidden while the buddy is tagged in nothing, so a page for someone never
/// photographed stays as it was.
class BuddyPhotosSection extends ConsumerWidget {
  final String buddyId;

  const BuddyPhotosSection({super.key, required this.buddyId});

  /// Tiles drawn on the page; the rest are a tap away in the library.
  static const int maxTiles = 9;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(mediaForBuddyProvider(buddyId)).value ?? const <MediaItem>[];
    if (items.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.media_people_buddyPhotosTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (items.length > maxTiles)
                    TextButton(
                      onPressed: () =>
                          openMediaWithBuddy(context, ref, buddyId),
                      child: Text(l10n.buddies_action_viewAll(items.length)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: items.length < maxTiles ? items.length : maxTiles,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        fullscreenDialog: true,
                        builder: (_) => MediaViewerPage(
                          mediaList: items,
                          initialMediaId: item.id,
                          showGoToDive: true,
                        ),
                      ),
                    ),
                    child: MediaThumbnailTile(
                      item: item,
                      settings: settings,
                      isSelectionMode: false,
                      isSelected: false,
                      semanticsLabel: l10n.media_people_buddyThumbnailLabel,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
