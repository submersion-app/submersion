import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import '../../../../core/utils/unit_formatter.dart';
import '../../../dive_centers/presentation/providers/dive_center_providers.dart';
import '../../../dive_sites/presentation/providers/site_providers.dart';
import '../../../dive_types/presentation/providers/dive_type_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../tags/presentation/providers/tag_providers.dart';
import '../../../trips/presentation/providers/trip_providers.dart';
import '../providers/dive_providers.dart';

/// Advanced search page with all filter options in collapsible sections.
///
/// This page provides a comprehensive form for searching dives with
/// all available filter criteria. When the user taps "Search", the
/// filters are applied and they're navigated to the dive list.
class DiveSearchPage extends ConsumerStatefulWidget {
  const DiveSearchPage({super.key});

  @override
  ConsumerState<DiveSearchPage> createState() => _DiveSearchPageState();
}

class _DiveSearchPageState extends ConsumerState<DiveSearchPage> {
  // Date Range
  DateTime? _startDate;
  DateTime? _endDate;

  // Location
  String? _siteId;
  String? _tripId;
  String? _diveCenterId;

  // Conditions
  double? _minDepth;
  double? _maxDepth;
  int? _minDurationMinutes;
  int? _maxDurationMinutes;

  // Gas & Equipment
  String? _diveTypeId;
  double? _minO2Percent;
  double? _maxO2Percent;
  List<String> _equipmentIds = [];

  // Social
  String? _buddyNameFilter;

  // Organization
  List<String> _selectedTagIds = [];
  int? _minRating;
  bool _favoritesOnly = false;

  // Controllers
  final _minDepthController = TextEditingController();
  final _maxDepthController = TextEditingController();
  final _minDurationController = TextEditingController();
  final _maxDurationController = TextEditingController();
  final _buddyNameController = TextEditingController();

  // Expansion state
  final Map<String, bool> _expanded = {
    'date': true,
    'location': false,
    'conditions': false,
    'gas': false,
    'social': false,
    'organization': false,
  };

  @override
  void initState() {
    super.initState();
    // Initialize from current filter state
    final filter = ref.read(diveFilterProvider);
    _startDate = filter.startDate;
    _endDate = filter.endDate;
    _siteId = filter.siteId;
    _tripId = filter.tripId;
    _diveCenterId = filter.diveCenterId;
    _minDepth = filter.minDepth;
    _maxDepth = filter.maxDepth;
    _minDurationMinutes = filter.minDurationMinutes;
    _maxDurationMinutes = filter.maxDurationMinutes;
    _diveTypeId = filter.diveTypeId;
    _minO2Percent = filter.minO2Percent;
    _maxO2Percent = filter.maxO2Percent;
    _equipmentIds = List.from(filter.equipmentIds);
    _buddyNameFilter = filter.buddyNameFilter;
    _selectedTagIds = List.from(filter.tagIds);
    _minRating = filter.minRating;
    _favoritesOnly = filter.favoritesOnly ?? false;

    // Set controller text
    _minDepthController.text = _minDepth?.toStringAsFixed(0) ?? '';
    _maxDepthController.text = _maxDepth?.toStringAsFixed(0) ?? '';
    _minDurationController.text = _minDurationMinutes?.toString() ?? '';
    _maxDurationController.text = _maxDurationMinutes?.toString() ?? '';
    _buddyNameController.text = _buddyNameFilter ?? '';

    // Auto-expand sections with active filters
    if (_startDate != null || _endDate != null) _expanded['date'] = true;
    if (_siteId != null || _tripId != null || _diveCenterId != null) {
      _expanded['location'] = true;
    }
    if (_minDepth != null ||
        _maxDepth != null ||
        _minDurationMinutes != null ||
        _maxDurationMinutes != null) {
      _expanded['conditions'] = true;
    }
    if (_diveTypeId != null ||
        _minO2Percent != null ||
        _maxO2Percent != null ||
        _equipmentIds.isNotEmpty) {
      _expanded['gas'] = true;
    }
    if (_buddyNameFilter != null && _buddyNameFilter!.isNotEmpty) {
      _expanded['social'] = true;
    }
    if (_selectedTagIds.isNotEmpty || _minRating != null || _favoritesOnly) {
      _expanded['organization'] = true;
    }
  }

