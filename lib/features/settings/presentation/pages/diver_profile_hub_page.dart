import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/widgets/delete_diver_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class DiverProfileHubPage extends ConsumerWidget {
  const DiverProfileHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diverAsync = ref.watch(currentDiverProvider);
    final diverListAsync = ref.watch(diverListNotifierProvider);

    return diverAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.settings_section_diverProfile_title),
        ),
        body: Center(
          child: Text(context.l10n.settings_profile_error_loadingDiver),
        ),
      ),
      data: (diver) {
        if (diver == null) {
          return _buildNoDiverState(context);
        }

        final diverCount =
            diverListAsync.whenOrNull(data: (divers) => divers.length) ?? 1;

        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.settings_section_diverProfile_title),
            actions: [
              if (diverCount > 1)
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'delete') {
                      await _showDeleteConfirmation(context, ref, diver);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        context.l10n.settings_profileHub_deleteDiver,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: ListView(
            children: [
              _buildActiveDiverCard(context, diver),
              const SizedBox(height: 16),
              _buildSectionTilesCard(context, diver),
              const SizedBox(height: 16),
              _buildManagementTilesCard(context, ref, diver),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoDiverState(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings_section_diverProfile_title),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_add,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.settings_profile_noDiverProfile,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.settings_profile_noDiverProfile_subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/settings/diver-profile/new'),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.settings_profileHub_addNewDiver),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveDiverCard(BuildContext context, Diver diver) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Text(
                  diver.initials,
                  style: theme.textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                diver.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(context.l10n.divers_detail_activeDiver),
                backgroundColor: theme.colorScheme.primaryContainer,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTilesCard(BuildContext context, Diver diver) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _buildSectionTile(
              context,
              icon: Icons.person,
              title: context.l10n.settings_profileHub_personalInfo,
              subtitle: _personalInfoSubtitle(diver),
              route: '/settings/diver-profile/personal',
            ),
            const Divider(height: 1),
            _buildSectionTile(
              context,
              icon: Icons.contact_phone,
              title: context.l10n.settings_profileHub_emergencyContacts,
              subtitle: _emergencyContactsSubtitle(context, diver),
              route: '/settings/diver-profile/emergency',
            ),
            const Divider(height: 1),
            _buildSectionTile(
              context,
              icon: Icons.medical_information,
              title: context.l10n.settings_profileHub_medicalInfo,
              subtitle: _medicalInfoSubtitle(context, diver),
              route: '/settings/diver-profile/medical',
            ),
            const Divider(height: 1),
            _buildSectionTile(
              context,
              icon: Icons.health_and_safety,
              title: context.l10n.settings_profileHub_insurance,
              subtitle: _insuranceSubtitle(context, diver),
              route: '/settings/diver-profile/insurance',
            ),
            const Divider(height: 1),
            _buildSectionTile(
              context,
              icon: Icons.notes,
              title: context.l10n.settings_profileHub_notes,
              subtitle: _notesSubtitle(context, diver),
              route: '/settings/diver-profile/notes',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
  }

  Widget _buildManagementTilesCard(
    BuildContext context,
    WidgetRef ref,
    Diver diver,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            ListTile(
              leading: Icon(
                Icons.swap_horiz,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(context.l10n.settings_profileHub_switchDiver),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDiverSwitcher(context, ref, diver.id),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.person_add,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(context.l10n.settings_profileHub_addNewDiver),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/diver-profile/new'),
            ),
          ],
        ),
      ),
    );
  }

  // -- Subtitle logic --

  String _personalInfoSubtitle(Diver diver) {
    if (diver.email != null && diver.email!.isNotEmpty) {
      return diver.email!;
    }
    if (diver.phone != null && diver.phone!.isNotEmpty) {
      return diver.phone!;
    }
    return diver.name;
  }

  String _emergencyContactsSubtitle(BuildContext context, Diver diver) {
    int count = 0;
    if (diver.emergencyContact.isComplete) count++;
    if (diver.emergencyContact2.isComplete) count++;
    return context.l10n.settings_profileHub_emergencyContacts_count(count);
  }

  String _medicalInfoSubtitle(BuildContext context, Diver diver) {
    if (diver.bloodType != null && diver.bloodType!.isNotEmpty) {
      return diver.bloodType!;
    }
    if (diver.hasMedicalInfo) {
      return context.l10n.settings_profileHub_medicalInfo;
    }
    return context.l10n.settings_profileHub_medicalInfo_notSet;
  }

  String _insuranceSubtitle(BuildContext context, Diver diver) {
    final insurance = diver.insurance;
    if (insurance.provider == null || insurance.provider!.isEmpty) {
      return context.l10n.settings_profileHub_insurance_notSet;
    }

    if (insurance.isExpired) {
      return '${insurance.provider} - ${context.l10n.settings_profileHub_insurance_expired}';
    }

    if (insurance.expiryDate != null) {
      final formatted = DateFormat.yMMMd().format(insurance.expiryDate!);
      return '${insurance.provider} - $formatted';
    }

    return insurance.provider!;
  }

  String _notesSubtitle(BuildContext context, Diver diver) {
    if (diver.notes.isEmpty) {
      return context.l10n.settings_profileHub_notes_notSet;
    }
    return diver.notes.split('\n').first;
  }

  // -- Dialogs --

  void _showDiverSwitcher(
    BuildContext context,
    WidgetRef ref,
    String currentDiverId,
  ) {
    final diverListAsync = ref.read(diverListNotifierProvider);

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  context.l10n.settings_profile_switchDiver_title,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              const Divider(),
              Flexible(
                child: diverListAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Text(
                      context.l10n.settings_profile_error_loadingDiver,
                    ),
                  ),
                  data: (divers) => ListView.builder(
                    shrinkWrap: true,
                    itemCount: divers.length,
                    itemBuilder: (listContext, index) {
                      final diver = divers[index];
                      final isActive = diver.id == currentDiverId;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            sheetContext,
                          ).colorScheme.primaryContainer,
                          foregroundColor: Theme.of(
                            sheetContext,
                          ).colorScheme.onPrimaryContainer,
                          child: Text(diver.initials),
                        ),
                        title: Text(diver.name),
                        trailing: isActive
                            ? Icon(
                                Icons.check,
                                color: Theme.of(
                                  sheetContext,
                                ).colorScheme.primary,
                              )
                            : null,
                        onTap: () {
                          if (!isActive) {
                            ref
                                .read(currentDiverIdProvider.notifier)
                                .setCurrentDiver(diver.id);
                            Navigator.of(sheetContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.l10n.settings_profile_switchedTo(
                                    diver.name,
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    Diver diver,
  ) async {
    final confirmed = await DeleteDiverDialog.show(
      context,
      diverName: diver.name,
    );
    if (confirmed && context.mounted) {
      await ref.read(diverListNotifierProvider.notifier).deleteDiver(diver.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.settings_profileHub_deleted)),
        );
      }
    }
  }
}
