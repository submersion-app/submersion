import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../shared/widgets/master_detail/responsive_breakpoints.dart';
import '../../data/repositories/buddy_repository.dart';
import '../../domain/entities/buddy.dart';
import '../providers/buddy_providers.dart';

class BuddyDetailPage extends ConsumerStatefulWidget {
  final String buddyId;

  /// When true, renders without Scaffold wrapper for use in master-detail layout.
  final bool embedded;

  /// Callback when delete completes (used in embedded mode).
  final VoidCallback? onDeleted;

  const BuddyDetailPage({
    super.key,
    required this.buddyId,
    this.embedded = false,
    this.onDeleted,
  });

  @override
  ConsumerState<BuddyDetailPage> createState() => _BuddyDetailPageState();
}

class _BuddyDetailPageState extends ConsumerState<BuddyDetailPage> {
  bool _hasRedirected = false;

  @override
  Widget build(BuildContext context) {
    // Desktop redirect: if not embedded and on desktop, redirect to master-detail view
    if (!widget.embedded &&
        !_hasRedirected &&
        ResponsiveBreakpoints.isDesktop(context)) {
      _hasRedirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/buddies?selected=${widget.buddyId}');
        }
      });
    }

    final buddyAsync = ref.watch(buddyByIdProvider(widget.buddyId));

    return buddyAsync.when(
      data: (buddy) {
        if (buddy == null) {
          if (widget.embedded) {
            return const Center(child: Text('Buddy not found'));
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Buddy')),
            body: const Center(child: Text('Buddy not found')),
          );
        }
        return _BuddyDetailContent(
          buddy: buddy,
          embedded: widget.embedded,
          onDeleted: widget.onDeleted,
        );
      },
      loading: () {
        if (widget.embedded) {
          return const Center(child: CircularProgressIndicator());
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Buddy')),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, stack) {
        if (widget.embedded) {
          return Center(child: Text('Error: $error'));
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Buddy')),
          body: Center(child: Text('Error: $error')),
        );
      },
    );
  }
}

class _BuddyDetailContent extends ConsumerWidget {
  final Buddy buddy;
  final bool embedded;
  final VoidCallback? onDeleted;

