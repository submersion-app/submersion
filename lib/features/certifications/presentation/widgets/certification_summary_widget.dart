import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';

/// Summary widget shown when no certification is selected.
class CertificationSummaryWidget extends ConsumerWidget {
  const CertificationSummaryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certificationsAsync = ref.watch(certificationListNotifierProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            certificationsAsync.when(
              data: (certs) => _buildOverview(context, certs),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
            const SizedBox(height: 24),
            _buildQuickActions(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.card_membership,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Certifications',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Select a certification from the list to view details',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildOverview(BuildContext context, List certs) {
    int expiredCount = 0;
    int expiringSoonCount = 0;
    int validCount = 0;

    for (final cert in certs) {
      if (cert.isExpired) {
        expiredCount++;
      } else if (cert.expiresWithin(90)) {
        expiringSoonCount++;
      } else {
        validCount++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              context,
              icon: Icons.card_membership,
              value: '${certs.length}',
              label: 'Total',
              color: Colors.blue,
            ),
            _buildStatCard(
              context,
              icon: Icons.check_circle,
              value: '$validCount',
              label: 'Valid',
              color: Colors.green,
            ),
            if (expiringSoonCount > 0)
              _buildStatCard(
                context,
                icon: Icons.schedule,
                value: '$expiringSoonCount',
                label: 'Expiring Soon',
                color: Colors.orange,
              ),
            if (expiredCount > 0)
              _buildStatCard(
                context,
                icon: Icons.warning,
                value: '$expiredCount',
                label: 'Expired',
                color: Colors.red,
              ),
          ],
        ),
        if (certs.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildCertListPreview(context, certs),
        ],
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      width: 120,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCertListPreview(BuildContext context, List certs) {
    final previewCerts = certs.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Certifications',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: previewCerts.map((cert) {
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      cert.agency.displayName.substring(0, 4),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
                title: Text(cert.name),
                subtitle: Text(cert.agency.displayName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final state = GoRouterState.of(context);
                  final currentPath = state.uri.path;
                  context.go('$currentPath?selected=${cert.id}');
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () {
                final state = GoRouterState.of(context);
                final currentPath = state.uri.path;
                context.go('$currentPath?mode=new');
              },
              icon: const Icon(Icons.add_card),
              label: const Text('Add Certification'),
            ),
          ],
        ),
      ],
    );
  }
}
