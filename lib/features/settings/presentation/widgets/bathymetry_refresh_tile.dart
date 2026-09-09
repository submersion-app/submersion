import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/data/sources/swissbathy3d_source.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Manual "reload map data" tile: immediately revalidates every cached
/// swissBATHY3D tile via the same light STAC metadata check the periodic
/// 30-day check performs, instead of waiting for it to elapse.
///
/// Shared between [AppearancePage] and settings_page.dart's
/// `_AppearanceSectionContent`, which are both real, user-reachable paths to
/// the appearance settings (see settingsSectionDedicatedRoutes and the
/// desktop master-detail layout) -- previously each carried its own copy of
/// this logic, which could drift out of sync.
class BathymetryRefreshTile extends ConsumerStatefulWidget {
  final Widget leading;

  const BathymetryRefreshTile({super.key, required this.leading});

  @override
  ConsumerState<BathymetryRefreshTile> createState() =>
      _BathymetryRefreshTileState();
}

class _BathymetryRefreshTileState extends ConsumerState<BathymetryRefreshTile> {
  bool _isRefreshing = false;

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    final refresh = ref.read(swissBathyManualRefreshProvider);
    SwissBathyRefreshSummary? summary;
    try {
      summary = await refresh();
    } catch (_) {
      summary = null;
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
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
