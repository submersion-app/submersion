import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/router/track_locations.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/tracks/application/tracks_match_controller.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';
import 'package:submersion/features/tracks/presentation/providers/tracks_providers.dart';
import 'package:submersion/features/tracks/presentation/track_item_location.dart';
import 'package:submersion/features/tracks/presentation/tracks_import.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_list_pane.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_map_pane.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_match_snackbar.dart';
import 'package:submersion/features/tracks/presentation/widgets/tracks_overview_map.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_list_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// The Tracks area (spec 2026-10-02-tracks-navigation-consolidation-design):
/// GPS surface tracks and underwater tracks in one list and one map.
///
/// Below the master-detail breakpoint it is one column and a row opens its
/// track. At desktop width the list sits beside the overview map, a row
/// selects its track, and the map's info card opens it.
class TracksPage extends ConsumerStatefulWidget {
  const TracksPage({super.key, this.initialKind});

  /// The kind a link asked for (`/tracks?kind=...`); null leaves the
  /// current filter alone.
  final TrackKindFilter? initialKind;

  @override
  ConsumerState<TracksPage> createState() => _TracksPageState();
}

class _TracksPageState extends ConsumerState<TracksPage> {
  final _log = LoggerService.forClass(TracksPage);
  final MapController _mapController = MapController();

  /// A sweep is running: Match is disabled until it finishes, so a double
  /// tap cannot start a second sweep writing the same dives.
  bool _matching = false;

  @override
  void initState() {
    super.initState();
    // Riverpod 3 forbids provider mutation inside lifecycle callbacks; defer
    // the filter seed and the orphan recovery to a microtask.
    Future.microtask(() async {
      if (!mounted) return;
      _seedKind(widget.initialKind);
      await _recoverOrphanedTracks();
    });
  }

  @override
  void didUpdateWidget(TracksPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final kind = widget.initialKind;
    if (kind != oldWidget.initialKind) {
      Future.microtask(() {
        if (mounted) _seedKind(kind);
      });
    }
  }

  void _seedKind(TrackKindFilter? kind) {
    if (kind == null) return;
    ref.read(trackKindFilterProvider.notifier).state = kind;
  }

  /// Surfaces tracks a crash left open.
  Future<void> _recoverOrphanedTracks() async {
    if (ref.read(gpsTrackRecorderProvider).isRecording) return;
    try {
      final recovered = await ref
          .read(gpsTrackRepositoryProvider)
          .recoverOrphanedTracks();
      if (recovered.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.gpsLogger_interruptedNotice)),
        );
      }
    } catch (e, stackTrace) {
      // Recovery is best-effort; the page must render regardless.
      _log.error(
        'Orphan track recovery failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _matchNow() async {
    if (_matching) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _matching = true);
    final outcome = await ref.read(tracksMatchControllerProvider).matchAll();
    if (!mounted) return;
    setState(() => _matching = false);
    showTracksMatchOutcome(
      messenger: messenger,
      l10n: l10n,
      router: router,
      outcome: outcome,
    );
  }

  Future<void> _delete(TrackListItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteTrackDialog(item: item),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      switch (item) {
        case GpsTrackItem():
          await ref.read(deleteTrackProvider)(item.id);
        case UnderwaterTrackItem():
          await ref.read(navTrackRepositoryProvider).delete(item.id);
      }
    } catch (e, stackTrace) {
      _log.error('Track delete failed', error: e, stackTrace: stackTrace);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.common_error_tryAgain)),
      );
      return;
    }
    if (!mounted) return;
    // A deleted track must not stay picked on the map.
    final section = mapListSelectionProvider(kTracksSectionKey);
    if (ref.read(section).selectedId == item.selectionKey) {
      ref.read(section.notifier).deselect();
    }
  }

  void _open(TrackListItem item) => context.push(trackLocationOf(item));

  void _select(TrackListItem item) => ref
      .read(mapListSelectionProvider(kTracksSectionKey).notifier)
      .select(item.selectionKey);

  Widget _title() =>
      FeatureAppBarTitle(featureId: 'tracks', title: context.l10n.nav_tracks);

  Widget _importAction() => IconButton(
    key: const ValueKey('tracks-import'),
    icon: const Icon(Icons.file_open_outlined),
    tooltip: context.l10n.gpsTrack_import_action,
    onPressed: () => importTrackFile(context, ref),
  );

  @override
  Widget build(BuildContext context) {
    return ResponsiveBreakpoints.isMasterDetail(context)
        ? _buildSplit(context)
        : _buildColumn(context);
  }

  Widget _buildSplit(BuildContext context) {
    final selection = ref.watch(mapListSelectionProvider(kTracksSectionKey));
    return MapListScaffold(
      sectionKey: kTracksSectionKey,
      title: context.l10n.nav_tracks,
      titleWidget: _title(),
      actions: [_importAction()],
      listPane: TracksListPane(
        selectedKey: selection.selectedId,
        onTap: _select,
        onMatch: _matching ? null : _matchNow,
        onDelete: _delete,
      ),
      mapPane: TracksMapPane(controller: _mapController),
      infoCard: TracksInfoCard(onOpen: _open),
    );
  }

  Widget _buildColumn(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: _title(),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: l10n.gpsTrack_map_showMap,
            onPressed: () => context.push(kTracksMapLocation),
          ),
          _importAction(),
        ],
      ),
      body: TracksListPane(
        selectedKey: null,
        onTap: _open,
        onMatch: _matching ? null : _matchNow,
        onDelete: _delete,
      ),
    );
  }
}

/// Confirms a delete in the wording of the track's own feature.
class _DeleteTrackDialog extends StatelessWidget {
  const _DeleteTrackDialog({required this.item});

  final TrackListItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (title, message) = switch (item) {
      GpsTrackItem() => (
        l10n.gpsLogger_deleteTrackTitle,
        l10n.gpsLogger_deleteTrackMessage,
      ),
      UnderwaterTrackItem(:final track) => (
        l10n.navTrack_detail_deleteTrackTitle,
        l10n.navTrack_list_deleteMessage(
          track.name ?? track.sourceRef ?? track.id,
        ),
      ),
    };
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.common_action_delete),
        ),
      ],
    );
  }
}