  @override
  void dispose() {
    _minDepthController.dispose();
    _maxDepthController.dispose();
    _minDurationController.dispose();
    _maxDurationController.dispose();
    _buddyNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Search'),
        actions: [
          TextButton(onPressed: _clearAll, child: const Text('Clear All')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Date Range Section
          _buildSection(
            key: 'date',
            title: 'Date Range',
            icon: Icons.calendar_today,
            child: _buildDateRangeContent(units),
          ),

          // Location Section
          _buildSection(
            key: 'location',
            title: 'Location',
            icon: Icons.location_on,
            child: _buildLocationContent(),
          ),

          // Conditions Section
          _buildSection(
            key: 'conditions',
            title: 'Conditions',
            icon: Icons.waves,
            child: _buildConditionsContent(),
          ),

          // Gas & Equipment Section
          _buildSection(
            key: 'gas',
            title: 'Gas & Equipment',
            icon: Icons.propane_tank,
            child: _buildGasEquipmentContent(),
          ),

          // Social Section
          _buildSection(
            key: 'social',
            title: 'Social',
            icon: Icons.people,
            child: _buildSocialContent(),
          ),

          // Organization Section
          _buildSection(
            key: 'organization',
            title: 'Organization',
            icon: Icons.label,
            child: _buildOrganizationContent(),
          ),

          const SizedBox(height: 16),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _applyAndSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String key,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final isExpanded = _expanded[key] ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon, color: theme.colorScheme.primary),
            title: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
            onTap: () {
              setState(() {
                _expanded[key] = !isExpanded;
              });
            },
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
        ],
      ),
    );
  }

  Widget _buildDateRangeContent(UnitFormatter units) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _selectDate(isStart: true),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  _startDate != null ? units.formatDate(_startDate) : 'Start',
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('to'),
            ),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _selectDate(isStart: false),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  _endDate != null ? units.formatDate(_endDate) : 'End',
                ),
              ),
            ),
          ],
        ),
        if (_startDate != null || _endDate != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() {
                  _startDate = null;
                  _endDate = null;
                });
              },
              child: const Text('Clear dates'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationContent() {
    final sites = ref.watch(sitesProvider);
    final trips = ref.watch(allTripsProvider);
    final diveCenters = ref.watch(allDiveCentersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dive Site
        sites.when(
          data: (siteList) => DropdownButtonFormField<String?>(
            initialValue: _siteId,
            decoration: const InputDecoration(
              labelText: 'Dive Site',
              prefixIcon: Icon(Icons.location_on),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All sites')),
              ...siteList.map((site) {
                return DropdownMenuItem(value: site.id, child: Text(site.name));
              }),
            ],
            onChanged: (value) => setState(() => _siteId = value),
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Error loading sites'),
        ),
        const SizedBox(height: 16),

        // Trip
        trips.when(
          data: (tripList) => DropdownButtonFormField<String?>(
            initialValue: _tripId,
            decoration: const InputDecoration(
              labelText: 'Trip',
              prefixIcon: Icon(Icons.flight),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All trips')),
              ...tripList.map((trip) {
                return DropdownMenuItem(value: trip.id, child: Text(trip.name));
              }),
            ],
            onChanged: (value) => setState(() => _tripId = value),
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Error loading trips'),
        ),
        const SizedBox(height: 16),

        // Dive Center
        diveCenters.when(
          data: (centerList) => DropdownButtonFormField<String?>(
            initialValue: _diveCenterId,
            decoration: const InputDecoration(
              labelText: 'Dive Center',
              prefixIcon: Icon(Icons.store),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All centers')),
              ...centerList.map((center) {
                return DropdownMenuItem(
                  value: center.id,
                  child: Text(center.name),
                );
              }),
            ],
            onChanged: (value) => setState(() => _diveCenterId = value),
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Error loading dive centers'),
        ),
      ],
    );
  }

  Widget _buildConditionsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Depth Range
        Text('Depth Range (m)', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _minDepthController,
                decoration: const InputDecoration(
                  labelText: 'Min',
                  prefixIcon: Icon(Icons.arrow_downward),
                  suffixText: 'm',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => _minDepth = double.tryParse(value),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _maxDepthController,
                decoration: const InputDecoration(
                  labelText: 'Max',
                  prefixIcon: Icon(Icons.arrow_downward),
                  suffixText: 'm',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => _maxDepth = double.tryParse(value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Duration Range
        Text(
          'Duration Range (min)',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _minDurationController,
                decoration: const InputDecoration(
                  labelText: 'Min',
                  prefixIcon: Icon(Icons.timer),
                  suffixText: 'min',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => _minDurationMinutes = int.tryParse(value),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _maxDurationController,
                decoration: const InputDecoration(
                  labelText: 'Max',
                  prefixIcon: Icon(Icons.timer),
                  suffixText: 'min',
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => _maxDurationMinutes = int.tryParse(value),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGasEquipmentContent() {
    final diveTypesAsync = ref.watch(diveTypesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dive Type
        diveTypesAsync.when(
          data: (diveTypes) => DropdownButtonFormField<String?>(
            initialValue: _diveTypeId,
            decoration: const InputDecoration(
              labelText: 'Dive Type',
              prefixIcon: Icon(Icons.category),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All types')),
              ...diveTypes.map((type) {
                return DropdownMenuItem(value: type.id, child: Text(type.name));
              }),
            ],
            onChanged: (value) => setState(() => _diveTypeId = value),
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('Error loading dive types'),
        ),
        const SizedBox(height: 24),

        // Gas Mix
        Text('Gas Mix (O₂%)', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: _minO2Percent == null && _maxO2Percent == null,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _minO2Percent = null;
                    _maxO2Percent = null;
                  });
                }
              },
            ),
            ChoiceChip(
              label: const Text('Air (21%)'),
              selected: _minO2Percent == 20 && _maxO2Percent == 22,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _minO2Percent = 20;
                    _maxO2Percent = 22;
                  });
                }
              },
            ),
            ChoiceChip(
              label: const Text('Nitrox (>21%)'),
              selected: _minO2Percent == 22 && _maxO2Percent == null,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _minO2Percent = 22;
                    _maxO2Percent = null;
                  });
                }
              },
            ),
            ChoiceChip(
              label: const Text('Trimix (<21% O₂)'),
              selected: _maxO2Percent == 21 && _minO2Percent == null,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _minO2Percent = null;
                    _maxO2Percent = 21;
                  });
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialContent() {
    return TextField(
      controller: _buddyNameController,
      decoration: const InputDecoration(
        labelText: 'Buddy Name',
        hintText: 'Search by buddy name',
        prefixIcon: Icon(Icons.person),
      ),
      onChanged: (value) {
        _buddyNameFilter = value.isEmpty ? null : value;
      },
    );
  }

  Widget _buildOrganizationContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Favorites
        SwitchListTile(
          title: const Text('Favorites Only'),
          secondary: Icon(
            Icons.favorite,
            color: _favoritesOnly ? Colors.red : null,
          ),
          value: _favoritesOnly,
          onChanged: (value) => setState(() => _favoritesOnly = value),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),

        // Minimum Rating
        Text('Minimum Rating', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final rating = index + 1;
            final isSelected = _minRating != null && rating <= _minRating!;
            return IconButton(
              icon: Icon(
                isSelected ? Icons.star : Icons.star_border,
                color: isSelected ? Colors.amber : null,
                size: 32,
              ),
              onPressed: () {
                setState(() {
                  if (_minRating == rating) {
                    _minRating = null;
                  } else {
                    _minRating = rating;
                  }
                });
              },
            );
          }),
        ),
        const SizedBox(height: 16),

        // Tags
        Text('Tags', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 8),
        ref
            .watch(tagListNotifierProvider)
            .when(
              data: (allTags) {
                if (allTags.isEmpty) {
                  return const Text(
                    'No tags created yet',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allTags.map((tag) {
                    final isSelected = _selectedTagIds.contains(tag.id);
                    return FilterChip(
                      label: Text(tag.name),
                      selected: isSelected,
                      selectedColor: tag.color.withValues(alpha: 0.3),
                      checkmarkColor: tag.color,
                      side: BorderSide(
                        color: isSelected ? tag.color : Colors.grey.shade300,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedTagIds.add(tag.id);
                          } else {
                            _selectedTagIds.remove(tag.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (_, _) => const Text('Error loading tags'),
            ),
      ],
    );
  }

  Future<void> _selectDate({required bool isStart}) async {
    final initialDate = isStart ? _startDate : _endDate;
    final firstDate = DateTime(2000);
    final lastDate = DateTime.now().add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _clearAll() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _siteId = null;
      _tripId = null;
      _diveCenterId = null;
      _minDepth = null;
      _maxDepth = null;
      _minDurationMinutes = null;
      _maxDurationMinutes = null;
      _diveTypeId = null;
      _minO2Percent = null;
      _maxO2Percent = null;
      _equipmentIds = [];
      _buddyNameFilter = null;
      _selectedTagIds = [];
      _minRating = null;
      _favoritesOnly = false;

      _minDepthController.clear();
      _maxDepthController.clear();
      _minDurationController.clear();
      _maxDurationController.clear();
      _buddyNameController.clear();
    });
  }

  void _applyAndSearch() {
    // Apply all filters
    ref.read(diveFilterProvider.notifier).state = DiveFilterState(
      startDate: _startDate,
      endDate: _endDate,
      siteId: _siteId,
      tripId: _tripId,
      diveCenterId: _diveCenterId,
      minDepth: _minDepth,
      maxDepth: _maxDepth,
      minDurationMinutes: _minDurationMinutes,
      maxDurationMinutes: _maxDurationMinutes,
      diveTypeId: _diveTypeId,
      minO2Percent: _minO2Percent,
      maxO2Percent: _maxO2Percent,
      equipmentIds: _equipmentIds,
      buddyNameFilter: _buddyNameFilter,
      tagIds: _selectedTagIds,
      minRating: _minRating,
      favoritesOnly: _favoritesOnly ? true : null,
    );

    // Navigate to dive list
    context.go('/dives');
  }
}
