import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

/// Filter sheet for dive list
class DiveFilterSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;
  final StateProvider<DiveFilterState> filterProvider;

  // `diveFilterProvider` is a `final` top-level variable, not `const`, so it
  // cannot be used as a parameter's default value (Dart requires those to be
  // compile-time constants). Instead the parameter is nullable and defaults
  // to null, then the initializer list resolves it to `diveFilterProvider`,
  // preserving a non-nullable `filterProvider` field for the rest of the
  // class to use. This also means the constructor can no longer be `const`,
  // but no call site ever invoked it as `const` (they all pass a runtime
  // `ref`), so this is not an observable behavior change.
  DiveFilterSheet({
    super.key,
    required this.ref,
    StateProvider<DiveFilterState>? filterProvider,
  }) : filterProvider = filterProvider ?? diveFilterProvider;

  @override
  ConsumerState<DiveFilterSheet> createState() => _DiveFilterSheetState();
}

class _DiveFilterSheetState extends ConsumerState<DiveFilterSheet> {
  late DateTime? _startDate;
  late DateTime? _endDate;
  late String? _diveTypeId;
  late String? _siteId;
  late double? _minDepth;
  late double? _maxDepth;
  late bool _favoritesOnly;
  late List<String> _selectedTagIds;

  // v1.5 filters
  late String? _buddyNameFilter;
  late double? _minO2Percent;
  late double? _maxO2Percent;
  late int? _minRating;
  late int? _minDurationMinutes;
  late int? _maxDurationMinutes;
  late String? _computerSerial;

  final _minDepthController = TextEditingController();
  final _maxDepthController = TextEditingController();
  final _buddyNameController = TextEditingController();
  final _minDurationController = TextEditingController();
  final _maxDurationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final filter = widget.ref.read(widget.filterProvider);
    _startDate = filter.startDate;
    _endDate = filter.endDate;
    _diveTypeId = filter.diveTypeId;
    _siteId = filter.siteId;
    _minDepth = filter.minDepth;
    _maxDepth = filter.maxDepth;
    _favoritesOnly = filter.favoritesOnly ?? false;
    _selectedTagIds = List.from(filter.tagIds);
    _minDepthController.text = _minDepth?.toStringAsFixed(0) ?? '';
    _maxDepthController.text = _maxDepth?.toStringAsFixed(0) ?? '';

