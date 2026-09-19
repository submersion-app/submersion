import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/buddies/presentation/buddy_certification_l10n.dart';
import 'package:submersion/features/buddies/presentation/buddy_dive_share.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/master_detail/detail_scroll_retainer.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_favorite_button.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_shared_dives_section.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/certifications/presentation/certification_title_l10n.dart';

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
    // Desktop redirect: if not embedded and on desktop, redirect to master-detail view.
    // Skip in table mode -- table view has no master-detail split to redirect into.
    if (!widget.embedded &&
        !_hasRedirected &&
        ResponsiveBreakpoints.isMasterDetail(context)) {
      final viewMode = ref.read(buddyListViewModeProvider);
      if (viewMode != ListViewMode.table) {
        _hasRedirected = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/buddies?selected=${widget.buddyId}');
          }
        });
      }
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
    final units = UnitFormatter(ref.watch(settingsProvider));

    final body = SingleChildScrollView(
      controller: DetailScrollController.maybeOf(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile header
          _buildProfileHeader(context, ref),
          const SizedBox(height: 24),

          // Contact info
          if (buddy.hasContactInfo || buddy.linkedDiverId != null) ...[
            _buildContactSection(context, ref),
            const SizedBox(height: 24),
          ],

          // Certifications (issue #553): full list from the certifications
          // table, with an empty state.
          _buildCertificationSection(context, ref),
          const SizedBox(height: 24),

          // Statistics
          _buildStatsSection(context, statsAsync, units),
          const SizedBox(height: 24),

          // Notes
          if (buddy.notes.isNotEmpty) ...[
            _buildNotesSection(context),
            const SizedBox(height: 24),
          ],

          // Shared dives
          BuddySharedDivesSection(buddyId: buddy.id),
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
          BuddyFavoriteButton(buddyId: buddy.id, isFavorite: buddy.isFavorite),
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
          ProfileAvatar(
            photo: buddy.photo,
            initials: buddy.initials,
            radius: 18,
            backgroundColor: colorScheme.primaryContainer,
            textStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimaryContainer,
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
                if (buddyCertificationLineL10n(buddy, context.l10n) != null)
                  Text(
                    buddyCertificationLineL10n(buddy, context.l10n)!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          BuddyFavoriteButton(
            buddyId: buddy.id,
            isFavorite: buddy.isFavorite,
            iconSize: 20,
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

  Future<void> _shareDivesWithBuddy(BuildContext context, WidgetRef ref) =>
      shareDivesWithBuddy(context, ref, buddy.id);

  Widget _buildProfileHeader(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        children: [
          ProfileAvatar(
            photo: buddy.photo ?? _linkedProfile(ref)?.photo,
            initials: buddy.initials,
            radius: 50,
            textStyle: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(buddy.name, style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }

  /// The local profile this buddy is, when linked and loaded (issue #2002).
  Diver? _linkedProfile(WidgetRef ref) {
    final linkedId = buddy.linkedDiverId;
    if (linkedId == null) return null;
    return ref.watch(diverByIdProvider(linkedId)).value;
  }

  Widget _buildContactSection(BuildContext context, WidgetRef ref) {
    final linked = _linkedProfile(ref);
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
            if (buddy.linkedDiverId != null)
              ListTile(
                key: const Key('buddy_detail_linked_profile'),
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(context.l10n.buddies_field_linkedProfile),
                subtitle: linked == null ? null : Text(linked.name),
                contentPadding: EdgeInsets.zero,
              ),
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

  Widget _buildCertificationSection(BuildContext context, WidgetRef ref) {
    final certsAsync = ref.watch(buddyCertificationsProvider(buddy.id));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.buddies_section_certifications,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            certsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) =>
                  Text('${context.l10n.common_label_error}: $error'),
              data: (certs) => certs.isEmpty
                  ? Text(
                      context.l10n.buddies_certifications_empty,
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final cert in certs)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.card_membership),
                            title: Text(
                              certificationTitleL10n(cert, context.l10n),
                            ),
                            subtitle: Text(
                              certificationAgencyAndLevelL10n(
                                cert,
                                context.l10n,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(
    BuildContext context,
    AsyncValue<BuddyStats> statsAsync,
    UnitFormatter units,
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
                      value: units.formatDate(stats.firstDive),
                    ),
                  if (stats.lastDive != null)
                    _StatRow(
                      icon: Icons.last_page,
                      label: context.l10n.buddies_stat_lastDive,
                      value: units.formatDate(stats.lastDive),
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
