import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/location_service.dart';
import '../../domain/entities/dive_site.dart';
import '../providers/site_providers.dart';
import '../widgets/location_picker_map.dart';

class SiteEditPage extends ConsumerStatefulWidget {
  final String? siteId;

  const SiteEditPage({super.key, this.siteId});

  bool get isEditing => siteId != null;

  @override
  ConsumerState<SiteEditPage> createState() => _SiteEditPageState();
}

class _SiteEditPageState extends ConsumerState<SiteEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _countryController = TextEditingController();
  final _regionController = TextEditingController();
  final _minDepthController = TextEditingController();
  final _maxDepthController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _notesController = TextEditingController();
  final _hazardsController = TextEditingController();
  final _accessNotesController = TextEditingController();
  final _mooringNumberController = TextEditingController();
  final _parkingInfoController = TextEditingController();

  double _rating = 0;
  SiteDifficulty? _difficulty;
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _countryController.dispose();
    _regionController.dispose();
    _minDepthController.dispose();
    _maxDepthController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _notesController.dispose();
    _hazardsController.dispose();
    _accessNotesController.dispose();
    _mooringNumberController.dispose();
    _parkingInfoController.dispose();
    super.dispose();
  }

  void _initializeFromSite(DiveSite site) {
    if (_isInitialized) return;
    _isInitialized = true;

    _nameController.text = site.name;
    _descriptionController.text = site.description;
    _countryController.text = site.country ?? '';
    _regionController.text = site.region ?? '';
    _minDepthController.text = site.minDepth?.toString() ?? '';
    _maxDepthController.text = site.maxDepth?.toString() ?? '';
    _latitudeController.text = site.location?.latitude.toString() ?? '';
    _longitudeController.text = site.location?.longitude.toString() ?? '';
    _notesController.text = site.notes;
    _hazardsController.text = site.hazards ?? '';
    _accessNotesController.text = site.accessNotes ?? '';
    _mooringNumberController.text = site.mooringNumber ?? '';
    _parkingInfoController.text = site.parkingInfo ?? '';
    _rating = site.rating ?? 0;
    _difficulty = site.difficulty;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing) {
      final siteAsync = ref.watch(siteProvider(widget.siteId!));
      return siteAsync.when(
        data: (site) {
          if (site == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Site Not Found')),
              body: const Center(child: Text('This site no longer exists.')),
            );
          }
          _initializeFromSite(site);
          return _buildForm(context);
        },
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Loading...')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: Center(child: Text('Error: $error')),
        ),
      );
    }

    return _buildForm(context);
  }

  Widget _buildForm(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Site' : 'New Site'),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Site Name *',
                prefixIcon: Icon(Icons.location_on),
                hintText: 'e.g., Blue Hole',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a site name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description),
                hintText: 'Brief description of the site',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Country & Region
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _countryController,
                    decoration: const InputDecoration(
                      labelText: 'Country',
                      prefixIcon: Icon(Icons.flag),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _regionController,
                    decoration: const InputDecoration(
                      labelText: 'Region',
                      prefixIcon: Icon(Icons.map),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Depth Section
            _buildDepthSection(context),
            const SizedBox(height: 16),

            // Difficulty
            _buildDifficultySection(context),
            const SizedBox(height: 16),

            // Rating
            _buildRatingSection(context),
            const SizedBox(height: 16),

            // GPS Coordinates
            _buildGpsSection(context),
            const SizedBox(height: 16),

            // Access & Logistics Section
            _buildAccessSection(context),
            const SizedBox(height: 16),

            // Safety Section
            _buildSafetySection(context),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'General Notes',
                prefixIcon: Icon(Icons.notes),
                hintText: 'Any other information about this site',
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 32),

            // Save Button
            FilledButton(
              onPressed: _isLoading ? null : _saveSite,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.isEditing ? 'Save Changes' : 'Add Site'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Rating',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = index + 1.0;
                    });
                  },
                );
              }),
            ),
            if (_rating > 0)
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _rating = 0),
                  child: const Text('Clear Rating'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepthSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.arrow_downward),
                const SizedBox(width: 8),
                Text(
                  'Depth Range',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'From the shallowest to the deepest point',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minDepthController,
                    decoration: const InputDecoration(
                      labelText: 'Minimum Depth (m)',
                      hintText: 'e.g., 5',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('to'),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _maxDepthController,
                    decoration: const InputDecoration(
                      labelText: 'Maximum Depth (m)',
                      hintText: 'e.g., 30',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultySection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fitness_center),
                const SizedBox(width: 8),
                Text(
                  'Difficulty Level',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: SiteDifficulty.values.map((difficulty) {
                final isSelected = _difficulty == difficulty;
                return ChoiceChip(
                  label: Text(difficulty.displayName),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _difficulty = selected ? difficulty : null;
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  bool _isGettingLocation = false;

  Future<void> _useMyLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      final locationService = LocationService.instance;
      final result = await locationService.getCurrentLocation(includeGeocoding: true);

      if (result == null) {
        if (mounted) {
          final isMobile = !kIsWeb && (Platform.isIOS || Platform.isAndroid);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isMobile
                    ? 'Unable to get location. Please check permissions.'
                    : 'Unable to get location. Location services may not be available.',
              ),
              action: isMobile
                  ? SnackBarAction(
                      label: 'Settings',
                      onPressed: () => locationService.openAppSettings(),
                    )
                  : null,
            ),
          );
        }
        return;
      }

      setState(() {
        _latitudeController.text = result.latitude.toStringAsFixed(6);
        _longitudeController.text = result.longitude.toStringAsFixed(6);

        // Auto-fill country and region if empty
        if (_countryController.text.isEmpty && result.country != null) {
          _countryController.text = result.country!;
        }
        if (_regionController.text.isEmpty && result.region != null) {
          _regionController.text = result.region!;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location captured${result.accuracy != null ? ' (±${result.accuracy!.toStringAsFixed(0)}m)' : ''}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  Future<void> _pickFromMap() async {
    // Parse existing coordinates if available
    LatLng? initialLocation;
    final lat = double.tryParse(_latitudeController.text);
    final lng = double.tryParse(_longitudeController.text);
    if (lat != null && lng != null) {
      initialLocation = LatLng(lat, lng);
    }

    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (context) => LocationPickerMap(
          initialLocation: initialLocation,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitudeController.text = result.latitude.toStringAsFixed(6);
        _longitudeController.text = result.longitude.toStringAsFixed(6);

        // Auto-fill country and region if empty
        if (_countryController.text.isEmpty && result.country != null) {
          _countryController.text = result.country!;
        }
        if (_regionController.text.isEmpty && result.region != null) {
          _regionController.text = result.region!;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location selected from map')),
      );
    }
  }

  Widget _buildGpsSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.gps_fixed),
                const SizedBox(width: 8),
                Text(
                  'GPS Coordinates',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a location method - coordinates will auto-fill country and region',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _isGettingLocation ? null : _useMyLocation,
                  icon: _isGettingLocation
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        )
                      : const Icon(Icons.my_location, size: 18),
                  label: Text(_isGettingLocation ? 'Getting...' : 'Use My Location'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickFromMap,
                  icon: const Icon(Icons.map, size: 18),
                  label: const Text('Pick from Map'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latitudeController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      hintText: 'e.g., 21.4225',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final lat = double.tryParse(value);
                        if (lat == null || lat < -90 || lat > 90) {
                          return 'Invalid latitude';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _longitudeController,
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      hintText: 'e.g., -86.7542',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final lng = double.tryParse(value);
                        if (lng == null || lng < -180 || lng > 180) {
                          return 'Invalid longitude';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions),
                const SizedBox(width: 8),
                Text(
                  'Access & Logistics',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accessNotesController,
              decoration: const InputDecoration(
                labelText: 'Access Notes',
                hintText: 'How to get to the site, entry/exit points, shore/boat access',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _mooringNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Mooring Number',
                      hintText: 'e.g., Buoy #12',
                      prefixIcon: Icon(Icons.anchor),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _parkingInfoController,
              decoration: const InputDecoration(
                labelText: 'Parking Information',
                hintText: 'Parking availability, fees, tips',
                prefixIcon: Icon(Icons.local_parking),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetySection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  'Hazards & Safety',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'List any hazards or safety considerations',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _hazardsController,
              decoration: const InputDecoration(
                labelText: 'Hazards',
                hintText: 'e.g., Strong currents, boat traffic, jellyfish, sharp coral',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSite() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      GeoPoint? location;
      final latText = _latitudeController.text.trim();
      final lngText = _longitudeController.text.trim();
      
      if (latText.isNotEmpty && lngText.isNotEmpty) {
        final lat = double.tryParse(latText);
        final lng = double.tryParse(lngText);
        if (lat != null && lng != null) {
          location = GeoPoint(lat, lng);
        }
      }

      final site = DiveSite(
        id: widget.siteId ?? '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
        region: _regionController.text.trim().isEmpty ? null : _regionController.text.trim(),
        minDepth: double.tryParse(_minDepthController.text),
        maxDepth: double.tryParse(_maxDepthController.text),
        difficulty: _difficulty,
        location: location,
        rating: _rating > 0 ? _rating : null,
        notes: _notesController.text.trim(),
        hazards: _hazardsController.text.trim().isEmpty ? null : _hazardsController.text.trim(),
        accessNotes: _accessNotesController.text.trim().isEmpty ? null : _accessNotesController.text.trim(),
        mooringNumber: _mooringNumberController.text.trim().isEmpty ? null : _mooringNumberController.text.trim(),
        parkingInfo: _parkingInfoController.text.trim().isEmpty ? null : _parkingInfoController.text.trim(),
      );

      final notifier = ref.read(siteListNotifierProvider.notifier);

      if (widget.isEditing) {
        await notifier.updateSite(site);
      } else {
        await notifier.addSite(site);
      }

      // Invalidate providers to refresh data
      ref.invalidate(sitesWithCountsProvider);
      ref.invalidate(sitesProvider);
      if (widget.isEditing) {
        ref.invalidate(siteProvider(widget.siteId!));
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing ? 'Site updated' : 'Site added'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving site: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Site'),
        content: const Text(
          'Are you sure you want to delete this site? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteSite();
    }
  }

  Future<void> _deleteSite() async {
    setState(() => _isLoading = true);

    try {
      await ref.read(siteListNotifierProvider.notifier).deleteSite(widget.siteId!);
      ref.invalidate(sitesWithCountsProvider);
      ref.invalidate(sitesProvider);

      if (mounted) {
        context.go('/sites');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Site deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting site: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }
}
