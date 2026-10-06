import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/presentation/certification_entry_display.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/certification_agencies/presentation/widgets/agency_swatch.dart';
import 'package:submersion/features/certification_agencies/presentation/widgets/certification_delete_dialogs.dart';
import 'package:submersion/features/certification_agencies/presentation/widgets/custom_agency_dialog.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/fab_clearance.dart';

/// Settings > Manage > Certification Agencies (issue #690): the diver's own
/// and shared custom agencies, then the built-in ones. Built-ins and other
/// divers' agencies are read-only; every row opens the agency's editor,
/// where certifications can be added.
class CertificationAgenciesPage extends ConsumerWidget {
  const CertificationAgenciesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final catalogAsync = ref.watch(certificationCatalogProvider);
    final diverNames = {
      for (final d in ref.watch(allDiversProvider).value ?? const [])
        d.id: d.name,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings_manage_certificationAgencies),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: l10n.common_action_back,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCustomAgencyDialog(context),
        tooltip: l10n.certificationAgencies_addAgency,
        icon: const Icon(Icons.add),
        label: Text(l10n.certificationAgencies_addAgency),
      ),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('${l10n.common_label_error}: $e')),
        data: (catalog) {
          final custom = catalog.agencies.where((a) => !a.isBuiltIn).toList();
          final builtIn = catalog.agencies.where((a) => a.isBuiltIn).toList();
          return ListView(
            padding: kFabListPadding,
            children: [
              if (custom.isNotEmpty) ...[
                _SectionHeader(l10n.certificationAgencies_section_yours),
                for (final a in custom)
                  _AgencyRow(
                    entry: a,
                    canEdit: catalog.canEditAgency(a.id),
                    sharedBy: catalog.canEditAgency(a.id)
                        ? null
                        : diverNames[a.custom?.diverId],
                    catalog: catalog,
                  ),
                const Divider(),
              ],
              _SectionHeader(l10n.certificationAgencies_section_builtIn),
              for (final a in builtIn)
                _AgencyRow(entry: a, canEdit: false, catalog: catalog),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _AgencyRow extends ConsumerWidget {
  const _AgencyRow({
    required this.entry,
    required this.canEdit,
    required this.catalog,
    this.sharedBy,
  });

  final AgencyEntry entry;
  final bool canEdit;
  final CertificationCatalog catalog;

  /// The owning diver's name, for another diver's shared agency.
  final String? sharedBy;

  void _open(BuildContext context) =>
      context.push('/certification-agencies/${entry.id}');

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final name = entry.localizedName(context.l10n);
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.common_error_tryAgain;
    final repo = ref.read(customCertificationRepositoryProvider);
    try {
      // An agency in use is refused up front, not after a confirmation;
      // the delete checks again in case that changes meanwhile.
      final used = await repo.agencyUsage(entry.id);
      if (!context.mounted) return;
      if (used.isUsed) {
        await showCertificationDeleteRefusal(context, used);
        return;
      }
      if (!await confirmCertificationDelete(context, name)) return;
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      if (diverId == null) return;
      final refused = await repo.deleteAgency(entry.id, actingDiverId: diverId);
      if (refused != null && context.mounted) {
        await showCertificationDeleteRefusal(context, refused);
      }
    } catch (_) {
      // Logged by the repository; tell the diver it did not happen.
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final owner = sharedBy;
    return ListTile(
      leading: AgencySwatch(
        primary: entry.primaryColor,
        secondary: entry.secondaryColor,
      ),
      title: Text(entry.localizedName(l10n)),
      subtitle: owner == null
          ? null
          : Text(l10n.certificationAgencies_sharedBy(owner)),
      onTap: () => _open(context),
      trailing: canEdit
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.common_action_edit,
                  onPressed: () => _open(context),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.common_action_delete,
                  onPressed: () => _delete(context, ref),
                ),
              ],
            )
          : const Icon(Icons.chevron_right),
    );
  }
}
