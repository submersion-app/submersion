import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/repositories/buddy_repository.dart';
import '../../domain/entities/buddy.dart';
import '../providers/buddy_providers.dart';

class BuddyDetailPage extends ConsumerWidget {
  final String buddyId;

  const BuddyDetailPage({super.key, required this.buddyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buddyAsync = ref.watch(buddyByIdProvider(buddyId));

    return buddyAsync.when(
      data: (buddy) {
        if (buddy == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Buddy')),
            body: const Center(child: Text('Buddy not found')),
          );
        }
        return _BuddyDetailContent(buddy: buddy);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Buddy')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Buddy')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _BuddyDetailContent extends ConsumerWidget {
  final Buddy buddy;

  const _BuddyDetailContent({required this.buddy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(buddyStatsProvider(buddy.id));

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
                final confirmed = await _showDeleteConfirmation(context);
                if (confirmed && context.mounted) {
                  await ref
                      .read(buddyListNotifierProvider.notifier)
                      .deleteBuddy(buddy.id);
                  if (context.mounted) {
                    context.pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Buddy deleted')),
                    );
                  }
                }
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
      body: SingleChildScrollView(
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
      ),
    );
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
          Text(
            buddy.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            diveIdsAsync.when(
              data: (ids) {
                if (ids.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('No dives together yet'),
                    ),
                  );
                }
                // Show first 3 dive IDs as tappable items
                final displayIds = ids.take(3).toList();
                return Column(
                  children: displayIds.map((diveId) {
                    return ListTile(
                      leading: const Icon(Icons.scuba_diving),
                      title: const Text('Dive'),
                      subtitle: Text(diveId.substring(0, 8)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/dives/$diveId'),
                      contentPadding: EdgeInsets.zero,
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
              error: (_, __) => const Text('Unable to load dives'),
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
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
