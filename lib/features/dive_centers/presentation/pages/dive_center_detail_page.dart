import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';

class DiveCenterDetailPage extends ConsumerStatefulWidget {
  final String centerId;
  final bool embedded;
  final VoidCallback? onDeleted;

  const DiveCenterDetailPage({
    super.key,
    required this.centerId,
    this.embedded = false,
    this.onDeleted,
  });

  @override
  ConsumerState<DiveCenterDetailPage> createState() =>
      _DiveCenterDetailPageState();
}

class _DiveCenterDetailPageState extends ConsumerState<DiveCenterDetailPage> {
  bool _hasRedirected = false;

  @override
  Widget build(BuildContext context) {
    // Desktop redirect: If accessed directly (not embedded), redirect to master-detail view
    if (!widget.embedded &&
        !_hasRedirected &&
        ResponsiveBreakpoints.isMasterDetail(context)) {
      _hasRedirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/dive-centers?selected=${widget.centerId}');
        }
      });
    }

    final centerAsync = ref.watch(diveCenterByIdProvider(widget.centerId));

    return centerAsync.when(
      loading: () => widget.embedded
          ? const Center(child: CircularProgressIndicator())
          : Scaffold(
              appBar: AppBar(),
              body: const Center(child: CircularProgressIndicator()),
            ),
      error: (error, stack) => widget.embedded
          ? Center(child: Text('Error: $error'))
          : Scaffold(
              appBar: AppBar(),
              body: Center(child: Text('Error: $error')),
            ),
      data: (center) {
        if (center == null) {
          return widget.embedded
              ? const Center(child: Text('Dive center not found'))
              : Scaffold(
                  appBar: AppBar(),
                  body: const Center(child: Text('Dive center not found')),
                );
        }

        final body = SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (center.hasCoordinates) _MapSection(center: center),
              _HeaderSection(center: center),
              const Divider(height: 32),
              _ContactSection(center: center),
              if (center.notes.isNotEmpty) ...[
                const Divider(height: 32),
                _NotesSection(notes: center.notes),
              ],
              const Divider(height: 32),
              _DivesSection(centerId: widget.centerId),
              const SizedBox(height: 32),
            ],
          ),
        );

        if (widget.embedded) {
          return Column(
            children: [
              _buildEmbeddedHeader(context, center),
              Expanded(child: body),
            ],
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(center.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit dive center',
                onPressed: () =>
                    context.push('/dive-centers/${widget.centerId}/edit'),
              ),
              _buildMoreMenu(context, center),
            ],
          ),
          body: body,
        );
      },
    );
  }

  Widget _buildEmbeddedHeader(BuildContext context, DiveCenter center) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.store, color: colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  center.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (center.fullLocationString != null)
                  Text(
                    center.fullLocationString!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (center.rating != null) ...[
            Icon(Icons.star, size: 16, color: Colors.amber.shade700),
            const SizedBox(width: 4),
            Text(
              center.rating!.toStringAsFixed(1),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () {
              final state = GoRouterState.of(context);
              final currentPath = state.uri.path;
              context.go('$currentPath?selected=${widget.centerId}&mode=edit');
            },
            tooltip: 'Edit',
          ),
          _buildMoreMenu(context, center),
        ],
      ),
    );
  }

  Widget _buildMoreMenu(BuildContext context, DiveCenter center) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        if (value == 'delete') {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Dive Center'),
              content: Text(
                'Are you sure you want to delete "${center.name}"?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );

          if (confirmed == true && context.mounted) {
            await ref
                .read(diveCenterListNotifierProvider.notifier)
                .deleteDiveCenter(widget.centerId);
            if (context.mounted) {
              if (widget.embedded) {
                widget.onDeleted?.call();
              } else {
                context.pop();
              }
            }
          }
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final DiveCenter center;

  const _HeaderSection({required this.center});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.store,
                  size: 32,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      center.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (center.rating != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (index) => Icon(
                              index < center.rating!.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 20,
                              color: Colors.amber.shade700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            center.rating!.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (center.displayLocation != null) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    center.displayLocation!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ],
          if (center.hasStreetAddress) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.home_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    center.formattedAddress ?? '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
          if (center.affiliations.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: center.affiliations.map((affiliation) {
                return Chip(
                  label: Text(affiliation),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  final DiveCenter center;

  const _ContactSection({required this.center});

  @override
  Widget build(BuildContext context) {
    final hasContact =
        center.phone != null || center.email != null || center.website != null;

    if (!hasContact) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contact', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (center.phone != null)
            _ContactTile(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: center.phone!,
              onTap: () => _launchPhone(center.phone!),
              onLongPress: () => _copyToClipboard(context, center.phone!),
            ),
          if (center.email != null)
            _ContactTile(
              icon: Icons.email_outlined,
              label: 'Email',
              value: center.email!,
              onTap: () => _launchEmail(center.email!),
              onLongPress: () => _copyToClipboard(context, center.email!),
            ),
          if (center.website != null)
            _ContactTile(
              icon: Icons.language_outlined,
              label: 'Website',
              value: center.website!,
              onTap: () => _launchWebsite(center.website!),
              onLongPress: () => _copyToClipboard(context, center.website!),
            ),
        ],
      ),
    );
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWebsite(String website) async {
    var url = website;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ContactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $value',
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              ExcludeSemantics(
                child: Icon(
                  Icons.chevron_right,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotesSection extends StatelessWidget {
  final String notes;

  const _NotesSection({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(notes, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _MapSection extends StatelessWidget {
  final DiveCenter center;

  const _MapSection({required this.center});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final centerLocation = LatLng(center.latitude!, center.longitude!);

    return Card(
      margin: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 200,
        child: Stack(
          children: [
            FlutterMap(
              key: ValueKey('${center.latitude}_${center.longitude}'),
              options: MapOptions(
                initialCenter: centerLocation,
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
                  tileProvider: TileCacheService.instance.isInitialized
                      ? TileCacheService.instance.getTileProvider()
                      : null,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: centerLocation,
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
                            Icons.store,
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
            Positioned(
              right: 8,
              top: 8,
              child: Material(
                color: colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(4),
                child: Semantics(
                  button: true,
                  label: 'View fullscreen map',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => _showFullscreenMap(context),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.fullscreen,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullscreenMap(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final centerLocation = LatLng(center.latitude!, center.longitude!);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(center.name)),
          body: FlutterMap(
            options: MapOptions(
              initialCenter: centerLocation,
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
                tileProvider: TileCacheService.instance.isInitialized
                    ? TileCacheService.instance.getTileProvider()
                    : null,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: centerLocation,
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
                          Icons.store,
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
      ),
    );
  }
}

class _DivesSection extends ConsumerWidget {
  final String centerId;

  const _DivesSection({required this.centerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final diveCountAsync = ref.watch(diveCenterDiveCountProvider(centerId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: diveCountAsync.when(
        data: (diveCount) {
          return Card(
            clipBehavior: Clip.antiAlias,
            child: Semantics(
              button: true,
              label: 'View dives with this center',
              child: InkWell(
                onTap: diveCount > 0
                    ? () {
                        // Set the filter to this dive center and navigate to dive list
                        ref.read(diveFilterProvider.notifier).state =
                            DiveFilterState(diveCenterId: centerId);
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
                              'Dives with this Center',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              diveCount == 0
                                  ? 'No dives logged yet'
                                  : diveCount == 1
                                  ? '1 dive logged'
                                  : '$diveCount dives logged',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      if (diveCount > 0)
                        ExcludeSemantics(
                          child: Icon(
                            Icons.chevron_right,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
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
        error: (e, st) => const SizedBox.shrink(),
      ),
    );
  }
}
