import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/maps/presentation/providers/offline_map_providers.dart';

/// Dialog for configuring and starting a region download.
///
/// Allows users to:
/// - Name the region (with auto-suggestion from reverse geocoding)
/// - Select min/max zoom levels
/// - View estimated tile count and storage size
/// - Start the download
class RegionDownloadDialog extends ConsumerStatefulWidget {
  final LatLng southWest;
  final LatLng northEast;

  const RegionDownloadDialog({
    super.key,
    required this.southWest,
    required this.northEast,
  });

  @override
  ConsumerState<RegionDownloadDialog> createState() =>
      _RegionDownloadDialogState();
}

class _RegionDownloadDialogState extends ConsumerState<RegionDownloadDialog> {
  final _nameController = TextEditingController();
  int _minZoom = 8;
  int _maxZoom = 16;
  bool _isEstimating = false;
  bool _isLoadingName = false;
  int? _estimatedTiles;

  /// Default tile layer options for OpenStreetMap.
  TileLayer get _tileLayerOptions => TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.submersion.app',
    maxZoom: 19,
  );

  @override
  void initState() {
    super.initState();
    _estimateTiles();
    _autoSuggestName();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Attempt to auto-suggest a name based on the center of the region.
  Future<void> _autoSuggestName() async {
    setState(() => _isLoadingName = true);

    try {
      // Calculate center of the bounding box
      final centerLat =
          (widget.southWest.latitude + widget.northEast.latitude) / 2;
      final centerLng =
          (widget.southWest.longitude + widget.northEast.longitude) / 2;

      final result = await LocationService.instance.reverseGeocode(
        centerLat,
        centerLng,
      );

      if (mounted && _nameController.text.isEmpty) {
        // Build a suggested name from the geocoding result
        final parts = <String>[];
        if (result.locality != null && result.locality!.isNotEmpty) {
          parts.add(result.locality!);
        }
        if (result.region != null && result.region!.isNotEmpty) {
          parts.add(result.region!);
        }
        if (result.country != null &&
            result.country!.isNotEmpty &&
            parts.length < 2) {
          parts.add(result.country!);
        }

        if (parts.isNotEmpty) {
          _nameController.text = parts.join(', ');
        }
      }
    } catch (e) {
      // Silently fail - user can still enter a name manually
    } finally {
      if (mounted) {
        setState(() => _isLoadingName = false);
      }
    }
  }

  Future<void> _estimateTiles() async {
    setState(() => _isEstimating = true);

    try {
      final service = ref.read(tileCacheServiceProvider);
      final count = await service.estimateTileCount(
        southWest: widget.southWest,
        northEast: widget.northEast,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
        options: _tileLayerOptions,
      );

      if (mounted) {
        setState(() {
          _estimatedTiles = count;
          _isEstimating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isEstimating = false);
      }
    }
  }

  String _formatEstimatedSize(int tiles) {
    // Rough estimate: ~30KB per tile on average for map tiles
    final bytes = tiles * 30 * 1024;
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _startDownload() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for this region')),
      );
      return;
    }

    Navigator.of(context).pop();

    // Start the download using the provider
    await ref
        .read(downloadProgressProvider.notifier)
        .downloadRegion(
          name: name,
          minLat: widget.southWest.latitude,
          maxLat: widget.northEast.latitude,
          minLng: widget.southWest.longitude,
          maxLng: widget.northEast.longitude,
          minZoom: _minZoom,
          maxZoom: _maxZoom,
          tileLayerOptions: _tileLayerOptions,
        );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Download Region'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Region name input
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Region Name',
                hintText: 'e.g., Cozumel, Mexico',
                prefixIcon: const Icon(Icons.label),
                suffixIcon: _isLoadingName
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 24),

            // Zoom range selection
            Text('Zoom Levels', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Higher zoom = more detail, larger download',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Min: $_minZoom'),
                      Slider(
                        value: _minZoom.toDouble(),
                        min: 1,
                        max: 14,
                        divisions: 13,
                        onChanged: (value) {
                          setState(() {
                            _minZoom = value.round();
                            if (_maxZoom < _minZoom) _maxZoom = _minZoom;
                          });
                          _estimateTiles();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Max: $_maxZoom'),
                      Slider(
                        value: _maxZoom.toDouble(),
                        min: 8,
                        max: 18,
                        divisions: 10,
                        onChanged: (value) {
                          setState(() {
                            _maxZoom = value.round();
                            if (_minZoom > _maxZoom) _minZoom = _maxZoom;
                          });
                          _estimateTiles();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tile estimate card
            Card(
              color: colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.storage, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _isEstimating
                          ? const Text('Estimating...')
                          : _estimatedTiles != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '~$_estimatedTiles tiles',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  '~${_formatEstimatedSize(_estimatedTiles!)}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            )
                          : const Text('Unable to estimate'),
                    ),
                  ],
                ),
              ),
            ),

            // Warning for large downloads
            if (_estimatedTiles != null && _estimatedTiles! > 10000)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      size: 20,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Large download. Consider reducing zoom levels or selecting a smaller region.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _startDownload,
          icon: const Icon(Icons.download),
          label: const Text('Download'),
        ),
      ],
    );
  }
}
