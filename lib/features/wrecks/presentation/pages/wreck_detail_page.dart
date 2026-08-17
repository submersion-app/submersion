import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/wrecks/domain/entities/wreck.dart';
import 'package:submersion/features/wrecks/presentation/providers/wreck_providers.dart';
import 'package:submersion/features/wrecks/presentation/widgets/wreck_labels.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One catalogue wreck: its structured facts, its linked site, and the
/// edit and delete actions.
class WreckDetailPage extends ConsumerWidget {
  final String wreckId;

  /// Embedded in the master-detail pane, the page supplies no Scaffold of
  /// its own (the pane already has one).
  final bool embedded;

  const WreckDetailPage({
    super.key,
    required this.wreckId,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final wreckAsync = ref.watch(wreckProvider(wreckId));

    return wreckAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (wreck) {
        if (wreck == null) {
          // Deleted underneath us (another device, or this one).
          return Center(child: Text(l10n.wrecks_empty_title));
        }
        final body = _body(context, ref, wreck);
        if (embedded) return body;
        return Scaffold(
          appBar: AppBar(
            title: Text(wreck.name),
            actions: [
              IconButton(
                key: const ValueKey('wreckEditButton'),
                icon: const Icon(Icons.edit),
                tooltip: l10n.wrecks_edit,
                onPressed: () => context.push('/wrecks/$wreckId/edit'),
              ),
              IconButton(
                key: const ValueKey('wreckDeleteButton'),
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.common_action_delete,
                onPressed: () => _confirmDelete(context, ref, wreck),
              ),
            ],
          ),
          body: body,
        );
      },
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, Wreck wreck) {
    final l10n = context.l10n;
    final depthUnit = ref.watch(settingsProvider.select((s) => s.depthUnit));
    final unitInMeters = depthUnit == DepthUnit.feet ? 0.3048 : 1.0;
    final symbol = depthUnit.symbol;

    final facts = <(String, String)>[
      (
        l10n.wrecks_field_vesselType,
        wreckVesselTypeLabel(l10n, wreck.vesselTypeName),
      ),
      (
        l10n.wrecks_field_depthToDeck,
        wreckMeasure(wreck.depthToDeckMeters, unitInMeters, symbol),
      ),
      (
        l10n.wrecks_field_depthToSeabed,
        wreckMeasure(wreck.depthToSeabedMeters, unitInMeters, symbol),
      ),
      (
        l10n.wrecks_field_length,
        wreckMeasure(wreck.lengthMeters, unitInMeters, symbol),
      ),
      (l10n.wrecks_field_yearBuilt, wreck.yearBuilt?.toString() ?? ''),
      (l10n.wrecks_field_yearSunk, wreck.yearSunk?.toString() ?? ''),
      (l10n.wrecks_field_cause, wreckCauseLabel(l10n, wreck.causeName)),
      (
        l10n.wrecks_field_condition,
        wreckConditionLabel(l10n, wreck.conditionName),
      ),
      (
        l10n.wrecks_field_protection,
        wreckProtectionLabel(l10n, wreck.protectionName),
      ),
    ].where((f) => f.$2.isNotEmpty).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(wreck.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                for (final f in facts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 160, child: Text(f.$1)),
                        Expanded(
                          child: Text(
                            f.$2,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (wreck.penetrationPossible != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 160,
                          child: Text(l10n.wrecks_field_penetration),
                        ),
                        Icon(
                          wreck.penetrationPossible!
                              ? Icons.check_circle_outline
                              : Icons.block,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (wreck.siteId != null) _siteCard(context, ref, wreck.siteId!),
        if (wreck.notes.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.wrecks_field_notes,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(wreck.notes),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _siteCard(BuildContext context, WidgetRef ref, String siteId) {
    final site = ref.watch(siteProvider(siteId)).valueOrNull;
    return Card(
      child: ListTile(
        key: const ValueKey('wreckSiteRow'),
        leading: const Icon(Icons.location_on_outlined),
        title: Text(context.l10n.wrecks_field_site),
        subtitle: Text(site?.name ?? siteId),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/sites/$siteId'),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Wreck wreck,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.wrecks_deleteConfirm(wreck.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            key: const ValueKey('wreckDeleteConfirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(wreckRepositoryProvider).deleteWreck(wreck.id);
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}
