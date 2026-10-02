import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/data/services/track_import/csv_track_parser.dart';
import 'package:submersion/features/gps_log/data/services/track_import/parsed_track.dart';
import 'package:submersion/features/gps_log/data/services/track_import/track_import_service.dart';
import 'package:submersion/features/nav_track/data/services/parsers/seacraft_enc_signature.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_import_review_page.dart';
import 'package:submersion/features/gps_log/presentation/pages/track_import_review_page.dart';
import 'package:submersion/features/gps_log/presentation/track_parse_error_text.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_log_empty_state.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_log_list_pane.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_record_card.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_log_summary_strip.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_date_filter_action.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_empty_map.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_info_card.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_list_tile.dart';
import 'package:submersion/features/gps_log/presentation/widgets/gps_track_overview_map.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_list_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// GPS surface track logger (discussion #289): record the phone's position
/// during a dive day; imported dives are matched to positions by timestamp.
///
/// Two layouts. Below the master-detail breakpoint it is a single column:
/// record card (phones only), summary, match action, track list; a row opens
/// the track. At desktop width the same list sits beside the overview map,
/// a row selects the track on the map, and the map's info card opens it.
class GpsLoggerPage extends ConsumerStatefulWidget {
  const GpsLoggerPage({super.key});

  @override
  ConsumerState<GpsLoggerPage> createState() => _GpsLoggerPageState();
}

