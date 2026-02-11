import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';

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
        ResponsiveBreakpoints.isMasterDetail(context)) {
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
            return Center(child: Text(context.l10n.buddies_detail_notFound));
          }
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.buddies_title_singular)),
            body: Center(child: Text(context.l10n.buddies_detail_notFound)),
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
          appBar: AppBar(title: Text(context.l10n.buddies_title_singular)),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, stack) {
        if (widget.embedded) {
          return Center(
            child: Text(context.l10n.buddies_detail_error(error.toString())),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.buddies_title_singular)),
          body: Center(
            child: Text(context.l10n.buddies_detail_error(error.toString())),
          ),
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
            tooltip: context.l10n.buddies_action_edit,
            onPressed: () => context.push('/buddies/${buddy.id}/edit'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'share') {
                await _shareDivesWithBuddy(context, ref);
              } else if (value == 'delete') {
                await _handleDelete(context, ref);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    const Icon(Icons.share),
                    const SizedBox(width: 8),
                    Text(context.l10n.buddies_action_shareDives),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.common_action_delete,
                      style: const TextStyle(color: Colors.red),
                    ),
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
            tooltip: context.l10n.common_action_edit,
            onPressed: () {
              final state = GoRouterState.of(context);
              context.go('${state.uri.path}?selected=${buddy.id}&mode=edit');
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) async {
              if (value == 'share') {
                await _shareDivesWithBuddy(context, ref);
              } else if (value == 'delete') {
                await _handleDelete(context, ref);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    const Icon(Icons.share, size: 20),
                    const SizedBox(width: 8),
                    Text(context.l10n.buddies_action_shareDives),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.common_action_delete,
                      style: const TextStyle(color: Colors.red),
                    ),
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
          SnackBar(content: Text(context.l10n.buddies_message_deleted)),
        );
      }
    }
  }

  Future<void> _shareDivesWithBuddy(BuildContext context, WidgetRef ref) async {
    // Capture the scaffold messenger and l10n before any async gaps
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;

    // Show preparing message
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(l10n.buddies_message_preparingExport),
        duration: const Duration(seconds: 1),
      ),
    );

    // Get all dive IDs for this buddy
    final diveIds = await ref.read(diveIdsForBuddyProvider(buddy.id).future);

    if (diveIds.isEmpty) {
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.buddies_message_noDivesToShare)),
      );
      return;
    }

    try {
      // Fetch all dives
      final diveRepository = ref.read(diveRepositoryProvider);
      final dives = <Dive>[];
      for (final diveId in diveIds) {
        final dive = await diveRepository.getDiveById(diveId);
        if (dive != null) {
          dives.add(dive);
        }
      }

      if (dives.isEmpty) {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(l10n.buddies_message_noDivesFound)),
        );
        return;
      }

      // Get unique sites from dives
      final sites = dives
          .where((d) => d.site != null)
          .map((d) => d.site!)
          .toSet()
          .toList();

      scaffoldMessenger.hideCurrentSnackBar();

      // Export to UDDF (this opens the share sheet)
      final exportService = ref.read(exportServiceProvider);
      await exportService.exportDivesToUddf(dives, sites: sites);

      // Note: Success snackbar may not show if share sheet is still active
      // That's fine - the share sheet itself provides feedback
    } catch (e) {
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(l10n.buddies_message_exportFailed(e.toString())),
        ),
      );
    }
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            backgroundImage: buddy.photoPath != null
                ? AssetImage(buddy.photoPath!)
                : null,
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
              context.l10n.buddies_section_contact,
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
              context.l10n.buddies_section_certification,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (buddy.certificationLevel != null)
              ListTile(
                leading: const Icon(Icons.card_membership),
                title: Text(context.l10n.buddies_label_level),
                subtitle: Text(buddy.certificationLevel!.displayName),
                contentPadding: EdgeInsets.zero,
              ),
            if (buddy.certificationAgency != null)
              ListTile(
                leading: const Icon(Icons.business),
                title: Text(context.l10n.buddies_label_agency),
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
              context.l10n.buddies_section_diveStatistics,
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
                    label: context.l10n.buddies_stat_divesTogether,
                    value: stats.totalDives.toString(),
                  ),
                  if (stats.firstDive != null)
                    _StatRow(
                      icon: Icons.first_page,
                      label: context.l10n.buddies_stat_firstDive,
                      value: DateFormat.yMMMd().format(stats.firstDive!),
                    ),
                  if (stats.lastDive != null)
                    _StatRow(
                      icon: Icons.last_page,
                      label: context.l10n.buddies_stat_lastDive,
                      value: DateFormat.yMMMd().format(stats.lastDive!),
                    ),
                  if (stats.favoriteSite != null)
                    _StatRow(
                      icon: Icons.place,
                      label: context.l10n.buddies_stat_favoriteSite,
                      value: stats.favoriteSite!,
                    ),
                ],
              ),
              loading: () =>
                  const Center(child: CircularProgressIndicator.adaptive()),
              error: (error, _) =>
                  Text(context.l10n.buddies_error_unableToLoadStats),
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
              context.l10n.buddies_section_notes,
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
                  context.l10n.buddies_section_sharedDives,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                diveIdsAsync.when(
                  data: (ids) => TextButton(
                    onPressed: ids.isEmpty
                        ? null
                        : () {
                            // Set filter to show only shared dives with this buddy
                            ref
                                .read(diveFilterProvider.notifier)
                                .state = DiveFilterState(
                              diveIds: ids,
                              buddyId: buddy.id,
                            );
                            // Navigate to dive list
                            context.go('/dives');
                          },
                    child: Text(
                      context.l10n.buddies_action_viewAll(ids.length),
                    ),
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
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(context.l10n.buddies_detail_noDivesTogether),
                    ),
                  );
                }
                // Show first 5 dives with same format as trip detail page
                final displayDives = dives.take(5).toList();
                return Column(
                  children: displayDives.map((dive) {
                    return Semantics(
                      button: true,
                      label:
                          'View dive ${dive.diveNumber ?? ''} at ${dive.site?.name ?? 'Unknown Site'}',
                      child: InkWell(
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
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      dateFormat.format(dive.dateTime),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
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
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  if (dive.duration != null)
                                    Text(
                                      '${dive.duration!.inMinutes}min',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 4),
                              ExcludeSemantics(
                                child: Icon(
                                  Icons.chevron_right,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
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
              error: (e, st) =>
                  Text(context.l10n.buddies_error_unableToLoadDives),
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
            title: Text(context.l10n.buddies_dialog_deleteTitle),
            content: Text(
              context.l10n.buddies_dialog_deleteMessage(buddy.name),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.common_action_cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(context.l10n.common_action_delete),
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
