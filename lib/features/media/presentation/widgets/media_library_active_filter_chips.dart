import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';
import 'package:submersion/features/media/presentation/helpers/media_source_labels.dart';
import 'package:submersion/features/media/presentation/providers/media_library_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_smart_album_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_library_filter_labels.dart';
import 'package:submersion/features/media/presentation/widgets/media_smart_album_name_dialog.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The strip of removable chips below the library toolbar. Renders nothing
/// while the filter is empty, so the section is uncluttered at rest and
/// self-explanatory the moment anything is filtered.
class MediaLibraryActiveFilterChips extends ConsumerWidget {
  const MediaLibraryActiveFilterChips({super.key});

  void _update(
    WidgetRef ref,
    MediaLibraryFilter Function(MediaLibraryFilter) change,
  ) {
    final notifier = ref.read(mediaLibraryFilterProvider.notifier);
    notifier.state = change(notifier.state);
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
    final l10n = context.l10n;
    final filter = ref.watch(mediaLibraryFilterProvider);
    if (filter.isEmpty) return const SizedBox.shrink();

    final sites = ref.watch(sitesProvider).value ?? const [];
    final trips = ref.watch(allTripsProvider).value ?? const [];

    Widget chip(String label, VoidCallback onClear) {
      return InputChip(
        label: Text(label),
        deleteIcon: const Icon(Icons.clear, size: 18),
        onDeleted: onClear,
      );
    }

    final chips = <Widget>[];

    final type = filter.mediaType;
    if (type != null) {
      chips.add(
        chip(
          type == MediaType.photo
              ? l10n.media_library_filter_photos
              : l10n.media_library_filter_videos,
          () => _update(ref, (f) => f.copyWith(mediaType: null)),
        ),
      );
    }

    final siteId = filter.siteId;
    if (siteId != null) {
      final name =
          sites.where((s) => s.id == siteId).firstOrNull?.name ??
          l10n.media_library_filter_site;
      chips.add(
        chip(name, () => _update(ref, (f) => f.copyWith(siteId: null))),
      );
    }

    final tripId = filter.tripId;
    if (tripId != null) {
      final name =
          trips.where((t) => t.id == tripId).firstOrNull?.name ??
          l10n.media_library_filter_trip;
      chips.add(
        chip(name, () => _update(ref, (f) => f.copyWith(tripId: null))),
      );
    }

    if (filter.fromDate != null || filter.toDate != null) {
      chips.add(
        chip(
          formatFilterDateRange(context, filter.fromDate, filter.toDate),
          () => _update(ref, (f) => f.copyWith(fromDate: null, toDate: null)),
        ),
      );
    }

    // Set by the Sources section's "browse this source", not by the filter
    // sheet. Without a chip the library sits filtered with nothing on screen
    // saying why. Labelled through the same helper the Sources list uses, so
    // the chip names the source the way the row the user just tapped did.
    final sourceType = filter.sourceType;
    if (sourceType != null) {
      chips.add(
        chip(
          mediaSourceLabel(context, sourceType),
          () => _update(ref, (f) => f.copyWith(sourceType: null)),
        ),
      );
    }

    if (filter.health == MediaHealthFilter.missing) {
      chips.add(
        chip(
          l10n.media_library_filter_missing,
          () => _update(ref, (f) => f.copyWith(health: null)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...chips,
          ActionChip(
            label: Text(l10n.media_library_filter_clear),
            onPressed: () =>
                ref.read(mediaLibraryFilterProvider.notifier).state =
                    MediaLibraryFilter.none,
          ),
          // Saving "everything" as an album would name nothing, so this only
          // appears once the filter says something. The whole strip is
          // already gated on that.
          ActionChip(
            avatar: const Icon(Icons.bookmark_add_outlined, size: 18),
            label: Text(l10n.media_smartAlbum_save),
            onPressed: () => _saveAlbum(context, ref),
          ),
        ],
      ),
    );
  }
}
