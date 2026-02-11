import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

/// Bottom sheet for filtering dive sites.
///
/// Uses local state to allow preview before applying.
/// Filters are applied when "Apply Filters" is tapped.
class SiteFilterSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const SiteFilterSheet({super.key, required this.ref});

  @override
  ConsumerState<SiteFilterSheet> createState() => _SiteFilterSheetState();
}

class _SiteFilterSheetState extends ConsumerState<SiteFilterSheet> {
  // Local state mirrors SiteFilterState fields
  String? _country;
  String? _region;
  SiteDifficulty? _difficulty;
  double? _minDepth;
  double? _maxDepth;
  double? _minRating;
  bool? _hasCoordinates;
  bool? _hasDives;

  // Controllers for text fields
  late TextEditingController _countryController;
  late TextEditingController _regionController;
  late TextEditingController _minDepthController;
  late TextEditingController _maxDepthController;

  @override
  void initState() {
    super.initState();
    // Initialize from current filter state
    final filter = widget.ref.read(siteFilterProvider);
    _country = filter.country;
    _region = filter.region;
    _difficulty = filter.difficulty;
    _minDepth = filter.minDepth;
    _maxDepth = filter.maxDepth;
    _minRating = filter.minRating;
    _hasCoordinates = filter.hasCoordinates;
    _hasDives = filter.hasDives;

    _countryController = TextEditingController(text: _country ?? '');
    _regionController = TextEditingController(text: _region ?? '');
    _minDepthController = TextEditingController(
      text: _minDepth?.toStringAsFixed(0) ?? '',
    );
    _maxDepthController = TextEditingController(
      text: _maxDepth?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _countryController.dispose();
    _regionController.dispose();
    _minDepthController.dispose();
    _maxDepthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.diveSites_filter_title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton(
                      onPressed: _clearAll,
                      child: Text(context.l10n.diveSites_filter_clearAll),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Filter content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildLocationSection(),
                    const SizedBox(height: 24),
                    _buildDifficultySection(),
                    const SizedBox(height: 24),
                    _buildDepthSection(),
                    const SizedBox(height: 24),
                    _buildRatingSection(),
                    const SizedBox(height: 24),
                    _buildOptionsSection(),
                    const SizedBox(height: 80), // Space for buttons
                  ],
                ),
              ),
              // Bottom buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.l10n.diveSites_filter_cancel),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: _applyFilters,
                        child: Text(context.l10n.diveSites_filter_apply),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveSites_filter_section_location,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _countryController,
          decoration: InputDecoration(
            labelText: context.l10n.diveSites_filter_country_label,
            hintText: context.l10n.diveSites_filter_country_hint,
            prefixIcon: const Icon(Icons.public),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _country = value.isEmpty ? null : value;
            });
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _regionController,
          decoration: InputDecoration(
            labelText: context.l10n.diveSites_filter_region_label,
            hintText: context.l10n.diveSites_filter_region_hint,
            prefixIcon: const Icon(Icons.place),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _region = value.isEmpty ? null : value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildDifficultySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveSites_filter_section_difficulty,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: Text(context.l10n.diveSites_filter_difficulty_any),
              selected: _difficulty == null,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _difficulty = null);
                }
              },
            ),
            ...SiteDifficulty.values.map((difficulty) {
              return FilterChip(
                label: Text(difficulty.displayName),
                selected: _difficulty == difficulty,
                onSelected: (selected) {
                  setState(() {
                    _difficulty = selected ? difficulty : null;
                  });
                },
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildDepthSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveSites_filter_section_depthRange,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _minDepthController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.diveSites_filter_depth_min_label,
                  suffixText: 'm',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _minDepth = double.tryParse(value);
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(context.l10n.diveSites_filter_depth_separator),
            ),
            Expanded(
              child: TextField(
                controller: _maxDepthController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.diveSites_filter_depth_max_label,
                  suffixText: 'm',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _maxDepth = double.tryParse(value);
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveSites_filter_section_minRating,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (int i = 1; i <= 5; i++)
              IconButton(
                icon: Icon(
                  i <= (_minRating ?? 0) ? Icons.star : Icons.star_border,
                  color: Colors.amber.shade600,
                ),
                tooltip: context.l10n.diveSites_edit_rating_starTooltip(i),
                onPressed: () {
                  setState(() {
                    // Tapping the same star clears the filter
                    if (_minRating == i.toDouble()) {
                      _minRating = null;
                    } else {
                      _minRating = i.toDouble();
                    }
                  });
                },
              ),
            const SizedBox(width: 8),
            if (_minRating != null)
              Text(
                context.l10n.diveSites_filter_rating_starsPlus(
                  _minRating!.toInt(),
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildOptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveSites_filter_section_options,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: Text(
            context.l10n.diveSites_filter_option_hasCoordinates_title,
          ),
          subtitle: Text(
            context.l10n.diveSites_filter_option_hasCoordinates_subtitle,
          ),
          value: _hasCoordinates == true,
          onChanged: (value) {
            setState(() {
              _hasCoordinates = value ? true : null;
            });
          },
        ),
        SwitchListTile(
          title: Text(context.l10n.diveSites_filter_option_hasDives_title),
          subtitle: Text(
            context.l10n.diveSites_filter_option_hasDives_subtitle,
          ),
          value: _hasDives == true,
          onChanged: (value) {
            setState(() {
              _hasDives = value ? true : null;
            });
          },
        ),
      ],
    );
  }

  void _clearAll() {
    setState(() {
      _country = null;
      _region = null;
      _difficulty = null;
      _minDepth = null;
      _maxDepth = null;
      _minRating = null;
      _hasCoordinates = null;
      _hasDives = null;

      _countryController.clear();
      _regionController.clear();
      _minDepthController.clear();
      _maxDepthController.clear();
    });
  }

  void _applyFilters() {
    widget.ref.read(siteFilterProvider.notifier).state = SiteFilterState(
      country: _country,
      region: _region,
      difficulty: _difficulty,
      minDepth: _minDepth,
      maxDepth: _maxDepth,
      minRating: _minRating,
      hasCoordinates: _hasCoordinates,
      hasDives: _hasDives,
    );
    Navigator.of(context).pop();
  }
}
