import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/data/services/media_serving_recorder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_provenance.dart';
import 'package:submersion/features/media/domain/entities/media_status.dart';
import 'package:submersion/features/media/domain/services/media_displayed_source.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_provenance_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_serving_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_info_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/media_badge_settings_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One glyph per grid tile: what is wrong with this item, or failing that,
/// where its bytes came from.
///
/// Health wins. An item with a problem or an in-flight transfer shows that
/// state in saturated colour; everything else shows a subdued provenance chip
/// (see [_ProvenanceBadge]), which the diver can switch off entirely.
///
/// This is a deliberate reversal of the original quiet-on-success design.
/// Rendering nothing for a healthy item made a working badge layer
/// indistinguishable from a broken one: on a library with no cloud store and
/// no missing files, EVERY item was healthy, so the feature was invisible and
/// unverifiable. Saying where each item is served from means the common case
/// carries information instead of carrying nothing.
///
/// Deriving from [mediaProvenanceProvider] rather than a second per-item
/// queue watch halves the stream subscriptions a scrolling grid opens.
class MediaStatusBadge extends ConsumerWidget {
  const MediaStatusBadge({super.key, required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = mediaStatusFor(ref.watch(mediaProvenanceProvider(item)));
    if (status == MediaStatus.none) return _ProvenanceBadge(item: item);

    final scheme = Theme.of(context).colorScheme;
    final (icon, background) = switch (status) {
      MediaStatus.broken => (Icons.error_outline, scheme.errorContainer),
      MediaStatus.transferFailed => (Icons.cloud_off, scheme.errorContainer),
      MediaStatus.transferring => (Icons.cloud_upload, scheme.primaryContainer),
      MediaStatus.queued => (Icons.schedule, scheme.surfaceContainerHighest),
      MediaStatus.cloudOnly => (Icons.cloud, scheme.surfaceContainerHighest),
      MediaStatus.notBackedUp => (
        Icons.cloud_off,
        scheme.surfaceContainerHighest,
      ),
      MediaStatus.none => (Icons.circle, scheme.surface),
    };

    return Tooltip(
      message: mediaStatusLabel(context.l10n, status),
      // Opaque so the badge claims the tap rather than letting it fall
      // through to the tile, which would open the viewer instead of
      // explaining the badge the user just aimed at.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showMediaInfoSheet(context, item),
        child: CircleAvatar(
          key: const Key('media-status-badge'),
          radius: 10,
          backgroundColor: background.withValues(alpha: 0.9),
          child: Icon(icon, size: 13),
        ),
      ),
    );
  }
}

/// Where this item's bytes came from, for a healthy item.
///
/// Deliberately quieter than the health badge above it: a translucent chip
/// with a white glyph, matching the video and document markers already on the
/// tile, so a grid of healthy photos still reads as photos while the
/// saturated health colours stay reserved for things that need attention.
///
/// Subscribes to [mediaServingRecorderProvider] by hand rather than through a
/// ListenableBuilder, and rebuilds only when THIS item's answer changes.
///
/// The recorder fires one global `notifyListeners` per resolved tile with no
/// per-key granularity, and every visible badge listens. A ListenableBuilder
/// therefore rebuilt its whole subtree N times per resolution: on a 40-tile
/// screenful that is ~1600 builder runs and ~6400 widget constructions per
/// scroll, all on the most latency-sensitive path in the app, to change at
/// most one glyph.
///
/// Listening directly keeps the per-notification cost at a map lookup and a
/// switch, and turns actual rebuilds into O(tiles) instead of
/// O(tiles x resolutions), since a tile's source settles once when its
/// observation replaces the fallback.
///
/// Not a Riverpod provider for the reason `_ServingSection` documents:
/// Riverpod 3 auto-pause trips an assertion on providers that self-invalidate
/// from a listener the framework cannot see, and `Ref.invalidateSelfWhen`
/// takes a Stream, which a ChangeNotifier is not.
class _ProvenanceBadge extends ConsumerStatefulWidget {
  const _ProvenanceBadge({required this.item});

  final MediaItem item;

