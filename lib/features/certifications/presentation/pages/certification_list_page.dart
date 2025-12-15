import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/certification.dart';
import '../providers/certification_providers.dart';

class CertificationListPage extends ConsumerWidget {
  const CertificationListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certificationsAsync = ref.watch(certificationListNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Certifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: CertificationSearchDelegate(ref),
              );
            },
          ),
        ],
      ),
      body: certificationsAsync.when(
        data: (certifications) => certifications.isEmpty
            ? _buildEmptyState(context)
            : _buildCertificationList(context, ref, certifications),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading certifications: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref
                    .read(certificationListNotifierProvider.notifier)
                    .refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/certifications/new'),
        icon: const Icon(Icons.add_card),
        label: const Text('Add Certification'),
      ),
    );
  }

  Widget _buildCertificationList(
      BuildContext context, WidgetRef ref, List<Certification> certifications) {
    // Group certifications by status (expired, expiring soon, valid)
    final expired = <Certification>[];
    final expiringSoon = <Certification>[];
    final valid = <Certification>[];

    for (final cert in certifications) {
      if (cert.isExpired) {
        expired.add(cert);
      } else if (cert.expiresWithin(90)) {
        expiringSoon.add(cert);
      } else {
        valid.add(cert);
      }
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(certificationListNotifierProvider.notifier).refresh();
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          if (expired.isNotEmpty) ...[
            _buildSectionHeader(context, 'Expired', Colors.red),
            ...expired.map((cert) => CertificationListTile(
                  certification: cert,
                  onTap: () => context.push('/certifications/${cert.id}'),
                )),
          ],
          if (expiringSoon.isNotEmpty) ...[
            _buildSectionHeader(context, 'Expiring Soon', Colors.orange),
            ...expiringSoon.map((cert) => CertificationListTile(
                  certification: cert,
                  onTap: () => context.push('/certifications/${cert.id}'),
                )),
          ],
          if (valid.isNotEmpty) ...[
            _buildSectionHeader(context, 'Valid', Colors.green),
            ...valid.map((cert) => CertificationListTile(
                  certification: cert,
                  onTap: () => context.push('/certifications/${cert.id}'),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.card_membership_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No certifications added yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your dive certifications to keep track\nof your training and qualifications',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/certifications/new'),
            icon: const Icon(Icons.add_card),
            label: const Text('Add Your First Certification'),
          ),
        ],
      ),
    );
  }
}

/// List item widget for displaying a certification
class CertificationListTile extends StatelessWidget {
  final Certification certification;
  final VoidCallback? onTap;

  const CertificationListTile({
    super.key,
    required this.certification,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: _buildLeadingIcon(context),
        title: Text(certification.name),
        subtitle: _buildSubtitle(context),
        trailing: _buildTrailing(context),
      ),
    );
  }

  Widget _buildLeadingIcon(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          certification.agency.displayName.substring(0,
              certification.agency.displayName.length > 4 ? 4 : certification.agency.displayName.length),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget? _buildSubtitle(BuildContext context) {
    final parts = <String>[];

    parts.add(certification.agency.displayName);

    if (certification.issueDate != null) {
      parts.add(DateFormat.yMMMd().format(certification.issueDate!));
    }

    return Text(parts.join(' - '));
  }

  Widget _buildTrailing(BuildContext context) {
    if (certification.isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Expired',
          style: TextStyle(
            color: Colors.red,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    } else if (certification.expiresWithin(90)) {
      final days = certification.daysUntilExpiry;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${days}d',
          style: const TextStyle(
            color: Colors.orange,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return const Icon(Icons.chevron_right);
  }
}

/// Search delegate for certifications
class CertificationSearchDelegate extends SearchDelegate<Certification?> {
  final WidgetRef ref;

  CertificationSearchDelegate(this.ref);

  @override
  String get searchFieldLabel => 'Search certifications...';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Search by name, agency, or card number',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    final searchAsync = ref.watch(certificationSearchProvider(query));

    return searchAsync.when(
      data: (certifications) {
        if (certifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No certifications found for "$query"',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: certifications.length,
          itemBuilder: (context, index) {
            final cert = certifications[index];
            return CertificationListTile(
              certification: cert,
              onTap: () {
                close(context, cert);
                context.push('/certifications/${cert.id}');
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('Error: $error'),
      ),
    );
  }
}
