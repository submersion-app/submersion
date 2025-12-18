import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/location_service.dart';

/// Result from the location picker
class PickedLocation {
  final double latitude;
  final double longitude;
  final String? country;
  final String? region;
  final String? locality;

  const PickedLocation({
    required this.latitude,
    required this.longitude,
    this.country,
    this.region,
    this.locality,
  });
}

/// A full-screen map for picking a location
class LocationPickerMap extends StatefulWidget {
  /// Initial location to center the map on (optional)
  final LatLng? initialLocation;

  const LocationPickerMap({
    super.key,
    this.initialLocation,
  });

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  bool _isGeocoding = false;
  String? _locationPreview;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    if (_selectedLocation != null) {
      _updateLocationPreview();
    }
  }

  Future<void> _updateLocationPreview() async {
    if (_selectedLocation == null) return;

    setState(() => _isGeocoding = true);

    try {
      final result = await LocationService.instance.reverseGeocode(
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
      );

      if (mounted) {
        final parts = <String>[];
        if (result.locality != null) parts.add(result.locality!);
        if (result.region != null) parts.add(result.region!);
        if (result.country != null) parts.add(result.country!);

        setState(() {
          _locationPreview = parts.isNotEmpty ? parts.join(', ') : null;
          _isGeocoding = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeocoding = false);
      }
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
      _locationPreview = null;
    });
    _updateLocationPreview();
  }

  Future<void> _confirmSelection() async {
    if (_selectedLocation == null) return;

    // Get geocoding data before returning
    final result = await LocationService.instance.reverseGeocode(
      _selectedLocation!.latitude,
      _selectedLocation!.longitude,
    );

    if (mounted) {
      Navigator.of(context).pop(PickedLocation(
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        country: result.country,
        region: result.region,
        locality: result.locality,
      ));
    }
  }

  Future<void> _useCurrentLocation() async {
    final location = await LocationService.instance.getCurrentLocation(
      includeGeocoding: false,
    );

    if (location != null && mounted) {
      final newLocation = LatLng(location.latitude, location.longitude);
      setState(() {
        _selectedLocation = newLocation;
        _locationPreview = null;
      });
      _mapController.move(newLocation, 14.0);
      _updateLocationPreview();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Default to a world view if no initial location
    final initialCenter = widget.initialLocation ?? const LatLng(20.0, 0.0);
    final initialZoom = widget.initialLocation != null ? 12.0 : 2.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        actions: [
          if (_selectedLocation != null)
            TextButton.icon(
              onPressed: _confirmSelection,
              icon: const Icon(Icons.check),
              label: const Text('Confirm'),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: initialZoom,
              minZoom: 2.0,
              maxZoom: 18.0,
              onTap: _onMapTap,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.submersion.app',
                maxZoom: 19,
              ),
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.onPrimary,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.location_on,
                            size: 28,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Instructions overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.touch_app, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedLocation == null
                            ? 'Tap on the map to select a location'
                            : _isGeocoding
                                ? 'Looking up location...'
                                : _locationPreview ?? 'Location selected',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    if (_isGeocoding)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Coordinates display
          if (_selectedLocation != null)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Latitude',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                                Text(
                                  _selectedLocation!.latitude.toStringAsFixed(6),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontFamily: 'monospace',
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Longitude',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                                Text(
                                  _selectedLocation!.longitude.toStringAsFixed(6),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontFamily: 'monospace',
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // FAB for current location
          Positioned(
            bottom: 24,
            right: 16,
            child: FloatingActionButton(
              onPressed: _useCurrentLocation,
              tooltip: 'Use my location',
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}