  @override
  ConsumerState<_ProvenanceBadge> createState() => _ProvenanceBadgeState();
}

class _ProvenanceBadgeState extends ConsumerState<_ProvenanceBadge> {
  late final MediaServingRecorder _recorder;
  late ServedFrom _source;

  @override
  void initState() {
    super.initState();
    _recorder = ref.read(mediaServingRecorderProvider);
    _source = _currentSource();
    _recorder.addListener(_onRecorded);
  }

  @override
  void didUpdateWidget(covariant _ProvenanceBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A recycled grid tile can be handed a different row without being
    // rebuilt from scratch, and the cached source belongs to the old one.
    if (oldWidget.item.id != widget.item.id) _refresh();
  }

  @override
  void dispose() {
    _recorder.removeListener(_onRecorded);
    super.dispose();
  }

  /// thumbnail: true, because a GRID tile is what records here. The viewer
  /// records the same row under thumbnail: false, and reading that one would
  /// leave every grid badge stuck on its fallback.
  ServedFrom _currentSource() => displayedSourceFor(
    widget.item,
    ServingFacts.from(_recorder.lastFor(widget.item.id, thumbnail: true)),
  );

  /// Runs for EVERY tile's resolution, not just this one, so it has to stay
  /// cheap and must not rebuild unless this item's own answer moved.
  void _onRecorded() {
    if (!mounted) return;
    _refresh();
  }

  void _refresh() {
    final next = _currentSource();
    if (next == _source) return;
    setState(() => _source = next);
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(mediaProvenanceBadgesProvider)) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: mediaSourceLabel(context.l10n, _source),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showMediaInfoSheet(context, widget.item),
        child: Container(
          key: const Key('media-provenance-badge'),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(_iconFor(_source), size: 12, color: Colors.white),
        ),
      ),
    );
  }

  /// Exhaustive with no default arm, so a new [ServedFrom] has to choose a
  /// glyph rather than inherit one.
  IconData _iconFor(ServedFrom source) => switch (source) {
    ServedFrom.localDisk => Icons.folder_outlined,
    ServedFrom.platformGallery => Icons.photo_library_outlined,
    // Cache versus network is the difference between "already here" and "came
    // down just now", which is exactly what a diver on a boat wants to know.
    ServedFrom.storeCache => Icons.cloud_done_outlined,
    ServedFrom.storeNetwork => Icons.cloud_outlined,
    ServedFrom.networkUrl => Icons.public,
    ServedFrom.connectorCache => Icons.cloud_done_outlined,
    ServedFrom.connectorNetwork => Icons.cloud_sync_outlined,
    ServedFrom.embedded => Icons.draw_outlined,
  };
}

/// Localized tooltip for a served source. Exhaustive with no default arm.
String mediaSourceLabel(AppLocalizations l10n, ServedFrom source) =>
    switch (source) {
      ServedFrom.localDisk => l10n.media_servedFrom_localDisk,
      ServedFrom.platformGallery => l10n.media_servedFrom_platformGallery,
      ServedFrom.storeCache => l10n.media_servedFrom_storeCache,
      ServedFrom.storeNetwork => l10n.media_servedFrom_storeNetwork,
      ServedFrom.networkUrl => l10n.media_servedFrom_networkUrl,
      ServedFrom.connectorCache => l10n.media_servedFrom_connectorCache,
      ServedFrom.connectorNetwork => l10n.media_servedFrom_connectorNetwork,
      ServedFrom.embedded => l10n.media_servedFrom_embedded,
    };

/// Localized tooltip for a status. Exhaustive with no default arm, so a new
/// state cannot ship without a string.
String mediaStatusLabel(AppLocalizations l10n, MediaStatus status) =>
    switch (status) {
      MediaStatus.broken => l10n.media_status_broken,
      MediaStatus.transferFailed => l10n.media_status_transferFailed,
      MediaStatus.transferring => l10n.media_status_transferring,
      MediaStatus.queued => l10n.media_status_queued,
      MediaStatus.cloudOnly => l10n.media_status_cloudOnly,
      MediaStatus.notBackedUp => l10n.media_status_notBackedUp,
      MediaStatus.none => '',
    };
