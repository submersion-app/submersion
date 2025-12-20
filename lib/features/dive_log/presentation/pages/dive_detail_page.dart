import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/utils/unit_formatter.dart';
import '../../../buddies/domain/entities/buddy.dart';
import '../../../buddies/presentation/providers/buddy_providers.dart';
import '../../../marine_life/domain/entities/species.dart';
import '../../../marine_life/presentation/providers/species_providers.dart';
import '../../../settings/presentation/providers/export_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../data/services/profile_analysis_service.dart';
import '../../domain/entities/dive.dart';
import '../providers/dive_providers.dart';
import '../providers/profile_analysis_provider.dart';
import '../widgets/deco_info_panel.dart';
import '../widgets/dive_profile_chart.dart';
import '../widgets/o2_toxicity_card.dart';

class DiveDetailPage extends ConsumerStatefulWidget {
  final String diveId;

  const DiveDetailPage({
    super.key,
    required this.diveId,
  });

  @override
  ConsumerState<DiveDetailPage> createState() => _DiveDetailPageState();
}

class _DiveDetailPageState extends ConsumerState<DiveDetailPage> {
  /// Currently selected point index on the profile timeline
  int? _selectedPointIndex;

  String get diveId => widget.diveId;

  @override
  Widget build(BuildContext context) {
    final diveAsync = ref.watch(diveProvider(diveId));

    return diveAsync.when(
      data: (dive) {
        if (dive == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Dive Details')),
            body: const Center(child: Text('Dive not found')),
          );
        }
        return _buildContent(context, ref, dive);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Dive Details')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Dive Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text('Error loading dive', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(error.toString()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, Dive dive) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dive Details'),
        actions: [
          IconButton(
            icon: Icon(
              dive.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: dive.isFavorite ? Colors.red : null,
            ),
            tooltip: dive.isFavorite ? 'Remove from favorites' : 'Add to favorites',
            onPressed: () {
              ref.read(diveListNotifierProvider.notifier).toggleFavorite(diveId);
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.go('/dives/$diveId/edit'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _showExportOptions(context, ref, dive);
                  break;
                case 'delete':
                  _showDeleteConfirmation(context, ref);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Export'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(context, ref, dive, units),
            const SizedBox(height: 24),
            if (dive.profile.isNotEmpty) ...[
              _buildProfileSection(context, ref, dive),
              const SizedBox(height: 24),
              _buildDecoSection(context, ref, dive),
              const SizedBox(height: 24),
              _buildO2ToxicitySection(context, ref, dive),
              const SizedBox(height: 24),
            ],
            _buildDetailsSection(context, ref, dive, units),
            const SizedBox(height: 24),
            _buildConditionsSection(context, dive),
            const SizedBox(height: 24),
            _buildWeightSection(context, dive, units),
            const SizedBox(height: 24),
            _buildTagsSection(context, dive),
            const SizedBox(height: 24),
            _buildBuddiesSection(context, ref),
            const SizedBox(height: 24),
            if (dive.tanks.isNotEmpty) ...[
              _buildTanksSection(context, dive, units),
              const SizedBox(height: 24),
            ],
            _buildSightingsSection(context, ref),
            const SizedBox(height: 24),
            _buildNotesSection(context, dive),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context, WidgetRef ref, Dive dive, UnitFormatter units) {
    final hasLocation = dive.site?.location != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasLocation) _buildMiniMap(context, dive),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        '#${dive.diveNumber ?? '-'}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dive.site?.name ?? 'Unknown Site',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'Entry: ${DateFormat('MMM d, y • h:mm a').format(dive.effectiveEntryTime)}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          if (dive.exitTime != null)
                            Text(
                              'Exit: ${DateFormat('h:mm a').format(dive.exitTime!)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                        ],
                      ),
                    ),
                    if (dive.rating != null)
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber.shade600, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            '${dive.rating}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      context,
                      Icons.arrow_downward,
                      units.formatDepth(dive.maxDepth),
                      'Max Depth',
                    ),
                    _buildStatItem(
                      context,
                      Icons.timer,
                      dive.duration != null ? '${dive.duration!.inMinutes} min' : '--',
                      'Bottom Time',
                    ),
                    _buildStatItem(
                      context,
                      Icons.timelapse,
                      _formatRuntime(dive),
                      'Runtime',
                    ),
                    _buildStatItem(
                      context,
                      Icons.thermostat,
                      units.formatTemperature(dive.waterTemp),
                      'Temp',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMap(BuildContext context, Dive dive) {
    final colorScheme = Theme.of(context).colorScheme;
    final site = dive.site!;
    final siteLocation = LatLng(site.location!.latitude, site.location!.longitude);

    return InkWell(
      onTap: () => context.push('/sites/${site.id}'),
      child: SizedBox(
        height: 100,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: siteLocation,
                initialZoom: 12.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.submersion.app',
                  maxZoom: 19,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: siteLocation,
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: colorScheme.onPrimary,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.scuba_diving,
                            size: 16,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.open_in_new,
                      size: 14,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'View Site',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format runtime: use stored value, or calculate from entry/exit times
  String _formatRuntime(Dive dive) {
    if (dive.runtime != null) {
      return '${dive.runtime!.inMinutes} min';
    }
    // Calculate from entry/exit times if available
    if (dive.entryTime != null && dive.exitTime != null) {
      final calculated = dive.exitTime!.difference(dive.entryTime!);
      return '${calculated.inMinutes} min';
    }
    return '--';
  }

  Widget _buildStatItem(BuildContext context, IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildProfileSection(BuildContext context, WidgetRef ref, Dive dive) {
    // Get profile analysis
    final analysis = ref.watch(diveProfileAnalysisProvider(dive));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dive Profile',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Row(
                  children: [
                    Text(
                      '${dive.profile.length} points',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.fullscreen),
                      tooltip: 'View fullscreen',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showFullscreenProfile(context, ref, dive),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            DiveProfileChart(
              profile: dive.profile,
              diveDuration: dive.calculatedDuration,
              maxDepth: dive.maxDepth,
              ceilingCurve: analysis?.ceilingCurve,
              ascentRates: analysis?.ascentRates,
              events: analysis?.events,
              ndlCurve: analysis?.ndlCurve,
              onPointSelected: (point) {
                if (point == null) {
                  setState(() => _selectedPointIndex = null);
                  return;
                }
                // Find the index of this point in the profile
                final index = dive.profile.indexWhere(
                  (p) => p.timestamp == point.timestamp,
                );
                setState(() {
                  _selectedPointIndex = index >= 0 ? index : null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecoSection(BuildContext context, WidgetRef ref, Dive dive) {
    final analysis = ref.watch(diveProfileAnalysisProvider(dive));

    // Don't show if no analysis available
    if (analysis == null || analysis.decoStatuses.isEmpty) {
      return const SizedBox.shrink();
    }

    // Use selected point or default to final status
    final index = _selectedPointIndex != null &&
            _selectedPointIndex! < analysis.decoStatuses.length
        ? _selectedPointIndex!
        : analysis.decoStatuses.length - 1;
    final status = analysis.decoStatuses[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedPointIndex != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.timeline,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'At ${_formatTimestamp(dive.profile[_selectedPointIndex!].timestamp)}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() => _selectedPointIndex = null),
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Show end'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        DecoInfoPanel(
          status: status,
          showTissueChart: true,
          showDecoStops: true,
        ),
      ],
    );
  }

  String _formatTimestamp(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildO2ToxicitySection(BuildContext context, WidgetRef ref, Dive dive) {
    final analysis = ref.watch(diveProfileAnalysisProvider(dive));

    // Don't show if no analysis available
    if (analysis == null) {
      return const SizedBox.shrink();
    }

    // Show ppO2 at selected point if available
    final selectedPpO2 = _selectedPointIndex != null &&
            _selectedPointIndex! < analysis.ppO2Curve.length
        ? analysis.ppO2Curve[_selectedPointIndex!]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedPpO2 != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.air,
                      size: 20,
                      color: _getPpO2Color(selectedPpO2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'ppO₂ at selected point:',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${selectedPpO2.toStringAsFixed(2)} bar',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _getPpO2Color(selectedPpO2),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        O2ToxicityCard(
          exposure: analysis.o2Exposure,
          showDetails: true,
        ),
      ],
    );
  }

  Color _getPpO2Color(double ppO2) {
    if (ppO2 >= 1.6) return Colors.red;
    if (ppO2 >= 1.4) return Colors.orange;
    return Colors.green;
  }

  void _showFullscreenProfile(BuildContext context, WidgetRef ref, Dive dive) {
    final analysis = ref.read(diveProfileAnalysisProvider(dive));
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullscreenProfilePage(dive: dive, analysis: analysis),
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context, WidgetRef ref, Dive dive, UnitFormatter units) {
    final surfaceIntervalAsync = ref.watch(surfaceIntervalProvider(diveId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            _buildDetailRow(context, 'Dive Type', dive.diveTypeName),
            if (dive.trip != null)
              _buildTripRow(context, dive),
            if (dive.diveCenter != null)
              _buildDiveCenterRow(context, dive),
            if (dive.visibility != null)
              _buildDetailRow(context, 'Visibility', dive.visibility!.displayName),
            if (dive.avgDepth != null)
              _buildDetailRow(context, 'Avg Depth', units.formatDepth(dive.avgDepth)),
            if (dive.airTemp != null)
              _buildDetailRow(context, 'Air Temp', units.formatTemperature(dive.airTemp)),
            if (dive.waterType != null)
              _buildDetailRow(context, 'Water Type', dive.waterType!.displayName),
            if (dive.buddy != null && dive.buddy!.isNotEmpty)
              _buildDetailRow(context, 'Buddy', dive.buddy!),
            if (dive.diveMaster != null && dive.diveMaster!.isNotEmpty)
              _buildDetailRow(context, 'Dive Master', dive.diveMaster!),
            if (dive.sac != null)
              _buildDetailRow(context, 'SAC Rate', '${units.convertPressure(dive.sac!).toStringAsFixed(1)} ${units.pressureSymbol}/min'),
            surfaceIntervalAsync.when(
              data: (interval) {
                if (interval == null) return const SizedBox.shrink();
                final hours = interval.inHours;
                final minutes = interval.inMinutes % 60;
                final intervalText = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
                return _buildDetailRow(context, 'Surface Interval', intervalText);
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionsSection(BuildContext context, Dive dive) {
    final hasConditions = dive.currentDirection != null ||
        dive.currentStrength != null ||
        dive.swellHeight != null ||
        dive.entryMethod != null ||
        dive.exitMethod != null;

    if (!hasConditions) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conditions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            if (dive.currentDirection != null)
              _buildDetailRow(context, 'Current Direction', dive.currentDirection!.displayName),
            if (dive.currentStrength != null)
              _buildDetailRow(context, 'Current Strength', dive.currentStrength!.displayName),
            if (dive.swellHeight != null)
              _buildDetailRow(context, 'Swell Height', '${dive.swellHeight!.toStringAsFixed(1)}m'),
            if (dive.entryMethod != null)
              _buildDetailRow(context, 'Entry Method', dive.entryMethod!.displayName),
            if (dive.exitMethod != null)
              _buildDetailRow(context, 'Exit Method', dive.exitMethod!.displayName),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightSection(BuildContext context, Dive dive, UnitFormatter units) {
    // Combine new weights with legacy single weight for unified display
    final hasWeights = dive.weights.isNotEmpty;
    final hasLegacyWeight = dive.weightAmount != null && dive.weightAmount! > 0;

    if (!hasWeights && !hasLegacyWeight) return const SizedBox.shrink();

    // Build list of weights to display (new format + legacy if present)
    final displayWeights = <_WeightDisplay>[];
    
    // Add new weights
    for (final weight in dive.weights) {
      displayWeights.add(_WeightDisplay(
        type: weight.weightType.displayName,
        amount: weight.amountKg,
      ),);
    }
    
    // Add legacy weight in same format if no new weights exist
    if (!hasWeights && hasLegacyWeight) {
      displayWeights.add(_WeightDisplay(
        type: dive.weightType?.displayName ?? 'Weight',
        amount: dive.weightAmount!,
      ),);
    }

    final totalWeight = displayWeights.fold(0.0, (sum, w) => sum + w.amount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Weight',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Total: ${units.formatWeight(totalWeight)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...displayWeights.map((weight) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(weight.type),
                  Text(units.formatWeight(weight.amount)),
                ],
              ),
            ),),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection(BuildContext context, Dive dive) {
    if (dive.tags.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tags',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${dive.tags.length} ${dive.tags.length == 1 ? 'tag' : 'tags'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const Divider(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dive.tags.map((tag) => Chip(
                    label: Text(tag.name),
                    backgroundColor: tag.color.withValues(alpha: 0.2),
                    side: BorderSide(color: tag.color),
                    labelStyle: TextStyle(color: tag.color),
                    visualDensity: VisualDensity.compact,
                  ),).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildTripRow(BuildContext context, Dive dive) {
    final trip = dive.trip!;
    return InkWell(
      onTap: () => context.push('/trips/${trip.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Trip',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          trip.name,
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (trip.subtitle != null)
                          Text(
                            trip.subtitle!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiveCenterRow(BuildContext context, Dive dive) {
    return InkWell(
      onTap: () => context.push('/dive-centers/${dive.diveCenter!.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Dive Center',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            Row(
              children: [
                Text(dive.diveCenter!.name, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuddiesSection(BuildContext context, WidgetRef ref) {
    final buddiesAsync = ref.watch(buddiesForDiveProvider(diveId));

    return buddiesAsync.when(
      data: (buddies) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Buddies',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (buddies.isNotEmpty)
                      Text(
                        '${buddies.length} ${buddies.length == 1 ? 'buddy' : 'buddies'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                  ],
                ),
                const Divider(),
                if (buddies.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Solo dive or no buddies recorded',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  )
                else
                  ...buddies.map((bwr) => _buildBuddyTile(context, bwr)),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildBuddyTile(BuildContext context, BuddyWithRole bwr) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          bwr.buddy.initials,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(bwr.buddy.name),
      subtitle: Text(bwr.role.displayName),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => context.push('/buddies/${bwr.buddy.id}'),
    );
  }

  Widget _buildTanksSection(BuildContext context, Dive dive, UnitFormatter units) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tanks',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            ...dive.tanks.map((tank) {
              final startP = units.formatPressureValue(tank.startPressure?.toDouble());
              final endP = units.formatPressureValue(tank.endPressure?.toDouble());
              final used = tank.pressureUsed != null
                  ? ' (${units.formatPressure(tank.pressureUsed!.toDouble())} used)'
                  : '';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.propane_tank),
                title: Text(tank.gasMix.name),
                subtitle: Text(
                  '$startP ${units.pressureSymbol} → $endP ${units.pressureSymbol}$used',
                ),
                trailing: tank.volume != null 
                    ? Text(units.formatTankVolume(tank.volume, tank.workingPressure, decimals: 1)) 
                    : null,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSightingsSection(BuildContext context, WidgetRef ref) {
    final sightingsAsync = ref.watch(diveSightingsProvider(diveId));

    return sightingsAsync.when(
      data: (sightings) {
        if (sightings.isEmpty) {
          return const SizedBox.shrink(); // Don't show section if no sightings
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Marine Life',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${sightings.length} species',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
                const Divider(),
                ...sightings.map((sighting) => _buildSightingTile(context, sighting)),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSightingTile(BuildContext context, Sighting sighting) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _getCategoryColor(sighting.speciesCategory),
            child: Icon(
              _getCategoryIcon(sighting.speciesCategory),
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sighting.speciesName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                if (sighting.notes.isNotEmpty)
                  Text(
                    sighting.notes,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (sighting.count > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'x${sighting.count}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getCategoryColor(SpeciesCategory? category) {
    switch (category) {
      case SpeciesCategory.fish:
        return Colors.blue;
      case SpeciesCategory.shark:
        return Colors.grey.shade700;
      case SpeciesCategory.ray:
        return Colors.indigo;
      case SpeciesCategory.mammal:
        return Colors.brown;
      case SpeciesCategory.turtle:
        return Colors.green.shade700;
      case SpeciesCategory.invertebrate:
        return Colors.purple;
      case SpeciesCategory.coral:
        return Colors.pink;
      case SpeciesCategory.plant:
        return Colors.green;
      case SpeciesCategory.other:
      case null:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(SpeciesCategory? category) {
    switch (category) {
      case SpeciesCategory.fish:
        return Icons.set_meal;
      case SpeciesCategory.shark:
        return Icons.water;
      case SpeciesCategory.ray:
        return Icons.water;
      case SpeciesCategory.mammal:
        return Icons.pets;
      case SpeciesCategory.turtle:
        return Icons.water;
      case SpeciesCategory.invertebrate:
        return Icons.bug_report;
      case SpeciesCategory.coral:
        return Icons.nature;
      case SpeciesCategory.plant:
        return Icons.eco;
      case SpeciesCategory.other:
      case null:
        return Icons.water;
    }
  }

  Widget _buildNotesSection(BuildContext context, Dive dive) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Divider(),
            Text(
              dive.notes.isNotEmpty ? dive.notes : 'No notes for this dive.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: dive.notes.isEmpty
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : null,
                    fontStyle: dive.notes.isEmpty ? FontStyle.italic : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Dive?'),
        content: const Text(
          'This action cannot be undone. Are you sure you want to delete this dive?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(diveListNotifierProvider.notifier).deleteDive(diveId);
              if (context.mounted) {
                context.go('/dives');
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showExportOptions(BuildContext context, WidgetRef ref, Dive dive) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Export Dive #${dive.diveNumber ?? ""}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF Logbook Entry'),
              subtitle: const Text('Printable dive log page'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleSingleDiveExport(
                  context,
                  ref,
                  () => ref.read(exportServiceProvider).exportDivesToPdf([dive]),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('CSV'),
              subtitle: const Text('Spreadsheet format'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleSingleDiveExport(
                  context,
                  ref,
                  () => ref.read(exportServiceProvider).exportDivesToCsv([dive]),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('UDDF'),
              subtitle: const Text('Universal Dive Data Format'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _handleSingleDiveExport(
                  context,
                  ref,
                  () => ref.read(exportServiceProvider).exportDivesToUddf(
                    [dive],
                    sites: dive.site != null ? [dive.site!] : [],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSingleDiveExport(
    BuildContext context,
    WidgetRef ref,
    Future<String> Function() exportFn,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 24),
            Text('Exporting...'),
          ],
        ),
      ),
    );

    try {
      await exportFn();
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dive exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Fullscreen dive profile page with rotation support
class _FullscreenProfilePage extends StatefulWidget {
  final Dive dive;
  final ProfileAnalysis? analysis;

  const _FullscreenProfilePage({required this.dive, this.analysis});

  @override
  State<_FullscreenProfilePage> createState() => _FullscreenProfilePageState();
}

class _FullscreenProfilePageState extends State<_FullscreenProfilePage> {
  DiveProfilePoint? _selectedPoint;

  @override
  void initState() {
    super.initState();
    // Allow all orientations for fullscreen view
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Reset to portrait only when leaving fullscreen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dive = widget.dive;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: isLandscape
          ? null
          : AppBar(
              title: Text('Dive #${dive.diveNumber ?? "-"} Profile'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.only(
                left: isLandscape ? 48.0 : 16.0,
                right: 16.0,
                top: 16.0,
                bottom: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLandscape)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Dive #${dive.diveNumber ?? "-"} Profile',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  SizedBox(
                    height: isLandscape ? 280 : 350,
                    child: DiveProfileChart(
                      profile: dive.profile,
                      diveDuration: dive.calculatedDuration,
                      maxDepth: dive.maxDepth,
                      ceilingCurve: widget.analysis?.ceilingCurve,
                      ascentRates: widget.analysis?.ascentRates,
                      events: widget.analysis?.events,
                      ndlCurve: widget.analysis?.ndlCurve,
                      onPointSelected: (point) {
                        setState(() => _selectedPoint = point);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMetricsTable(context, compact: isLandscape),
                ],
              ),
            ),
            if (isLandscape)
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsTable(BuildContext context, {bool compact = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final point = _selectedPoint;

    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.touch_app,
                size: compact ? 14 : 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  point == null ? 'Touch chart' : 'Sample Data',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: compact ? 12 : null,
                      ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 12),
          if (point == null)
            Text(
              compact
                  ? 'Tap chart to see sample data'
                  : 'Tap or drag on the dive profile to see detailed metrics for each sample point.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            )
          else if (compact)
            _buildCompactMetrics(context, point)
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1),
              },
              children: [
                _buildTableRow(
                  context,
                  'Time',
                  _formatTime(point.timestamp),
                  'Depth',
                  '${point.depth.toStringAsFixed(1)}m',
                ),
                if (point.temperature != null || point.pressure != null)
                  _buildTableRow(
                    context,
                    point.temperature != null ? 'Temperature' : '',
                    point.temperature != null ? '${point.temperature!.toStringAsFixed(1)}°C' : '',
                    point.pressure != null ? 'Pressure' : '',
                    point.pressure != null ? '${point.pressure!.toInt()} bar' : '',
                  ),
                if (point.heartRate != null)
                  _buildTableRow(
                    context,
                    'Heart Rate',
                    '${point.heartRate!} bpm',
                    '',
                    '',
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCompactMetrics(BuildContext context, DiveProfilePoint point) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCompactMetricRow(context, 'Time', _formatTime(point.timestamp)),
        _buildCompactMetricRow(context, 'Depth', '${point.depth.toStringAsFixed(1)}m'),
        if (point.temperature != null)
          _buildCompactMetricRow(context, 'Temp', '${point.temperature!.toStringAsFixed(1)}°C'),
        if (point.pressure != null)
          _buildCompactMetricRow(context, 'Pressure', '${point.pressure!.toInt()} bar'),
        if (point.heartRate != null)
          _buildCompactMetricRow(context, 'HR', '${point.heartRate!} bpm'),
      ],
    );
  }

  Widget _buildCompactMetricRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  TableRow _buildTableRow(
    BuildContext context,
    String label1,
    String value1,
    String label2,
    String value2,
  ) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: label1.isNotEmpty
              ? Row(
                  children: [
                    Text(
                      '$label1: ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    Text(
                      value1,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: label2.isNotEmpty
              ? Row(
                  children: [
                    Text(
                      '$label2: ',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    Text(
                      value2,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}

/// Helper class for unified weight display
class _WeightDisplay {
  final String type;
  final double amount;

  const _WeightDisplay({required this.type, required this.amount});
}
