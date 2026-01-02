import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/certification.dart';
import '../providers/certification_providers.dart';

class CertificationDetailPage extends ConsumerWidget {
  final String certificationId;

  const CertificationDetailPage({super.key, required this.certificationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certificationAsync =
        ref.watch(certificationByIdProvider(certificationId));

    return certificationAsync.when(
      data: (certification) {
        if (certification == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Certification')),
            body: const Center(child: Text('Certification not found')),
          );
        }
        return _CertificationDetailContent(certification: certification);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Certification')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        appBar: AppBar(title: const Text('Certification')),
        body: Center(child: Text('Error: $error')),
      ),
    );
  }
}

class _CertificationDetailContent extends ConsumerWidget {
  final Certification certification;

  const _CertificationDetailContent({required this.certification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(certification.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () =>
                context.push('/certifications/${certification.id}/edit'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                final confirmed = await _showDeleteConfirmation(context);
                if (confirmed && context.mounted) {
                  await ref
                      .read(certificationListNotifierProvider.notifier)
                      .deleteCertification(certification.id);
                  if (context.mounted) {
                    context.pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Certification deleted')),
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
            // Status banner
            _buildStatusBanner(context),
            const SizedBox(height: 24),

            // Header with agency logo
            _buildHeader(context),
            const SizedBox(height: 24),

            // Basic info
            _buildBasicInfoSection(context),
            const SizedBox(height: 16),

            // Dates
            _buildDatesSection(context),
            const SizedBox(height: 16),

            // Instructor info
            if (certification.instructorName != null ||
                certification.instructorNumber != null) ...[
              _buildInstructorSection(context),
              const SizedBox(height: 16),
            ],

            // Card photos (placeholder for future)
            if (certification.photoFrontPath != null ||
                certification.photoBackPath != null) ...[
              _buildPhotosSection(context),
              const SizedBox(height: 16),
            ],

            // Notes
            if (certification.notes.isNotEmpty) ...[
              _buildNotesSection(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context) {
    if (certification.isExpired) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This certification has expired',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (certification.expiryDate != null)
                    Text(
                      'Expired on ${DateFormat.yMMMd().format(certification.expiryDate!)}',
                      style: TextStyle(
                        color: Colors.red.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (certification.expiresWithin(90)) {
      final days = certification.daysUntilExpiry ?? 0;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expires in $days days',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (certification.expiryDate != null)
                    Text(
                      'Expires on ${DateFormat.yMMMd().format(certification.expiryDate!)}',
                      style: TextStyle(
                        color: Colors.orange.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildHeader(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                certification.agency.displayName.substring(
                  0,
                  certification.agency.displayName.length > 4
                      ? 4
                      : certification.agency.displayName.length,
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            certification.name,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            certification.agency.displayName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Certification Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.card_membership,
              label: 'Type',
              value: certification.name,
            ),
            _InfoRow(
              icon: Icons.business,
              label: 'Agency',
              value: certification.agency.displayName,
            ),
            if (certification.level != null)
              _InfoRow(
                icon: Icons.stairs,
                label: 'Level',
                value: certification.level!.displayName,
              ),
            if (certification.cardNumber != null)
              _InfoRow(
                icon: Icons.numbers,
                label: 'Card Number',
                value: certification.cardNumber!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatesSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dates',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            if (certification.issueDate != null)
              _InfoRow(
                icon: Icons.event_available,
                label: 'Issue Date',
                value: DateFormat.yMMMd().format(certification.issueDate!),
              ),
            if (certification.expiryDate != null)
              _InfoRow(
                icon: Icons.event_busy,
                label: 'Expiry Date',
                value: DateFormat.yMMMd().format(certification.expiryDate!),
                valueColor: certification.isExpired
                    ? Colors.red
                    : certification.expiresWithin(90)
                        ? Colors.orange
                        : null,
              ),
            if (certification.expiryDate == null)
              const _InfoRow(
                icon: Icons.all_inclusive,
                label: 'Validity',
                value: 'No Expiration',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructorSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Instructor',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            if (certification.instructorName != null)
              _InfoRow(
                icon: Icons.person,
                label: 'Name',
                value: certification.instructorName!,
              ),
            if (certification.instructorNumber != null)
              _InfoRow(
                icon: Icons.badge,
                label: 'Instructor #',
                value: certification.instructorNumber!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Card Photos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (certification.photoFrontPath != null)
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          height: 100,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(Icons.image, size: 40),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('Front', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                if (certification.photoFrontPath != null &&
                    certification.photoBackPath != null)
                  const SizedBox(width: 16),
                if (certification.photoBackPath != null)
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          height: 100,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(Icons.image, size: 40),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('Back', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
              ],
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
            Text(certification.notes),
          ],
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Certification?'),
            content: Text(
              'Are you sure you want to delete "${certification.name}"?',
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
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }
}
