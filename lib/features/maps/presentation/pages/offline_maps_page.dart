import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/presentation/providers/offline_map_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/offline_map_tiles_section.dart';
import 'package:submersion/features/settings/presentation/widgets/terrain_data_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings page for everything the app keeps for use without a connection:
/// downloaded map tile regions, then cached 3D terrain (bathymetry) data.
///
/// Each section owns its own actions and busy state; the page only stacks
/// them. Pull-to-refresh re-reads the tile figures, the only numbers here
/// that are measured rather than tracked by a running action.
class OfflineMapsPage extends ConsumerWidget {
  const OfflineMapsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.maps_offline_title)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(cachedRegionsProvider);
          ref.invalidate(cacheStatsProvider);
        },
        // Not a lazy ListView: each section holds state that must outlive
        // being scrolled out of view (the terrain section's busy flags for an
        // action still running, the tile section's once-per-open store sweep),
        // and a lazy list disposes children far enough off screen.
        child: const SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [OfflineMapTilesSection(), TerrainDataSection()],
          ),
        ),
      ),
    );
  }
}
