import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/core/network/proxy/effective_proxy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/maps/data/services/region_download_layer.dart';
import 'package:submersion/features/maps/domain/region_size_estimate.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/providers/offline_map_providers.dart';
import 'package:submersion/features/settings/presentation/providers/network_proxy_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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
  // Overview by default: a planning-sized download. The deeper levels hold
  // about three quarters of all tiles, so 16 was a very heavy default.
  int _maxZoom = 12;
  bool _isEstimating = false;
  bool _isLoadingName = false;
  int? _estimatedTiles;

  /// Above this many tiles the Download button is disabled: a request this big
  /// takes hours and is heavy use of a public tile server.
  static const int _maxTiles = 100000;

  bool get _overLimit => (_estimatedTiles ?? 0) > _maxTiles;

  /// Download needs a count for the current zoom levels, and it has to be
  /// within the limit. No count (still estimating, or the estimate failed)
  /// blocks it: the limit protects a public tile server, so it fails closed.
  bool get _canDownload =>
      !_isEstimating &&
      _estimatedTiles != null &&
      !_overLimit &&
      !_socks5Blocked;

  /// A SOCKS5 proxy the tiles would go through: every tile request of the
  /// download would fail, so it is refused up front with the reason (#3269).
  bool get _socks5Blocked => socks5BlocksRegionDownload(
    urlTemplate: ref.read(mapTileUrlProvider),
    proxy:
        ref.read(proxyStateProvider).value?.effective ??
        const EffectiveProxy.direct(),
  );

  /// Counts the estimates started, so a slow earlier one cannot overwrite the
  /// count of a later one.
  int _estimateRequest = 0;

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
        languageCode: ref.read(placeNameLanguageProvider),
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
    // The previous count belongs to other zoom levels: drop it first, so
    // Download can never act on it while the new estimate runs.
    final request = ++_estimateRequest;
    setState(() {
      _isEstimating = true;
      _estimatedTiles = null;
    });

    try {
      final service = ref.read(tileCacheServiceProvider);
      final count = await service.estimateTileCount(
        southWest: widget.southWest,
        northEast: widget.northEast,
        minZoom: _minZoom,
        maxZoom: _maxZoom,
        urlTemplate: ref.read(mapTileUrlProvider),
      );

      if (mounted && request == _estimateRequest) {
        setState(() {
          _estimatedTiles = count;
          _isEstimating = false;
        });
      }
    } catch (e) {
      // No count: Download stays disabled and the card says it is unavailable.
      if (mounted && request == _estimateRequest) {
        setState(() => _isEstimating = false);
      }
    }
  }

  String _formatEstimatedSize(int tiles) {
    // Learned from the regions already downloaded (their measured bytes per
    // tile), because real tiles average far below a flat guess: open water is
    // mostly skipped or tiny. Only regions with their own store were
    // measured. With none it is the generous flat 30 KB per tile.
    final regions = ref.watch(cachedRegionsProvider).value ?? const [];
    final measuredIds = ref.watch(regionStoreIdsProvider).value ?? const {};
    final bytes = estimateRegionBytes(
      tiles,
      regions,
      measuredRegionIds: measuredIds,
    );
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _startDownload() async {
    if (!_canDownload) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.maps_regionDownload_nameRequired)),
      );
      return;
    }

    Navigator.of(context).pop(true);

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
          urlTemplate: ref.read(mapTileUrlProvider),
        );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    // Rebuilds when the proxy or the tile server changes, for _socks5Blocked.
    ref.watch(proxyStateProvider);
    ref.watch(mapTileUrlProvider);

    return AlertDialog(
      title: Text(l10n.maps_regionDownload_title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Region name input
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.maps_regionDownload_nameLabel,
                hintText: l10n.maps_regionDownload_nameHint,
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
            Text(
              l10n.maps_regionDownload_zoomLevels,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.maps_regionDownload_zoomHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            // Quality presets: each is just a max zoom (min stays 8). Every
            // extra level is about four times the tiles.
            Wrap(
              spacing: 8,
              children: [
                for (final preset in [
                  (l10n.maps_regionDownload_presetOverview, 12),
                  (l10n.maps_regionDownload_presetDetail, 14),
                  (l10n.maps_regionDownload_presetFull, 16),
                ])
                  ChoiceChip(
                    label: Text(preset.$1),
                    selected: _minZoom == 8 && _maxZoom == preset.$2,
                    onSelected: (_) {
                      setState(() {
                        _minZoom = 8;
                        _maxZoom = preset.$2;
                      });
                      _estimateTiles();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.maps_regionDownload_minZoom(_minZoom)),
                      Slider(
                        value: _minZoom.toDouble(),
                        min: 1,
                        max: 14,
                        divisions: 13,
                        label: l10n.maps_regionDownload_minZoomSemantics(
                          _minZoom,
                        ),
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
                      Text(l10n.maps_regionDownload_maxZoom(_maxZoom)),
                      Slider(
                        value: _maxZoom.toDouble(),
                        min: 8,
                        max: 18,
                        divisions: 10,
                        label: l10n.maps_regionDownload_maxZoomSemantics(
                          _maxZoom,
                        ),
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
            Semantics(
              label: _isEstimating
                  ? l10n.maps_regionDownload_estimatingSemantics
                  : _estimatedTiles != null
                  ? l10n.maps_regionDownload_estimateSemantics(
                      _estimatedTiles!,
                      _formatEstimatedSize(_estimatedTiles!),
                    )
                  : l10n.maps_regionDownload_estimateUnavailableSemantics,
              child: Card(
                color: colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(Icons.storage, color: colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _isEstimating
                            ? Text(l10n.maps_regionDownload_estimating)
                            : _estimatedTiles != null
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.maps_regionDownload_tileCount(
                                      _estimatedTiles!,
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
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
                            : Text(
                                l10n.maps_regionDownload_estimateUnavailable,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Warning for large downloads
            if (_estimatedTiles != null &&
                _estimatedTiles! > 10000 &&
                !_overLimit)
              Semantics(
                label: l10n.maps_regionDownload_largeWarningSemantics,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.warning_amber,
                          size: 20,
                          color: colorScheme.error,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.maps_regionDownload_largeWarning,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_socks5Blocked)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  l10n.maps_regionDownload_socks5Unsupported,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (_overLimit)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  l10n.maps_regionDownload_tooManyTiles,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton.icon(
          onPressed: _canDownload ? _startDownload : null,
          icon: const Icon(Icons.download),
          label: Text(l10n.maps_regionDownload_downloadButton),
        ),
      ],
    );
  }
}
