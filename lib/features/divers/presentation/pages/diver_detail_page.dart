import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

class DiverDetailPage extends ConsumerStatefulWidget {
  final String diverId;

  /// When true, renders without Scaffold wrapper for use in master-detail layout.
  final bool embedded;

  /// Callback when the diver is deleted (used in embedded mode).
  final VoidCallback? onDeleted;

  const DiverDetailPage({
    super.key,
    required this.diverId,
    this.embedded = false,
    this.onDeleted,
  });

  @override
  ConsumerState<DiverDetailPage> createState() => _DiverDetailPageState();
}

class _DiverDetailPageState extends ConsumerState<DiverDetailPage> {
  bool _hasRedirected = false;

  @override
  Widget build(BuildContext context) {
    // On desktop, redirect standalone detail pages to master-detail view
    if (!widget.embedded &&
        !_hasRedirected &&
        ResponsiveBreakpoints.isMasterDetail(context)) {
      _hasRedirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/divers?selected=${widget.diverId}');
        }
      });
    }

    final diverAsync = ref.watch(diverByIdProvider(widget.diverId));

    return diverAsync.when(
      data: (diver) {
        if (diver == null) {
          if (widget.embedded) {
            return Center(child: Text(context.l10n.divers_detail_notFound));
          }
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.divers_detail_appBarTitle)),
            body: Center(child: Text(context.l10n.divers_detail_notFound)),
          );
        }
        return _DiverDetailContent(
          diver: diver,
          embedded: widget.embedded,
          onDeleted: widget.onDeleted,
        );
      },
      loading: () {
        if (widget.embedded) {
          return const Center(child: CircularProgressIndicator());
        }
        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.divers_detail_appBarTitle)),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, stack) {
        if (widget.embedded) {
          return Center(
            child: Text(context.l10n.divers_detail_errorPrefix('$error')),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.divers_detail_appBarTitle)),
          body: Center(
            child: Text(context.l10n.divers_detail_errorPrefix('$error')),
          ),
        );
      },
    );
  }
}

class _DiverDetailContent extends ConsumerWidget {
  final Diver diver;
  final bool embedded;
  final VoidCallback? onDeleted;

