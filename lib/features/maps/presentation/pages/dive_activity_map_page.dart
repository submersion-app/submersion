import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_controls.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_layer.dart';

/// Page showing heat map of dive activity.
///
/// Displays a world map with a heat map overlay showing where the user has
/// dived most frequently. Uses [diveActivityHeatMapProvider] which weights
/// points by dive count per site.
class DiveActivityMapPage extends ConsumerStatefulWidget {
  const DiveActivityMapPage({super.key});

  @override
  ConsumerState<DiveActivityMapPage> createState() =>
      _DiveActivityMapPageState();
}

class _DiveActivityMapPageState extends ConsumerState<DiveActivityMapPage> {
  final MapController _mapController = MapController();

  // Default to a world view
  static const _defaultCenter = LatLng(20.0, 0.0);
  static const _defaultZoom = 2.0;

  @override
  Widget build(BuildContext context) {
    final heatMapAsync = ref.watch(diveActivityHeatMapProvider);
    final settings = ref.watch(heatMapSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dive Activity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'List View',
            onPressed: () => context.go('/dives'),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: _defaultCenter,
              initialZoom: _defaultZoom,
              minZoom: 2.0,
              maxZoom: 18.0,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.submersion.app',
                maxZoom: 19,
              ),
              if (settings.isVisible)
                heatMapAsync.when(
                  data: (points) => HeatMapLayer(
                    points: points,
                    radius: settings.radius,
                    opacity: settings.opacity,
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
            ],
          ),

          // Heat map controls
          const Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: HeatMapControls(),
          ),

          // Loading indicator
          if (heatMapAsync.isLoading)
            const Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(child: CircularProgressIndicator()),
            ),

          // Empty state
          heatMapAsync.when(
            data: (points) {
              if (points.isEmpty) {
                return _buildEmptyState(context);
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.scuba_diving,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No dive activity to display',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Log dives with location data to see your activity on the map',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
