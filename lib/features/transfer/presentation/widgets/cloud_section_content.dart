import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/transfer/presentation/widgets/transfer_list_content.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Cloud import section content.
///
/// Lists dive-computer manufacturer cloud accounts and online logbook
/// services (divelogs.de) that dives can be imported from directly (no file
/// export/transfer needed). Additional providers (Shearwater Cloud, etc.)
/// get their own card here as they're added.
class CloudSectionContent extends ConsumerWidget {
  const CloudSectionContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          transferSectionHeader(
            context,
            context.l10n.transfer_section_cloudTitle,
          ),
          const SizedBox(height: 8),
          _CloudProviderCard(
            title: context.l10n.transfer_importCloud_suuntoTitle,
            subtitle: context.l10n.transfer_importCloud_suuntoSubtitle,
            icon: Icons.watch,
            onTap: () => context.push('/transfer/import-cloud/suunto'),
          ),
          const SizedBox(height: 8),
          _CloudProviderCard(
            title: context.l10n.transfer_importCloud_garminTitle,
            subtitle: context.l10n.transfer_importCloud_garminSubtitle,
            icon: Icons.watch,
            onTap: () => context.push('/transfer/import-cloud/garmin'),
          ),
          const SizedBox(height: 8),
          _CloudProviderCard(
            title: context.l10n.transfer_importCloud_divelogsTitle,
            subtitle: context.l10n.transfer_importCloud_divelogsSubtitle,
            icon: Icons.menu_book,
            onTap: () => context.push('/transfer/import-cloud/divelogs'),
          ),
        ],
      ),
    );
  }
}

/// A single tappable cloud-provider entry within [CloudSectionContent].
class _CloudProviderCard extends StatelessWidget {
  const _CloudProviderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
