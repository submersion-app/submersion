import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/dive_center.dart';
import '../providers/dive_center_providers.dart';

class DiveCenterDetailPage extends ConsumerWidget {
  final String centerId;

  const DiveCenterDetailPage({super.key, required this.centerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final centerAsync = ref.watch(diveCenterByIdProvider(centerId));

    return centerAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $error')),
      ),
      data: (center) {
        if (center == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Dive center not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(center.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push('/dive-centers/$centerId/edit'),
              ),
              PopupMenuButton<String>(
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
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true && context.mounted) {
                      await ref
                          .read(diveCenterListNotifierProvider.notifier)
                          .deleteDiveCenter(centerId);
                      if (context.mounted) {
                        context.pop();
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
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderSection(center: center),
                const Divider(height: 32),
                _ContactSection(center: center),
                if (center.notes.isNotEmpty) ...[
                  const Divider(height: 32),
                  _NotesSection(notes: center.notes),
                ],
                const Divider(height: 32),
                _DivesSection(centerId: centerId),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
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
          if (center.country != null && center.location != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Text(
                  center.country!,
                  style: Theme.of(context).textTheme.bodyMedium,
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
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
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
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.outline,
            ),
          ],
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

class _DivesSection extends ConsumerWidget {
  final String centerId;

  const _DivesSection({required this.centerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diveCountAsync = ref.watch(diveCenterDiveCountProvider(centerId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Statistics', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.scuba_diving,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dives Logged',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      diveCountAsync.when(
                        data: (count) => Text(
                          count.toString(),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        loading: () => const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (_, _) => const Text('-'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
