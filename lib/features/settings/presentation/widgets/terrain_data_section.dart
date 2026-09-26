import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_reset_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/offline_maps_section_header.dart';
import 'package:submersion/features/settings/presentation/widgets/bathymetry_refresh_tile.dart';
import 'package:submersion/features/settings/presentation/widgets/three_d_maps_reload_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Offline Maps page's section for the app's cached 3D terrain/depth
/// data (bathymetry): swissBATHY3D-specific actions, a combined reset for the
/// other four providers (EMODnet, NOAA DEM, GMRT, ETOPO), and a "reload for
/// every dive site" action that spans all five.
///
/// Only one of the four actions runs at a time (a map tile download in the
/// section above is not one of them and runs independently): [_otherActionBusy] covers
/// the delete/reset actions (via [_runExclusive]), [_refreshBusy] covers
/// the refresh tile (it reports its own run through
/// [BathymetryRefreshTile.onBusyChanged]), and [mapReloadProvider]'s own
/// `isRunning` covers the reload action, which has a dialog and a
/// cancellable progress bar of its own.
///
/// These are deliberately two separate booleans, not one shared flag: the
/// refresh tile's own dimming must ask "is something ELSE running" (so it
/// stays bright and shows its own spinner while IT is the one running,
/// rather than looking disabled), while the other two tiles' dimming must
/// ask "is ANYTHING running, including the refresh tile". A single shared
/// flag can only answer one of those two questions correctly (regression:
/// it used to also double as "am I excluded from my own dimming check",
/// which silently re-enabled every other tile the moment the refresh tile
/// started, and vice versa -- found by code review).
class TerrainDataSection extends ConsumerStatefulWidget {
  const TerrainDataSection({super.key});

  @override
  ConsumerState<TerrainDataSection> createState() => _TerrainDataSectionState();
}

class _TerrainDataSectionState extends ConsumerState<TerrainDataSection> {
  bool _otherActionBusy = false;
  bool _refreshBusy = false;

  bool _busy(WidgetRef ref) =>
      _otherActionBusy ||
      _refreshBusy ||
      ref.watch(mapReloadProvider).isRunning;

