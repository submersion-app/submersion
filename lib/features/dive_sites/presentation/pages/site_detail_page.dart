import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../dive_log/presentation/providers/dive_providers.dart';
import '../../domain/entities/dive_site.dart';
import '../providers/site_providers.dart';

class SiteDetailPage extends ConsumerWidget {
  final String siteId;

  const SiteDetailPage({
    super.key,
    required this.siteId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final siteAsync = ref.watch(siteProvider(siteId));

    return siteAsync.when(
      data: (site) {
        if (site == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Site Not Found')),
            body: const Center(child: Text('This site no longer exists.')),
          );
        }
        return _buildContent(context, ref, site);
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

  Widget _buildContent(BuildContext context, WidgetRef ref, DiveSite site) {
    return Scaffold(
      appBar: AppBar(
        title: Text(site.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/sites/$siteId/edit'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map Section (if coordinates exist)
            if (site.hasCoordinates) ...[
              _buildMapSection(context, site),
              const SizedBox(height: 16),
            ],

            // Basic Info Section (Name + Location String)
            _buildBasicInfoSection(context, site),
            const SizedBox(height: 16),

            // Dive Count Section
            _buildDiveCountSection(context, ref, site),
            const SizedBox(height: 16),

            // Description Section
            _buildDescriptionSection(context, site),
            const SizedBox(height: 16),

            // Location Details Section
            _buildLocationSection(context, site),
            const SizedBox(height: 16),

            // Max Depth Section
            _buildMaxDepthSection(context, site),
            const SizedBox(height: 16),

            // Rating Section
            _buildRatingSection(context, site),
            const SizedBox(height: 16),

            // Notes Section
            _buildNotesSection(context, site),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection(BuildContext context, DiveSite site) {
    final colorScheme = Theme.of(context).colorScheme;
    final siteLocation = LatLng(site.location!.latitude, site.location!.longitude);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 200,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: siteLocation,
            initialZoom: 14.0,
            minZoom: 2.0,
            maxZoom: 18.0,
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
            MarkerLayer(
              markers: [
                Marker(
                  point: siteLocation,
                  width: 50,
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.onPrimary,
                        width: 2,
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
                        Icons.scuba_diving,
                        size: 24,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection(BuildContext context, DiveSite site) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.location_on,
                color: colorScheme.onPrimaryContainer,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    site.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (site.locationString.isNotEmpty)
                    Text(
                      site.locationString,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiveCountSection(BuildContext context, WidgetRef ref, DiveSite site) {
    final colorScheme = Theme.of(context).colorScheme;
    final diveCountAsync = ref.watch(siteDiveCountProvider(site.id));

    return diveCountAsync.when(
      data: (diveCount) {
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: diveCount > 0
                ? () {
                    // Set the filter to this site and navigate to dive list
                    ref.read(diveFilterProvider.notifier).state = DiveFilterState(
                      siteId: site.id,
                    );
                    context.go('/dives');
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(
                      Icons.scuba_diving,
                      color: colorScheme.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dives at this Site',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          diveCount == 0
                              ? 'No dives logged yet'
                              : diveCount == 1
                                  ? '1 dive logged'
                                  : '$diveCount dives logged',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (diveCount > 0)
                    Icon(
                      Icons.chevron_right,
                      color: colorScheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(
                  Icons.scuba_diving,
                  color: colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: SizedBox(
                  height: 20,
                  width: 100,
                  child: LinearProgressIndicator(),
                ),
              ),
            ],
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildDescriptionSection(BuildContext context, DiveSite site) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasDescription = site.description.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              hasDescription ? site.description : 'No description',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: hasDescription ? null : colorScheme.onSurfaceVariant,
                    fontStyle: hasDescription ? null : FontStyle.italic,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection(BuildContext context, DiveSite site) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.map,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Location',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              context,
              Icons.flag,
              'Country',
              site.country?.isNotEmpty == true ? site.country! : 'Not set',
              isEmpty: site.country?.isNotEmpty != true,
            ),
            _buildDetailRow(
              context,
              Icons.place,
              'Region',
              site.region?.isNotEmpty == true ? site.region! : 'Not set',
              isEmpty: site.region?.isNotEmpty != true,
            ),
            _buildDetailRow(
              context,
              Icons.gps_fixed,
              'GPS Coordinates',
              site.hasCoordinates ? site.location.toString() : 'Not set',
              isEmpty: !site.hasCoordinates,
              onTap: site.hasCoordinates
                  ? () {
                      Clipboard.setData(ClipboardData(text: site.location.toString()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Coordinates copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    bool isEmpty = false,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isEmpty ? colorScheme.onSurfaceVariant : null,
                        fontStyle: isEmpty ? FontStyle.italic : null,
                      ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.copy, size: 16, color: colorScheme.onSurfaceVariant),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      );
    }

    return content;
  }

  Widget _buildMaxDepthSection(BuildContext context, DiveSite site) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasMaxDepth = site.maxDepth != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.arrow_downward,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Max Depth',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  Text(
                    hasMaxDepth ? '${site.maxDepth!.toStringAsFixed(1)} m' : 'Not set',
                    style: hasMaxDepth
                        ? Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            )
                        : Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                  ),
                  if (hasMaxDepth)
                    Text(
                      '${(site.maxDepth! * 3.28084).toStringAsFixed(0)} ft',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSection(BuildContext context, DiveSite site) {
    final colorScheme = Theme.of(context).colorScheme;
    final rating = site.rating ?? 0;
    final hasRating = rating > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.star,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Rating',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    index < rating ? Icons.star : Icons.star_border,
                    color: hasRating ? Colors.amber : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    size: 36,
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                hasRating ? '${rating.toStringAsFixed(1)} out of 5' : 'Not rated',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: hasRating ? null : FontStyle.italic,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context, DiveSite site) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasNotes = site.notes.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notes,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Notes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              hasNotes ? site.notes : 'No notes',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: hasNotes ? null : colorScheme.onSurfaceVariant,
                    fontStyle: hasNotes ? null : FontStyle.italic,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
