import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/diver.dart';
import '../providers/diver_providers.dart';

class DiverDetailPage extends ConsumerWidget {
  final String diverId;

  const DiverDetailPage({super.key, required this.diverId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diverAsync = ref.watch(diverByIdProvider(diverId));

    return diverAsync.when(
      data: (diver) {
        if (diver == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Diver')),
            body: const Center(child: Text('Diver not found')),
          );
        }
        return _DiverDetailContent(diver: diver);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Diver')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Diver')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _DiverDetailContent extends ConsumerWidget {
  final Diver diver;

  const _DiverDetailContent({required this.diver});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(diverStatsProvider(diver.id));
    final currentDiverId = ref.watch(currentDiverIdProvider);
    final isCurrentDiver = diver.id == currentDiverId;

    return Scaffold(
      appBar: AppBar(
        title: Text(diver.name),
        actions: [
          if (!isCurrentDiver)
            IconButton(
              icon: const Icon(Icons.switch_account),
              tooltip: 'Switch to this diver',
              onPressed: () async {
                await ref.read(currentDiverIdProvider.notifier).setCurrentDiver(diver.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Switched to ${diver.name}')),
                  );
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/divers/${diver.id}/edit'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                final confirmed = await _showDeleteConfirmation(context);
                if (confirmed && context.mounted) {
                  await ref.read(diverListNotifierProvider.notifier).deleteDiver(diver.id);
                  if (context.mounted) {
                    context.pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Diver deleted')),
                    );
                  }
                }
              } else if (value == 'set_default') {
                await ref.read(diverListNotifierProvider.notifier).setAsDefault(diver.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${diver.name} set as default diver')),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              if (!diver.isDefault)
                const PopupMenuItem(
                  value: 'set_default',
                  child: Row(
                    children: [
                      Icon(Icons.star),
                      SizedBox(width: 8),
                      Text('Set as Default'),
                    ],
                  ),
                ),
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
            _buildProfileHeader(context, isCurrentDiver),
            const SizedBox(height: 24),

            // Dive Statistics
            _buildStatsSection(context, statsAsync),
            const SizedBox(height: 16),

            // Contact info
            if (diver.email != null || diver.phone != null) ...[
              _buildContactSection(context),
              const SizedBox(height: 16),
            ],

            // Emergency contact
            if (diver.hasEmergencyInfo) ...[
              _buildEmergencySection(context),
              const SizedBox(height: 16),
            ],

            // Medical info
            if (_hasMedicalInfo) ...[
              _buildMedicalSection(context),
              const SizedBox(height: 16),
            ],

            // Insurance
            if (diver.insurance.provider != null) ...[
              _buildInsuranceSection(context),
              const SizedBox(height: 16),
            ],

            // Notes
            if (diver.notes.isNotEmpty) ...[
              _buildNotesSection(context),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  bool get _hasMedicalInfo =>
      diver.bloodType != null ||
      (diver.allergies != null && diver.allergies!.isNotEmpty) ||
      diver.medicalNotes.isNotEmpty;

  Widget _buildProfileHeader(BuildContext context, bool isCurrentDiver) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: diver.photoPath != null
                    ? AssetImage(diver.photoPath!)
                    : null,
                child: diver.photoPath == null
                    ? Text(
                        diver.initials,
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      )
                    : null,
              ),
              if (isCurrentDiver)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.surface,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.check,
                      size: 16,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            diver.name,
            style: theme.textTheme.headlineMedium,
          ),
          if (isCurrentDiver)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Active Diver',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          if (diver.isDefault)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Default',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, AsyncValue<DiverStats> statsAsync) {
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
              data: (stats) => Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.scuba_diving,
                      label: 'Total Dives',
                      value: stats.diveCount.toString(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.timer,
                      label: 'Bottom Time',
                      value: stats.formattedBottomTime,
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator.adaptive()),
              error: (error, _) => const Text('Unable to load stats'),
            ),
          ],
        ),
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
            if (diver.email != null)
              ListTile(
                leading: const Icon(Icons.email),
                title: Text(diver.email!),
                onTap: () => _launchEmail(diver.email!),
                contentPadding: EdgeInsets.zero,
                trailing: const Icon(Icons.open_in_new, size: 16),
              ),
            if (diver.phone != null)
              ListTile(
                leading: const Icon(Icons.phone),
                title: Text(diver.phone!),
                onTap: () => _launchPhone(diver.phone!),
                contentPadding: EdgeInsets.zero,
                trailing: const Icon(Icons.open_in_new, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencySection(BuildContext context) {
    final emergency = diver.emergencyContact;

    return Card(
      color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emergency, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 8),
                Text(
                  'Emergency Contact',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (emergency.name != null)
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(emergency.name!),
                subtitle: emergency.relation != null ? Text(emergency.relation!) : null,
                contentPadding: EdgeInsets.zero,
              ),
            if (emergency.phone != null)
              ListTile(
                leading: const Icon(Icons.phone),
                title: Text(emergency.phone!),
                onTap: () => _launchPhone(emergency.phone!),
                contentPadding: EdgeInsets.zero,
                trailing: const Icon(Icons.open_in_new, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medical_information),
                const SizedBox(width: 8),
                Text(
                  'Medical Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (diver.bloodType != null)
              _InfoRow(label: 'Blood Type', value: diver.bloodType!),
            if (diver.allergies != null && diver.allergies!.isNotEmpty)
              _InfoRow(label: 'Allergies', value: diver.allergies!),
            if (diver.medicalNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Notes',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 4),
              Text(diver.medicalNotes),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInsuranceSection(BuildContext context) {
    final insurance = diver.insurance;
    final isExpired = insurance.isExpired;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user),
                const SizedBox(width: 8),
                Text(
                  'Dive Insurance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (isExpired) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Expired',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onError,
                          ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (insurance.provider != null)
              _InfoRow(label: 'Provider', value: insurance.provider!),
            if (insurance.policyNumber != null)
              _InfoRow(label: 'Policy #', value: insurance.policyNumber!),
            if (insurance.expiryDate != null)
              _InfoRow(
                label: 'Expires',
                value: DateFormat.yMMMd().format(insurance.expiryDate!),
                valueColor: isExpired ? Theme.of(context).colorScheme.error : null,
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
            Text(diver.notes),
          ],
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Diver?'),
            content: Text(
              'Are you sure you want to delete ${diver.name}? All associated dive logs will be unassigned.',
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: valueColor,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