    // v1.5 filters
    _buddyNameFilter = filter.buddyNameFilter;
    _buddyNameController.text = _buddyNameFilter ?? '';
    _minO2Percent = filter.minO2Percent;
    _maxO2Percent = filter.maxO2Percent;
    _minRating = filter.minRating;
    _minDurationMinutes = filter.minBottomTimeMinutes;
    _maxDurationMinutes = filter.maxBottomTimeMinutes;
    _computerSerial = filter.computerSerial;
    _minDurationController.text = _minDurationMinutes?.toString() ?? '';
    _maxDurationController.text = _maxDurationMinutes?.toString() ?? '';
  }

  @override
  void dispose() {
    _minDepthController.dispose();
    _maxDepthController.dispose();
    _buddyNameController.dispose();
    _minDurationController.dispose();
    _maxDurationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sites = ref.watch(sitesProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter Dives',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close filter',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Link to advanced search
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/dives/search');
                  },
                  icon: const Icon(Icons.manage_search, size: 18),
                  label: const Text('Advanced Search'),
                ),
              ),
              const SizedBox(height: 16),

              // Date Range Section
              Text(
                'Date Range',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _datePresetChip(context, 'All time', () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                  }),
                  _datePresetChip(context, 'This year', () {
                    final now = DateTime.now();
                    setState(() {
                      _startDate = DateTime(now.year, 1, 1);
                      _endDate = DateTime(now.year, now.month, now.day);
                    });
                  }),
                  _datePresetChip(context, 'Last 12 months', () {
                    final now = DateTime.now();
                    setState(() {
                      _startDate = DateTime(now.year - 1, now.month, now.day);
                      _endDate = DateTime(now.year, now.month, now.day);
                    });
                  }),
                  _datePresetChip(context, 'Last year', () {
                    final now = DateTime.now();
                    setState(() {
                      _startDate = DateTime(now.year - 1, 1, 1);
                      _endDate = DateTime(now.year - 1, 12, 31);
                    });
                  }),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(context, isStart: true),
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        _startDate != null
                            ? units.formatDate(_startDate)
                            : 'Start Date',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('to'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _selectDate(context, isStart: false),
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        _endDate != null
                            ? units.formatDate(_endDate)
                            : 'End Date',
                      ),
                    ),
                  ),
                ],
              ),
              if (_startDate != null || _endDate != null)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
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
              const SizedBox(height: 24),

              // Dive Type Section
              Text('Dive Type', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Consumer(
                builder: (context, ref, child) {
                  final diveTypesAsync = ref.watch(diveTypesProvider);
                  return diveTypesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, st) => Text('Error: $e'),
                    data: (diveTypes) => DropdownButtonFormField<String?>(
                      initialValue: _diveTypeId,
                      decoration: const InputDecoration(
                        hintText: 'All types',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All types'),
                        ),
                        ...diveTypes.map((type) {
                          return DropdownMenuItem(
                            value: type.id,
                            child: Text(type.name),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() => _diveTypeId = value);
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Site Section
              Text('Dive Site', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              sites.when(
                data: (siteList) => DropdownButtonFormField<String?>(
                  initialValue: _siteId,
                  decoration: const InputDecoration(
                    hintText: 'All sites',
                    prefixIcon: Icon(Icons.location_on),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All sites'),
                    ),
                    ...siteList.map((site) {
                      return DropdownMenuItem(
                        value: site.id,
                        child: Text(site.name),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() => _siteId = value);
                  },
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Error loading sites'),
              ),
              const SizedBox(height: 24),

              // Dive Computer Section
              Text(
                'Dive Computer',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Consumer(
                builder: (context, ref, child) {
                  final computersAsync = ref.watch(allDiveComputersProvider);
                  return computersAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const Text('Error loading computers'),
                    data: (computers) {
                      // Only include computers with serial numbers,
                      // deduplicated by serial.
                      final seen = <String>{};
                      final filterable = computers
                          .where(
                            (c) =>
                                c.serialNumber != null &&
                                seen.add(c.serialNumber!),
                          )
                          .toList();
                      if (filterable.isEmpty) {
                        return Text(
                          'No dive computers registered',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        );
                      }
                      // Reset to null if the saved serial is not in the list.
                      final validSerial =
                          filterable.any(
                            (c) => c.serialNumber == _computerSerial,
                          )
                          ? _computerSerial
                          : null;
                      if (validSerial != _computerSerial) {
                        _computerSerial = validSerial;
                      }
                      return DropdownButtonFormField<String?>(
                        initialValue: validSerial,
                        decoration: const InputDecoration(
                          hintText: 'All computers',
                          prefixIcon: Icon(Icons.watch),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All computers'),
                          ),
                          ...filterable.map(
                            (c) => DropdownMenuItem(
                              value: c.serialNumber,
                              child: Text(c.displayName),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _computerSerial = value);
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),

              // Depth Range Section
              Text(
                'Depth Range (meters)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
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
                      onChanged: (value) {
                        _minDepth = double.tryParse(value);
                      },
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
                      onChanged: (value) {
                        _maxDepth = double.tryParse(value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Favorites Section
              SwitchListTile(
                title: const Text('Favorites Only'),
                subtitle: const Text('Show only favorite dives'),
                secondary: Icon(
                  Icons.favorite,
                  color: _favoritesOnly ? Colors.red : null,
                ),
                value: _favoritesOnly,
                onChanged: (value) {
                  setState(() => _favoritesOnly = value);
                },
              ),
              const SizedBox(height: 24),

              // Tags Section
              Text('Tags', style: Theme.of(context).textTheme.titleMedium),
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
                              color: isSelected
                                  ? tag.color
                                  : Colors.grey.shade300,
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
              const SizedBox(height: 24),

              // Buddy Name Filter Section
              Text('Buddy', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _buddyNameController,
                decoration: const InputDecoration(
                  labelText: 'Buddy Name',
                  hintText: 'Search by buddy name',
                  prefixIcon: Icon(Icons.person),
                ),
                onChanged: (value) {
                  _buddyNameFilter = value.isEmpty ? null : value;
                },
              ),
              const SizedBox(height: 24),

              // Gas Mix (O2%) Filter Section
              Text(
                'Gas Mix (O₂%)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
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
                ],
              ),
              const SizedBox(height: 24),

              // Rating Filter Section
              Text(
                'Minimum Rating',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(5, (index) {
                  final rating = index + 1;
                  final isSelected =
                      _minRating != null && rating <= _minRating!;
                  return IconButton(
                    icon: Icon(
                      isSelected ? Icons.star : Icons.star_border,
                      color: isSelected ? Colors.amber : null,
                      size: 32,
                    ),
                    tooltip: '$rating star${rating > 1 ? 's' : ''}',
                    onPressed: () {
                      setState(() {
                        if (_minRating == rating) {
                          _minRating = null; // Tap same star to clear
                        } else {
                          _minRating = rating;
                        }
                      });
                    },
                  );
                }),
              ),
              if (_minRating != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => setState(() => _minRating = null),
                    child: const Text('Clear rating filter'),
                  ),
                ),
              const SizedBox(height: 24),

              // Duration Range Filter Section
              Text(
                'Duration (minutes)',
                style: Theme.of(context).textTheme.titleMedium,
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
                      onChanged: (value) {
                        _minDurationMinutes = int.tryParse(value);
                      },
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
                      onChanged: (value) {
                        _maxDurationMinutes = int.tryParse(value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.ref.read(widget.filterProvider.notifier).state =
                            const DiveFilterState();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Clear All'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _applyFilters,
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _datePresetChip(
    BuildContext context,
    String label,
    VoidCallback onTap,
  ) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _selectDate(
    BuildContext context, {
    required bool isStart,
  }) async {
    final initialDate = isStart ? _startDate : _endDate;
    final firstDate = DateTime(1950);
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

  void _applyFilters() {
    widget.ref.read(widget.filterProvider.notifier).state = DiveFilterState(
      startDate: _startDate,
      endDate: _endDate,
      diveTypeId: _diveTypeId,
      siteId: _siteId,
      minDepth: _minDepth,
      maxDepth: _maxDepth,
      favoritesOnly: _favoritesOnly ? true : null,
      tagIds: _selectedTagIds,
      // v1.5 filters
      buddyNameFilter: _buddyNameFilter,
      minO2Percent: _minO2Percent,
      maxO2Percent: _maxO2Percent,
      minRating: _minRating,
      minBottomTimeMinutes: _minDurationMinutes,
      maxBottomTimeMinutes: _maxDurationMinutes,
      computerSerial: _computerSerial,
    );
    Navigator.of(context).pop();
  }
}
