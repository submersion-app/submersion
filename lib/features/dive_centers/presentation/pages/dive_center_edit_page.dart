import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/dive_center.dart';
import '../providers/dive_center_providers.dart';

class DiveCenterEditPage extends ConsumerStatefulWidget {
  final String? centerId;

  const DiveCenterEditPage({super.key, this.centerId});

  @override
  ConsumerState<DiveCenterEditPage> createState() => _DiveCenterEditPageState();
}

class _DiveCenterEditPageState extends ConsumerState<DiveCenterEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _countryController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _websiteController;
  late TextEditingController _notesController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;

  double? _rating;
  List<String> _selectedAffiliations = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  static const List<String> _availableAffiliations = [
    'PADI',
    'SSI',
    'NAUI',
    'SDI/TDI',
    'GUE',
    'RAID',
    'BSAC',
    'CMAS',
    'IANTD',
    'PSAI',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _locationController = TextEditingController();
    _countryController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _websiteController = TextEditingController();
    _notesController = TextEditingController();
    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _countryController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _notesController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  void _initializeFromCenter(DiveCenter center) {
    if (_isInitialized) return;
    _isInitialized = true;

    _nameController.text = center.name;
    _locationController.text = center.location ?? '';
    _countryController.text = center.country ?? '';
    _phoneController.text = center.phone ?? '';
    _emailController.text = center.email ?? '';
    _websiteController.text = center.website ?? '';
    _notesController.text = center.notes;
    _latitudeController.text =
        center.latitude?.toStringAsFixed(6) ?? '';
    _longitudeController.text =
        center.longitude?.toStringAsFixed(6) ?? '';
    _rating = center.rating;
    _selectedAffiliations = List.from(center.affiliations);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      final center = DiveCenter(
        id: widget.centerId ?? '',
        name: _nameController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        latitude: _latitudeController.text.trim().isEmpty
            ? null
            : double.tryParse(_latitudeController.text.trim()),
        longitude: _longitudeController.text.trim().isEmpty
            ? null
            : double.tryParse(_longitudeController.text.trim()),
        country: _countryController.text.trim().isEmpty
            ? null
            : _countryController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        website: _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
        affiliations: _selectedAffiliations,
        rating: _rating,
        notes: _notesController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      final notifier = ref.read(diveCenterListNotifierProvider.notifier);

      if (widget.centerId != null) {
        await notifier.updateDiveCenter(center);
      } else {
        await notifier.addDiveCenter(center);
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving dive center: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.centerId != null;

    if (isEditing) {
      final centerAsync = ref.watch(diveCenterByIdProvider(widget.centerId!));

      return centerAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Edit Dive Center')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Scaffold(
          appBar: AppBar(title: const Text('Edit Dive Center')),
          body: Center(child: Text('Error: $error')),
        ),
        data: (center) {
          if (center == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Edit Dive Center')),
              body: const Center(child: Text('Dive center not found')),
            );
          }
          _initializeFromCenter(center);
          return _buildForm(context, isEditing: true);
        },
      );
    }

    return _buildForm(context, isEditing: false);
  }

  Widget _buildForm(BuildContext context, {required bool isEditing}) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Dive Center' : 'Add Dive Center'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Basic Info Section
            Text(
              'Basic Information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                hintText: 'Enter dive center name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'e.g., Koh Tao, Thailand',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _countryController,
              decoration: const InputDecoration(
                labelText: 'Country',
                hintText: 'e.g., Thailand',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Rating
            _buildRatingSelector(),

            const SizedBox(height: 24),

            // Affiliations Section
            Text(
              'Affiliations',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Select training agencies this center is affiliated with',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableAffiliations.map((affiliation) {
                final isSelected = _selectedAffiliations.contains(affiliation);
                return FilterChip(
                  label: Text(affiliation),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedAffiliations.add(affiliation);
                      } else {
                        _selectedAffiliations.remove(affiliation);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Contact Section
            Text(
              'Contact Information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                hintText: '+1 234 567 890',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'info@divecenter.com',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null &&
                    value.isNotEmpty &&
                    !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _websiteController,
              decoration: const InputDecoration(
                labelText: 'Website',
                hintText: 'www.divecenter.com',
                prefixIcon: Icon(Icons.language_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),

            const SizedBox(height: 24),

            // Coordinates Section
            Text(
              'GPS Coordinates',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Optional - for map display',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latitudeController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      hintText: '10.4613',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
                      hintText: '99.8359',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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

            const SizedBox(height: 24),

            // Notes Section
            Text(
              'Notes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Any additional information...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rating',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ...List.generate(
              5,
              (index) => IconButton(
                onPressed: () {
                  setState(() {
                    if (_rating == index + 1) {
                      _rating = null;
                    } else {
                      _rating = (index + 1).toDouble();
                    }
                  });
                },
                icon: Icon(
                  _rating != null && index < _rating!
                      ? Icons.star
                      : Icons.star_border,
                  color: Colors.amber.shade700,
                  size: 32,
                ),
              ),
            ),
            if (_rating != null) ...[
              const SizedBox(width: 8),
              Text(
                _rating!.toStringAsFixed(0),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () => setState(() => _rating = null),
                child: const Text('Clear'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