class _GpsLoggerPageState extends ConsumerState<GpsLoggerPage> {
  final _log = LoggerService.forClass(GpsLoggerPage);
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    // Riverpod 3 forbids provider mutation inside lifecycle callbacks; defer
    // the recovery read to a microtask. Surfaces tracks a crash left open.
    Future.microtask(() async {
      if (!mounted) return;
      final recorder = ref.read(gpsTrackRecorderProvider);
      if (recorder.isRecording) return;
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
    });
  }

  Future<void> _matchNow() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final List<String> stamped;
    try {
      stamped = await ref.read(gpsTrackMatchServiceProvider).sweep();
    } catch (e, stackTrace) {
      // Matching is best-effort everywhere else; a button press must not
      // surface an uncaught error either.
      _log.error(
        'Manual GPS match sweep failed',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.common_error_tryAgain)),
        );
      }
      return;
    }
    if (!mounted) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          stamped.isEmpty
              ? l10n.gpsLogger_matchResultNone
              : l10n.gpsLogger_matchResult(stamped.length),
        ),
        duration: const Duration(seconds: 5),
        // #406: an action defaults to persist: true; force auto-dismiss.
        persist: false,
        showCloseIcon: true,
        action: stamped.isEmpty
            ? null
            : SnackBarAction(
                label: l10n.gpsLogger_reviewSites,
                onPressed: () =>
                    router.push('/dives/match-sites', extra: stamped),
              ),
      ),
    );
  }

  Future<void> _importTrack() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['gpx', 'kml', 'csv', 'fit'],
    );
    if (file == null) return;
    // FIT is binary, so read the bytes through the handle rather than via a
    // path: file_picker 12 retired `withData`, and on Android SAF there may
    // be no local path at all.
    final bytes = await file.readAsBytes();

    // A Seacraft ENC navigation console log is a route, not a GPS track:
    // short-circuit straight to the route review page instead of the
    // column-mapping form a CSV would otherwise get (spec
    // 2026-09-10-underwater-nav-track-design.md, "Import and format
    // detection"). GPX/KML/FIT/every other CSV are untouched.
    if (file.name.toLowerCase().endsWith('.csv')) {
      List<String> headers;
      try {
        headers = readCsvHeaders(bytes);
      } catch (_) {
        headers = const [];
      }
      if (looksLikeSeacraftEnc(headers)) {
        if (!mounted) return;
        await navigateToNavTrackReview(context, bytes, fileName: file.name);
        return;
      }
    }

    final TrackImportCandidate candidate;
    try {
      candidate = await ref
          .read(trackImportServiceProvider)
          .prepare(fileName: file.name, bytes: bytes);
    } on TrackParseException catch (e) {
      // e.message names the offending element or row, in English. It belongs
      // in the log; the SnackBar gets the localized reason.
      _log.warning('Track import rejected: ${e.message}');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(trackParseErrorText(l10n, e))),
      );
      return;
    } catch (e, stackTrace) {
      _log.error('Track import failed', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.gpsTrack_import_failed('$e'))),
      );
      return;
    }

    if (!mounted) return;
    await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            TrackImportReviewPage(candidate: candidate, bytes: bytes),
      ),
    );
  }

  Future<void> _deleteTrack(GpsTrack track) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.gpsLogger_deleteTrackTitle),
        content: Text(l10n.gpsLogger_deleteTrackMessage),
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
      ),
    );
    if (confirmed != true) return;
    await ref.read(deleteTrackProvider)(track.id);
    // A deleted track must not stay picked on the map.
    final selection = ref.read(mapListSelectionProvider(kGpsTrackSectionKey));
    if (selection.selectedId == track.id) {
      ref
          .read(mapListSelectionProvider(kGpsTrackSectionKey).notifier)
          .deselect();
    }
  }

  void _openTrack(String id) => context.push('/gps-log/$id');

  Widget _importAction(BuildContext context) => IconButton(
    key: const ValueKey('gps-track-import'),
    icon: const Icon(Icons.file_open_outlined),
    tooltip: context.l10n.gpsTrack_import_action,
    onPressed: _importTrack,
  );

  @override
  Widget build(BuildContext context) {
    return ResponsiveBreakpoints.isMasterDetail(context)
        ? _buildSplit(context)
        : _buildColumn(context);
  }

  /// Desktop: list pane beside the overview map, sharing the map page's
  /// selection section so a track picked on either surface stays picked.
  Widget _buildSplit(BuildContext context) {
    final l10n = context.l10n;
    // Capped: every track drawn here hydrates a full point blob and, on a cold
    // cache, spawns its own simplification isolate.
    final tracksAsync = ref.watch(overviewTracksProvider);
    final tracks = tracksAsync.value ?? const <GpsTrack>[];
    final truncated = ref.watch(overviewTracksTruncatedProvider);
    final selection = ref.watch(mapListSelectionProvider(kGpsTrackSectionKey));
    final selected = tracks
        .where((t) => t.id == selection.selectedId)
        .firstOrNull;

    return MapListScaffold(
      sectionKey: kGpsTrackSectionKey,
      title: l10n.tools_gpsLogger_title,
      titleWidget: FeatureAppBarTitle(
        featureId: 'gps-log',
        title: l10n.tools_gpsLogger_title,
      ),
      actions: [const GpsTrackDateFilterAction(), _importAction(context)],
      listPane: GpsLogListPane(
        tracks: tracks,
        selectedId: selection.selectedId,
        leading: canRecordGpsTracks ? const GpsRecordCard() : null,
        truncatedNotice: truncated
            ? l10n.gpsTrack_map_truncated(kOverviewTrackLimit)
            : null,
        onMatch: _matchNow,
        onSelect: (id) => ref
            .read(mapListSelectionProvider(kGpsTrackSectionKey).notifier)
            .select(id),
        onDelete: _deleteTrack,
      ),
      // Same three-way split as the map page: a loading library must not
      // flash the empty message, and a failed query must not claim there
      // are no tracks.
      mapPane: switch (tracksAsync) {
        AsyncLoading() when tracks.isEmpty => const Center(
          child: CircularProgressIndicator(),
        ),
        AsyncError() => Center(child: Text(l10n.common_error_tryAgain)),
        _ when tracks.isEmpty => GpsTrackEmptyMap(
          message: l10n.gpsTrack_map_noTracks,
        ),
        _ => GpsTrackOverviewMap(
          tracks: tracks,
          selectedId: selection.selectedId,
          controller: _mapController,
        ),
      },
      infoCard: selected == null
          ? null
          : GpsTrackInfoCard(
              track: selected,
              onDetailsTap: () => _openTrack(selected.id),
              onClose: () => ref
                  .read(mapListSelectionProvider(kGpsTrackSectionKey).notifier)
                  .deselect(),
            ),
    );
  }

  /// Phones and narrow windows: one column, a row opens the track.
  Widget _buildColumn(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tracks = ref.watch(gpsTracksProvider).value ?? const <GpsTrack>[];

    return Scaffold(
      appBar: AppBar(
        title: FeatureAppBarTitle(
          featureId: 'gps-log',
          title: l10n.tools_gpsLogger_title,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: l10n.gpsTrack_map_showMap,
            onPressed: () => context.push('/gps-log/map'),
          ),
          _importAction(context),
        ],
      ),
      // CustomScrollView rather than ListView: each row carries a live
      // FlutterMap thumbnail, and a non-builder list would instantiate one
      // per track in the database on first paint.
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverList.list(
              children: [
                if (canRecordGpsTracks) ...[
                  const GpsRecordCard(),
                  const SizedBox(height: 16),
                ],
                const GpsLogSummaryStrip(),
                const SizedBox(height: 12),
                GpsLogMatchButton(onPressed: _matchNow),
                const SizedBox(height: 24),
                Text(
                  l10n.gpsLogger_tracksHeader,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (tracks.isEmpty) const GpsLogEmptyState(),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList.builder(
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                final track = tracks[index];
                return GpsTrackListTile(
                  // Keyed by track: without this a recycled row keeps the
                  // previous track's FlutterMap State, and its camera stays
                  // on the previous region.
                  key: ValueKey(track.id),
                  track: track,
                  contentPadding: EdgeInsets.zero,
                  onTap: () => _openTrack(track.id),
                  onDelete: () => _deleteTrack(track),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
