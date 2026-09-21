import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/data/sources/swissbathy3d_source.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Manual "reload map data" tile: immediately revalidates every cached
/// swissBATHY3D tile via the same light STAC metadata check the periodic
/// 30-day check performs, instead of waiting for it to elapse.
///
/// Lives on the "3D Maps" settings page, alongside the swissBATHY3D/other
/// providers' delete actions -- [onBusyChanged], if given, lets that page
/// gate its OTHER three actions while this one is running, matching the
/// page's "only one action at a time" rule.
class BathymetryRefreshTile extends ConsumerStatefulWidget {
  final Widget leading;

  /// Called with `true` when a refresh starts and `false` once it ends, so
  /// a parent page can disable its other actions for the duration. Optional:
  /// this tile still tracks and shows its own spinner either way.
  final ValueChanged<bool>? onBusyChanged;

  const BathymetryRefreshTile({
    super.key,
    required this.leading,
    this.onBusyChanged,
  });

  @override
  ConsumerState<BathymetryRefreshTile> createState() =>
      _BathymetryRefreshTileState();
}

class _BathymetryRefreshTileState extends ConsumerState<BathymetryRefreshTile> {
  bool _isRefreshing = false;

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    widget.onBusyChanged?.call(true);
    final refresh = ref.read(swissBathyManualRefreshProvider);
    SwissBathyRefreshSummary? summary;
    try {
      summary = await refresh();
    } catch (_) {
      summary = null;
    } finally {
      // Both guarded by the same `mounted` check: widget.onBusyChanged is
      // wired by the parent to its own setState (three_d_maps_page.dart), so
      // calling it after this tile (and so its ancestor) is disposed --
      // e.g. the diver navigated away while the refresh was still in
      // flight -- would throw "setState() called after dispose()" on the
      // parent, not just this widget (found by code review).
      if (mounted) {
        setState(() => _isRefreshing = false);
        widget.onBusyChanged?.call(false);
      }
    }
    if (!mounted) return;

    // `summary == null` means the refresh could not even be attempted (e.g.
    // the local cache database was not initialized) -- a real failure, not
    // "nothing to check" -- so it must not fall into the up-to-date branch.
    //
    // total == 0 means the sweep reached a verdict on nothing, which on a
    // fresh install (or before any Swiss lake view has been opened) means
    // there was no cached data to check. Reporting that as "up to date"
    // reads as a positive confirmation the app cannot actually make, so it
    // gets its own message.
    final message = summary == null
        ? context.l10n.settings_appearance_bathymetryRefresh_resultFailed
        : summary.total == 0
        ? context.l10n.settings_appearance_bathymetryRefresh_resultNothingCached
        : summary.updated > 0
        ? context.l10n.settings_appearance_bathymetryRefresh_resultUpdated(
            summary.updated,
          )
        : summary.failed > 0
        ? context.l10n.settings_appearance_bathymetryRefresh_resultFailed
        : context.l10n.settings_appearance_bathymetryRefresh_resultUpToDate;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: widget.leading,
      title: Text(context.l10n.settings_appearance_bathymetryRefresh),
      subtitle: Text(
        context.l10n.settings_appearance_bathymetryRefresh_subtitle,
      ),
      trailing: _isRefreshing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _isRefreshing ? null : _refresh,
    );
  }
}
