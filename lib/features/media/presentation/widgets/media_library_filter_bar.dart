import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_smart_album_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_smart_album_name_dialog.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The library filter chip row: media type, site, trip, and date range, all
/// writing [mediaLibraryFilterProvider]. Stateless — active state renders
/// from the watched filter.
class MediaLibraryFilterBar extends ConsumerWidget {
  const MediaLibraryFilterBar({super.key});

  void _update(
    WidgetRef ref,
    MediaLibraryFilter Function(MediaLibraryFilter) change,
  ) {
    final notifier = ref.read(mediaLibraryFilterProvider.notifier);
    notifier.state = change(notifier.state);
  }

  Future<void> _pickFromSheet(
    BuildContext context, {
    required List<(String id, String label)> options,
    required void Function(String id) onPicked,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final (id, label) in options)
              ListTile(
                title: Text(label),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onPicked(id);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDates(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 1),
    );
    if (range == null) return;
    _update(
      ref,
      (f) => f.copyWith(
        fromDate: range.start,
        // Extend to end-of-day so a single-day range includes its media.
        toDate: DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
          23,
          59,
          59,
          999,
        ),
      ),
    );
  }

  /// Deletes an album and says so when it fails. Awaited rather than fired
  /// and forgotten: an unawaited repository call turns a failed delete into
  /// an uncaught async error and leaves the album on screen with no
  /// explanation for why it came back.
  Future<void> _deleteAlbum(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    try {
      await ref.read(mediaSmartAlbumRepositoryProvider).delete(id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.media_smartAlbum_deleteFailed)),
      );
    }
  }

  Future<void> _saveAlbum(BuildContext context, WidgetRef ref) async {
    final name = await showMediaSmartAlbumNameDialog(context);
    if (name == null) return;
    await ref
        .read(mediaSmartAlbumRepositoryProvider)
        .create(name: name, filter: ref.read(mediaLibraryFilterProvider));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.media_smartAlbum_saved)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(mediaLibraryFilterProvider);
    final sites = ref.watch(sitesProvider).value ?? const [];
    final trips = ref.watch(allTripsProvider).value ?? const [];
    final albums = ref.watch(mediaSmartAlbumsProvider).value ?? const [];

    final siteName = filter.siteId == null
        ? null
        : sites.where((s) => s.id == filter.siteId).firstOrNull?.name;
    final tripName = filter.tripId == null
        ? null
        : trips.where((t) => t.id == filter.tripId).firstOrNull?.name;
    final hasDates = filter.fromDate != null || filter.toDate != null;

    Widget clearable({
      required String label,
      required bool active,
      required VoidCallback onOpen,
      required VoidCallback onClear,
    }) {
      return FilterChip(
        label: Text(label),
        selected: active,
        deleteIcon: active ? const Icon(Icons.clear, size: 18) : null,
        onDeleted: active ? onClear : null,
        onSelected: (_) => onOpen(),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: Text(context.l10n.media_library_filter_all),
            selected: filter.mediaType == null,
            onSelected: (_) => _update(ref, (f) => f.copyWith(mediaType: null)),
          ),
          const SizedBox(width: 6),
          FilterChip(
            label: Text(context.l10n.media_library_filter_photos),
            selected: filter.mediaType == MediaType.photo,
            onSelected: (_) =>
                _update(ref, (f) => f.copyWith(mediaType: MediaType.photo)),
          ),
          const SizedBox(width: 6),
          FilterChip(
            label: Text(context.l10n.media_library_filter_videos),
            selected: filter.mediaType == MediaType.video,
            onSelected: (_) =>
                _update(ref, (f) => f.copyWith(mediaType: MediaType.video)),
          ),
          const SizedBox(width: 6),
          clearable(
            label: siteName ?? context.l10n.media_library_filter_site,
            active: filter.siteId != null,
            onOpen: () => _pickFromSheet(
              context,
              options: [for (final s in sites) (s.id, s.name)],
              onPicked: (id) => _update(ref, (f) => f.copyWith(siteId: id)),
            ),
            onClear: () => _update(ref, (f) => f.copyWith(siteId: null)),
          ),
          const SizedBox(width: 6),
          clearable(
            label: tripName ?? context.l10n.media_library_filter_trip,
            active: filter.tripId != null,
            onOpen: () => _pickFromSheet(
              context,
              options: [for (final t in trips) (t.id, t.name)],
              onPicked: (id) => _update(ref, (f) => f.copyWith(tripId: id)),
            ),
            onClear: () => _update(ref, (f) => f.copyWith(tripId: null)),
          ),
          const SizedBox(width: 6),
          clearable(
            label: context.l10n.media_library_filter_dates,
            active: hasDates,
            onOpen: () => _pickDates(context, ref),
            onClear: () =>
                _update(ref, (f) => f.copyWith(fromDate: null, toDate: null)),
          ),
          if (!filter.isEmpty) ...[
            const SizedBox(width: 6),
            ActionChip(
              label: Text(context.l10n.media_library_filter_clear),
              onPressed: () =>
                  ref.read(mediaLibraryFilterProvider.notifier).state =
                      MediaLibraryFilter.none,
            ),
            const SizedBox(width: 6),
            // Saving "everything" as an album would name nothing, so this
            // only appears once the filter says something.
            ActionChip(
              avatar: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: Text(context.l10n.media_smartAlbum_save),
              onPressed: () => _saveAlbum(context, ref),
            ),
          ],
          if (albums.isNotEmpty) ...[
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              tooltip: context.l10n.media_smartAlbum_albums,
              onSelected: (id) {
                final album = albums.where((a) => a.id == id).firstOrNull;
                if (album == null) return;
                ref.read(mediaLibraryFilterProvider.notifier).state =
                    album.filter;
              },
              itemBuilder: (menuContext) => [
                for (final album in albums)
                  PopupMenuItem<String>(
                    value: album.id,
                    child: Row(
                      children: [
                        Expanded(child: Text(album.name)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: context.l10n.media_smartAlbum_delete,
                          onPressed: () async {
                            Navigator.of(menuContext).pop();
                            // The bar's own context, not the menu's: the
                            // menu is gone by the time a failure needs
                            // somewhere to show itself.
                            await _deleteAlbum(context, ref, album.id);
                          },
                        ),
                      ],
                    ),
                  ),
              ],
              child: Chip(
                avatar: const Icon(Icons.bookmarks_outlined, size: 18),
                label: Text(context.l10n.media_smartAlbum_albums),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