  const _BuddyDetailContent({
    required this.buddy,
    this.embedded = false,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(buddyStatsProvider(buddy.id));

    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header
          _buildProfileHeader(context),
          const SizedBox(height: 24),

          // Contact info
          if (buddy.hasContactInfo) ...[
            _buildContactSection(context),
            const SizedBox(height: 24),
          ],

          // Certification info
          if (buddy.hasCertificationInfo) ...[
            _buildCertificationSection(context),
            const SizedBox(height: 24),
          ],

          // Statistics
          _buildStatsSection(context, statsAsync),
          const SizedBox(height: 24),

          // Notes
          if (buddy.notes.isNotEmpty) ...[
            _buildNotesSection(context),
            const SizedBox(height: 24),
          ],

          // Shared dives
          _buildSharedDivesSection(context, ref),
        ],
      ),
    );

    if (embedded) {
      return Column(
        children: [
          _buildEmbeddedHeader(context, ref),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(buddy.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/buddies/${buddy.id}/edit'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                await _handleDelete(context, ref);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildEmbeddedHeader(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              buddy.initials,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  buddy.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (buddy.certificationLevel != null)
                  Text(
                    buddy.certificationLevel!.displayName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            tooltip: 'Edit',
            onPressed: () {
              final state = GoRouterState.of(context);
              context.go('${state.uri.path}?selected=${buddy.id}&mode=edit');
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) async {
              if (value == 'delete') {
                await _handleDelete(context, ref);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await _showDeleteConfirmation(context);
    if (confirmed && context.mounted) {
      await ref.read(buddyListNotifierProvider.notifier).deleteBuddy(buddy.id);
      if (context.mounted) {
        if (embedded) {
          onDeleted?.call();
        } else {
          context.pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Buddy deleted')),
        );
      }
    }
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            backgroundImage:
                buddy.photoPath != null ? AssetImage(buddy.photoPath!) : null,
            child: buddy.photoPath == null
                ? Text(
                    buddy.initials,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(buddy.name, style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }

  Widget _buildContactSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (buddy.email != null)
              ListTile(
                leading: const Icon(Icons.email),
                title: Text(buddy.email!),
                onTap: () => _launchEmail(buddy.email!),
                contentPadding: EdgeInsets.zero,
                trailing: const Icon(Icons.open_in_new, size: 16),
              ),
            if (buddy.phone != null)
              ListTile(
                leading: const Icon(Icons.phone),
                title: Text(buddy.phone!),
                onTap: () => _launchPhone(buddy.phone!),
                contentPadding: EdgeInsets.zero,
                trailing: const Icon(Icons.open_in_new, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificationSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Certification',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (buddy.certificationLevel != null)
              ListTile(
                leading: const Icon(Icons.card_membership),
                title: const Text('Level'),
                subtitle: Text(buddy.certificationLevel!.displayName),
                contentPadding: EdgeInsets.zero,
              ),
            if (buddy.certificationAgency != null)
              ListTile(
                leading: const Icon(Icons.business),
                title: const Text('Agency'),
                subtitle: Text(buddy.certificationAgency!.displayName),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(
    BuildContext context,
    AsyncValue<BuddyStats> statsAsync,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dive Statistics',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            statsAsync.when(
              data: (stats) => Column(
                children: [
                  _StatRow(
                    icon: Icons.scuba_diving,
                    label: 'Dives Together',
                    value: stats.totalDives.toString(),
                  ),
                  if (stats.firstDive != null)
                    _StatRow(
                      icon: Icons.first_page,
                      label: 'First Dive',
                      value: DateFormat.yMMMd().format(stats.firstDive!),
                    ),
                  if (stats.lastDive != null)
                    _StatRow(
                      icon: Icons.last_page,
                      label: 'Last Dive',
                      value: DateFormat.yMMMd().format(stats.lastDive!),
                    ),
                  if (stats.favoriteSite != null)
                    _StatRow(
                      icon: Icons.place,
                      label: 'Favorite Site',
                      value: stats.favoriteSite!,
                    ),
                ],
              ),
              loading: () =>
                  const Center(child: CircularProgressIndicator.adaptive()),
              error: (error, _) => const Text('Unable to load stats'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(buddy.notes),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedDivesSection(BuildContext context, WidgetRef ref) {
    final diveIdsAsync = ref.watch(diveIdsForBuddyProvider(buddy.id));
    final divesAsync = ref.watch(divesForBuddyProvider(buddy.id));
    final theme = Theme.of(context);
    final dateFormat = DateFormat.MMMd();

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
                  'Shared Dives',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                diveIdsAsync.when(
                  data: (ids) => TextButton(
                    onPressed: ids.isEmpty
                        ? null
                        : () {
                            // Navigate to filtered dive list (future enhancement)
                          },
                    child: Text('View All (${ids.length})'),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (e, st) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            divesAsync.when(
              data: (dives) {
                if (dives.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('No dives together yet')),
                  );
                }
                // Show first 5 dives with same format as trip detail page
                final displayDives = dives.take(5).toList();
                return Column(
                  children: displayDives.map((dive) {
                    return InkWell(
                      onTap: () => context.push('/dives/${dive.id}'),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            // Dive number badge
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '#${dive.diveNumber ?? '-'}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Dive details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dive.site?.name ?? 'Unknown Site',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dateFormat.format(dive.dateTime),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Stats
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (dive.maxDepth != null)
                                  Text(
                                    '${dive.maxDepth!.toStringAsFixed(1)}m',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                if (dive.duration != null)
                                  Text(
                                    '${dive.duration!.inMinutes}min',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              color: theme.colorScheme.onSurfaceVariant,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator.adaptive(),
                ),
              ),
              error: (e, st) => const Text('Unable to load dives'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Buddy?'),
            content: Text(
              'Are you sure you want to delete ${buddy.name}? This will also remove them from all dives.',
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
        ) ??
        false;
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