  const _DiverDetailContent({
    required this.diver,
    this.embedded = false,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(diverStatsProvider(diver.id));
    final currentDiverId = ref.watch(currentDiverIdProvider);
    final isCurrentDiver = diver.id == currentDiverId;

    final body = SingleChildScrollView(
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
          if (diver.hasMedicalInfo) ...[
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
    );

    if (embedded) {
      return Column(
        children: [
          _buildEmbeddedHeader(context, ref, isCurrentDiver),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(diver.name),
        actions: _buildAppBarActions(context, ref, isCurrentDiver),
      ),
      body: body,
    );
  }

  List<Widget> _buildAppBarActions(
    BuildContext context,
    WidgetRef ref,
    bool isCurrentDiver,
  ) {
    return [
      if (!isCurrentDiver)
        IconButton(
          icon: const Icon(Icons.switch_account),
          tooltip: context.l10n.divers_detail_switchToTooltip,
          onPressed: () async {
            await ref
                .read(currentDiverIdProvider.notifier)
                .setCurrentDiver(diver.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context.l10n.divers_detail_switchedTo(diver.name),
                  ),
                ),
              );
            }
          },
        ),
      IconButton(
        icon: const Icon(Icons.edit),
        tooltip: context.l10n.divers_detail_editTooltip,
        onPressed: () => context.push('/divers/${diver.id}/edit'),
      ),
      PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'delete') {
            await _handleDelete(context, ref);
          } else if (value == 'set_default') {
            await ref
                .read(diverListNotifierProvider.notifier)
                .setAsDefault(diver.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context.l10n.divers_detail_setAsDefaultSnackbar(diver.name),
                  ),
                ),
              );
            }
          }
        },
        itemBuilder: (context) => [
          if (!diver.isDefault)
            PopupMenuItem(
              value: 'set_default',
              child: Row(
                children: [
                  const Icon(Icons.star),
                  const SizedBox(width: 8),
                  Text(context.l10n.divers_detail_setAsDefault),
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
                  context.l10n.divers_detail_deleteMenuItem,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildEmbeddedHeader(
    BuildContext context,
    WidgetRef ref,
    bool isCurrentDiver,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

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
            radius: 16,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              diver.initials,
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 12,
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
                  diver.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                if (isCurrentDiver)
                  Text(
                    context.l10n.divers_detail_activeDiver,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colorScheme.primary),
                  ),
              ],
            ),
          ),
          if (!isCurrentDiver)
            IconButton(
              icon: const Icon(Icons.switch_account, size: 20),
              visualDensity: VisualDensity.compact,
              tooltip: context.l10n.divers_detail_switchToTooltip,
              onPressed: () async {
                await ref
                    .read(currentDiverIdProvider.notifier)
                    .setCurrentDiver(diver.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.l10n.divers_detail_switchedTo(diver.name),
                      ),
                    ),
                  );
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            visualDensity: VisualDensity.compact,
            tooltip: context.l10n.divers_detail_editTooltip,
            onPressed: () {
              final state = GoRouterState.of(context);
              final currentPath = state.uri.path;
              context.go('$currentPath?selected=${diver.id}&mode=edit');
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) async {
              if (value == 'delete') {
                await _handleDelete(context, ref);
              } else if (value == 'set_default') {
                await ref
                    .read(diverListNotifierProvider.notifier)
                    .setAsDefault(diver.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.l10n.divers_detail_setAsDefaultSnackbar(
                          diver.name,
                        ),
                      ),
                    ),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              if (!diver.isDefault)
                PopupMenuItem(
                  value: 'set_default',
                  child: Row(
                    children: [
                      const Icon(Icons.star),
                      const SizedBox(width: 8),
                      Text(context.l10n.divers_detail_setAsDefault),
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
                      context.l10n.divers_detail_deleteMenuItem,
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
      try {
        await ref
            .read(diverListNotifierProvider.notifier)
            .deleteDiver(diver.id);
        if (context.mounted) {
          if (embedded && onDeleted != null) {
            onDeleted!();
          } else {
            context.pop();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.divers_detail_deletedSnackbar)),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.divers_detail_deleteError('$e')),
            ),
          );
        }
      }
    }
  }

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
                  child: ExcludeSemantics(
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
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(diver.name, style: theme.textTheme.headlineMedium),
          if (isCurrentDiver)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  context.l10n.divers_detail_activeDiver,
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
                  Icon(Icons.star, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.divers_detail_defaultLabel,
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

  Widget _buildStatsSection(
    BuildContext context,
    AsyncValue<DiverStats> statsAsync,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.divers_detail_diveStatisticsTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            statsAsync.when(
              data: (stats) => Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.scuba_diving,
                      label: context.l10n.divers_detail_totalDivesLabel,
                      value: stats.diveCount.toString(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.timer,
                      label: context.l10n.divers_detail_bottomTimeLabel,
                      value: stats.formattedBottomTime,
                    ),
                  ),
                ],
              ),
              loading: () =>
                  const Center(child: CircularProgressIndicator.adaptive()),
              error: (error, _) =>
                  Text(context.l10n.divers_detail_unableToLoadStats),
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
              context.l10n.divers_detail_contactTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
      color: Theme.of(
        context,
      ).colorScheme.errorContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.emergency,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.divers_detail_emergencyContactTitle,
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
                subtitle: emergency.relation != null
                    ? Text(emergency.relation!)
                    : null,
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
                  context.l10n.divers_detail_medicalInfoTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (diver.bloodType != null)
              _InfoRow(
                label: context.l10n.divers_detail_bloodTypeLabel,
                value: diver.bloodType!,
              ),
            if (diver.allergies != null && diver.allergies!.isNotEmpty)
              _InfoRow(
                label: context.l10n.divers_detail_allergiesLabel,
                value: diver.allergies!,
              ),
            if (diver.medicalNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                context.l10n.divers_detail_medicalNotesLabel,
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
                  context.l10n.divers_detail_diveInsuranceTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isExpired) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      context.l10n.divers_detail_expiredBadge,
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
              _InfoRow(
                label: context.l10n.divers_detail_providerLabel,
                value: insurance.provider!,
              ),
            if (insurance.policyNumber != null)
              _InfoRow(
                label: context.l10n.divers_detail_policyNumberLabel,
                value: insurance.policyNumber!,
              ),
            if (insurance.expiryDate != null)
              _InfoRow(
                label: context.l10n.divers_detail_expiresLabel,
                value: DateFormat.yMMMd().format(insurance.expiryDate!),
                valueColor: isExpired
                    ? Theme.of(context).colorScheme.error
                    : null,
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
              context.l10n.divers_detail_notesTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
            title: Text(context.l10n.divers_detail_deleteDialogTitle),
            content: Text(
              context.l10n.divers_detail_deleteDialogContent(diver.name),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.divers_detail_cancelButton),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(context.l10n.divers_detail_deleteButton),
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

  const _InfoRow({required this.label, required this.value, this.valueColor});

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
