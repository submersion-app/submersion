import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/buddies/presentation/buddy_certification_l10n.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_context.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';

/// Summary widget shown in the detail pane when no buddy is selected.
///
/// Displays aggregate statistics about all buddies and quick actions.
class BuddySummaryWidget extends ConsumerWidget {
  const BuddySummaryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(certificationCatalogSyncProvider);
    final buddiesAsync = ref.watch(allBuddiesWithDiveCountProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            buddiesAsync.when(
              data: (entries) => _buildOverview(context, ref, entries),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('${context.l10n.common_label_error}: $e')),
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
              Icons.people,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              context.l10n.buddies_summary_title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.buddies_summary_selectHint,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildOverview(
    BuildContext context,
    WidgetRef ref,
    List<BuddyWithDiveCount> entries,
  ) {
    // Group by certification level
    final certifiedCount = entries
        .where((e) => e.buddy.certificationLevel != null)
        .length;

    final recentBuddies = applyBuddyWithDiveCountSorting(
      entries.where((e) => e.lastDiveAt != null).toList(),
      const SortState(
        field: BuddySortField.lastDive,
        direction: SortDirection.descending,
      ),
    ).take(5).toList();
    final mostDivedBuddies = applyBuddyWithDiveCountSorting(
      entries.where((e) => e.diveCount > 0).toList(),
      const SortState(
        field: BuddySortField.diveCount,
        direction: SortDirection.descending,
      ),
    ).take(5).toList();
    final units = UnitFormatter(ref.watch(settingsProvider));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.buddies_summary_overview,
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
              icon: Icons.people,
              value: '${entries.length}',
              label: context.l10n.buddies_summary_totalBuddies,
              color: Colors.blue,
            ),
            _buildStatCard(
              context,
              icon: Icons.card_membership,
              value: '$certifiedCount',
              label: context.l10n.buddies_summary_withCertification,
              color: Colors.green,
            ),
          ],
        ),
        if (recentBuddies.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildBuddyPreviewCard(
            context,
            title: context.l10n.buddies_summary_recentBuddies,
            entries: recentBuddies,
            trailingText: (entry) => units.formatDate(entry.lastDiveAt),
          ),
        ],
        if (mostDivedBuddies.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildBuddyPreviewCard(
            context,
            title: context.l10n.buddies_summary_mostDives,
            entries: mostDivedBuddies,
            trailingText: (entry) =>
                context.l10n.buddies_label_diveCount(entry.diveCount),
          ),
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
      width: 140,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
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

  Widget _buildBuddyPreviewCard(
    BuildContext context, {
    required String title,
    required List<BuddyWithDiveCount> entries,
    required String Function(BuddyWithDiveCount entry) trailingText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: entries.map((entry) {
              final buddy = entry.buddy;
              return ListTile(
                leading: ProfileAvatar(
                  photo: buddy.photo,
                  initials: buddy.initials,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                ),
                title: Text(buddy.name),
                subtitle:
                    buddyCertificationLineL10n(
                          buddy,
                          context.l10n,
                          catalog: context.certificationCatalog,
                        ) !=
                        null
                    ? Text(
                        buddyCertificationLineL10n(
                          buddy,
                          context.l10n,
                          catalog: context.certificationCatalog,
                        )!,
                      )
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      trailingText(entry),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const ExcludeSemantics(child: Icon(Icons.chevron_right)),
                  ],
                ),
                onTap: () {
                  final state = GoRouterState.of(context);
                  final currentPath = state.uri.path;
                  context.go('$currentPath?selected=${buddy.id}');
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
          context.l10n.buddies_summary_quickActions,
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
              icon: const Icon(Icons.person_add),
              label: Text(context.l10n.buddies_action_add),
            ),
          ],
        ),
      ],
    );
  }
}
