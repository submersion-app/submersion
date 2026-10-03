import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_list_tile.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_list_row.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';
import 'package:submersion/features/tracks/presentation/providers/tracks_providers.dart';
import 'package:submersion/features/tracks/presentation/widgets/track_kind_badge.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_list_header.dart';

/// The merged list: header first, then one row per track, each the row its
/// own feature already draws, badged with its kind.
///
/// A builder list, never a plain one: GPS rows carry live map thumbnails,
/// and a non-builder list would build one per track on first paint.
class TracksListPane extends ConsumerWidget {
  const TracksListPane({
    super.key,
    required this.selectedKey,
    required this.onTap,
    this.onMatch,
    this.onDelete,
    this.showControls = true,
  });

  final String? selectedKey;
  final ValueChanged<TrackListItem> onTap;
  final VoidCallback? onMatch;
  final ValueChanged<TrackListItem>? onDelete;
  final bool showControls;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(tracksListProvider);
    final items = itemsAsync.value ?? const <TrackListItem>[];
    final units = UnitFormatter(ref.watch(settingsProvider));
    final delete = onDelete;

    return ListView.builder(
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return TracksListHeader(
            showControls: showControls,
            // Only once loaded: a cold open must not flash the empty state.
            isEmpty: itemsAsync.hasValue && items.isEmpty,
            onMatch: onMatch,
          );
        }
        final item = items[index - 1];
        final selected = item.selectionKey == selectedKey;
        // Keyed by selection key: a recycled unkeyed GPS row keeps the
        // previous track's thumbnail camera.
        return switch (item) {
          GpsTrackItem(:final track) => GpsTrackListTile(
            key: ValueKey(item.selectionKey),
            track: track,
            selected: selected,
            onTap: () => onTap(item),
            onDelete: delete == null ? null : () => delete(item),
            kindBadge: TrackKindBadge(TrackKind.gps),
          ),
          UnderwaterTrackItem(:final track) => NavTrackListRow(
            key: ValueKey(item.selectionKey),
            route: track,
            units: units,
            selected: selected,
            onTap: () => onTap(item),
            onDelete: delete == null ? null : () => delete(item),
            kindBadge: TrackKindBadge(TrackKind.underwater),
          ),
        };
      },
    );
  }
}