  Future<void> _runExclusive(
    Future<void> Function() action, {
    required String doneMessage,
  }) async {
    setState(() => _otherActionBusy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(doneMessage)));
    } catch (e) {
      // Without this, a throwing delete/reset (locked DB, I/O error) left
      // the diver with no signal at all -- the busy flag still cleared via
      // `finally` below, so the tile just went idle again, indistinguishable
      // from a silent success. Every other action in this section (the refresh
      // tile, the reload flow) already surfaces its own failure (found by
      // code review).
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.l10n.common_label_error}: $e')),
      );
    } finally {
      if (mounted) setState(() => _otherActionBusy = false);
    }
  }

  Future<void> _confirmAndRun({
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function() action,
    required String doneMessage,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.common_action_cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runExclusive(action, doneMessage: doneMessage);
  }

  Future<void> _startReload() async {
    final confirmed = await showMapReloadConfirmDialog(context);
    if (confirmed != true || !mounted) return;
    await ref.read(mapReloadProvider.notifier).start();
    if (!mounted) return;
    final state = ref.read(mapReloadProvider);
    final message = state.error != null
        ? context.l10n.maps3d_reload_failed
        : state.cancelled
        ? context.l10n.maps3d_reload_cancelled
        : context.l10n.maps3d_reload_done;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final reloadState = ref.watch(mapReloadProvider);
    final busy = _busy(ref);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OfflineMapsSectionHeader(context.l10n.maps_offline_section_terrain),
        if (busy)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              context.l10n.maps3d_busy_notice,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        _SectionHeader(context.l10n.maps3d_section_all),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              ListTile(
                enabled: !busy,
                leading: const Icon(Icons.cloud_download_outlined),
                title: Text(context.l10n.maps3d_reload),
                subtitle: Text(context.l10n.maps3d_reload_subtitle),
                onTap: _startReload,
              ),
              if (reloadState.isRunning) ...[
                const Divider(height: 1),
                _ReloadProgress(state: reloadState),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionHeader(context.l10n.maps3d_section_swissBathy),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              IgnorePointer(
                ignoring: _otherActionBusy || reloadState.isRunning,
                child: Opacity(
                  // Matches the dimming a plain ListTile(enabled: false)
                  // already gives the other three actions below -- this
                  // tile has no such built-in disabled look of its own
                  // (BathymetryRefreshTile never sets ListTile.enabled),
                  // so without this it stayed visually identical whether
                  // it was actually tappable or not. Asks "is something
                  // ELSE running", not the page-wide `busy`: while this
                  // tile is the one running, it must stay bright and show
                  // its own spinner, not look disabled too.
                  opacity: (_otherActionBusy || reloadState.isRunning)
                      ? 0.5
                      : 1.0,
                  child: BathymetryRefreshTile(
                    leading: const Icon(Icons.refresh),
                    onBusyChanged: (value) =>
                        setState(() => _refreshBusy = value),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                enabled: !busy,
                leading: const Icon(Icons.delete_outline),
                title: Text(context.l10n.maps3d_swissBathy_delete),
                subtitle: Text(context.l10n.maps3d_swissBathy_delete_subtitle),
                onTap: () => _confirmAndRun(
                  title: context.l10n.maps3d_swissBathy_delete_confirmTitle,
                  message: context.l10n.maps3d_swissBathy_delete_confirmMessage,
                  confirmLabel: context.l10n.maps3d_swissBathy_delete,
                  action: ref.read(swissBathyClearProvider),
                  doneMessage: context.l10n.maps3d_swissBathy_delete_done,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionHeader(context.l10n.maps3d_section_other),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: ListTile(
            enabled: !busy,
            leading: const Icon(Icons.delete_sweep_outlined),
            title: Text(context.l10n.maps3d_other_reset),
            subtitle: Text(context.l10n.maps3d_other_reset_subtitle),
            onTap: () => _confirmAndRun(
              title: context.l10n.maps3d_other_reset_confirmTitle,
              message: context.l10n.maps3d_other_reset_confirmMessage,
              confirmLabel: context.l10n.maps3d_other_reset,
              action: ref.read(bathymetryOtherSourcesClearProvider),
              doneMessage: context.l10n.maps3d_other_reset_done,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ReloadProgress extends ConsumerWidget {
  const _ReloadProgress({required this.state});

  final MapReloadState state;

  /// Remaining time, estimated from the per-site loop's OWN pace so far
  /// (elapsed since [MapReloadState.startedAt], which is set after
  /// clearing/warming -- see that field's own doc on why). Null before the
  /// first site completes, since there is no rate to extrapolate from yet.
  Duration? _estimateRemaining() {
    final startedAt = state.startedAt;
    if (startedAt == null || state.completed == 0) return null;
    final elapsed = DateTime.now().difference(startedAt);
    final remainingSites = state.total - state.completed;
    if (remainingSites <= 0) return Duration.zero;
    final msPerSite = elapsed.inMilliseconds / state.completed;
    return Duration(milliseconds: (msPerSite * remainingSites).round());
  }

  String? _formatRemaining(BuildContext context, Duration? remaining) {
    if (remaining == null) return null;
    // Both estimators above report Duration.zero once their queue is
    // empty, and the clamp below would round that up to "about 1 second
    // remaining" -- reading as work still to come when there is none
    // (found by code review). The clamp is there to stop a sub-second
    // estimate showing as zero, not to invent a wait out of nothing.
    if (remaining <= Duration.zero) return null;
    if (remaining.inMinutes >= 1) {
      return context.l10n.maps3d_reload_remainingMinutes(remaining.inMinutes);
    }
    return context.l10n.maps3d_reload_remainingSeconds(
      remaining.inSeconds.clamp(1, 59),
    );
  }

  /// Time elapsed since the diver pressed the button -- the warm phase's
  /// own duration signal, since [MapReloadState.startedAt] (the per-site
  /// loop's own clock) does not exist yet during this phase.
  String? _formatElapsed(BuildContext context) {
    final overallStartedAt = state.overallStartedAt;
    if (overallStartedAt == null) return null;
    final elapsed = DateTime.now().difference(overallStartedAt);
    if (elapsed.inMinutes >= 1) {
      return context.l10n.maps3d_reload_elapsedMinutes(elapsed.inMinutes);
    }
    return context.l10n.maps3d_reload_elapsedSeconds(
      elapsed.inSeconds.clamp(1, 59),
    );
  }

  /// Remaining time, estimated from the warm phase's OWN pace so far --
  /// same shape as [_estimateRemaining], but per LAKE rather than per site,
  /// and against [MapReloadState.warmStartedAt] (set once the warm phase
  /// itself begins, AFTER clearing) rather than [MapReloadState.
  /// overallStartedAt] (covers the whole run, clearing included) -- using
  /// the latter would fold the clearing duration into the per-lake rate,
  /// inflating the estimate for as long as clearing took (found by code
  /// review). Null before the first lake finishes, since there is no rate
  /// to extrapolate from yet.
  ///
  /// Far less reliable than the per-site estimate: lake sizes vary hugely
  /// (a 3-tile lake vs. an 18-tile one), so an estimate taken after just one
  /// or two lakes can be well off if a small lake happened to go first (or
  /// last) -- shown anyway, on the same "better than nothing" basis as the
  /// per-site estimate, but this doc is the reason it is not held to the
  /// same expectation of accuracy.
  Duration? _estimateWarmRemaining() {
    final warmStartedAt = state.warmStartedAt;
    // The lake at warmingLakeIndex is still IN FLIGHT; only the ones before
    // it are actually finished and count toward the rate.
    final completedLakes = state.warmingLakeIndex - 1;
    if (warmStartedAt == null || completedLakes <= 0) return null;
    final elapsed = DateTime.now().difference(warmStartedAt);
    final remainingLakes = state.warmingLakeTotal - completedLakes;
    if (remainingLakes <= 0) return Duration.zero;
    final msPerLake = elapsed.inMilliseconds / completedLakes;
    return Duration(milliseconds: (msPerLake * remainingLakes).round());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWarming = state.warmingLakeName != null;
    final progress = isWarming || state.total == 0
        ? null
        : state.completed / state.total;
    final secondaryText = isWarming
        ? [
            _formatElapsed(context),
            _formatRemaining(context, _estimateWarmRemaining()),
          ].nonNulls.join(' · ')
        : _formatRemaining(context, _estimateRemaining());
    final primaryText = isWarming
        ? context.l10n.maps3d_reload_warming(
            state.warmingLakeIndex,
            state.warmingLakeTotal,
            state.warmingLakeName!,
          )
        : context.l10n.maps3d_reload_progress(state.completed, state.total);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(primaryText)),
              TextButton(
                onPressed: () => ref.read(mapReloadProvider.notifier).cancel(),
                child: Text(context.l10n.maps3d_reload_cancel),
              ),
            ],
          ),
          if (secondaryText != null) ...[
            const SizedBox(height: 4),
            Text(
              secondaryText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
