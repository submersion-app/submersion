import 'package:flutter/material.dart';
import 'package:submersion/features/equipment/domain/services/equipment_ownership.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_history_card.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_entry_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/observations_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/detail_scroll_retainer.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/cylinder_configs/presentation/widgets/unit_configurations_card.dart';
import 'package:submersion/features/media/presentation/helpers/document_open_helper.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_documents_section.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_detail_header_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_details_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_notes_card.dart';
import 'package:submersion/features/equipment/domain/entities/condition_trend.dart';
import 'package:submersion/features/equipment/presentation/widgets/children_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/components_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/condition_findings_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/condition_trend_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/exposure_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_clocks_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_history_section.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_record_dialog.dart';

class EquipmentDetailPage extends ConsumerStatefulWidget {
  final String equipmentId;
  final bool embedded;
  final VoidCallback? onDeleted;

  const EquipmentDetailPage({
    super.key,
    required this.equipmentId,
    this.embedded = false,
    this.onDeleted,
  });

  @override
  ConsumerState<EquipmentDetailPage> createState() =>
      _EquipmentDetailPageState();
}

class _EquipmentDetailPageState extends ConsumerState<EquipmentDetailPage> {
  bool _hasRedirected = false;

  @override
  Widget build(BuildContext context) {
    // Desktop redirect: if viewing detail page directly on desktop, redirect to master-detail.
    // Skip in table mode -- table view has no master-detail split to redirect into.
    if (!widget.embedded &&
        !_hasRedirected &&
        ResponsiveBreakpoints.isMasterDetail(context)) {
      final viewMode = ref.read(equipmentListViewModeProvider);
      if (viewMode != ListViewMode.table) {
        _hasRedirected = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/equipment?selected=${widget.equipmentId}');
          }
        });
      }
    }

    final equipmentAsync = ref.watch(equipmentItemProvider(widget.equipmentId));

    return equipmentAsync.when(
      data: (equipment) {
        if (equipment == null) {
          if (widget.embedded) {
            return Center(
              child: Text(context.l10n.equipment_detail_notFoundMessage),
            );
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.equipment_detail_notFoundTitle),
            ),
            body: Center(
              child: Text(context.l10n.equipment_detail_notFoundMessage),
            ),
          );
        }
        return _EquipmentDetailContent(
          equipment: equipment,
          equipmentId: widget.equipmentId,
          embedded: widget.embedded,
          onDeleted: widget.onDeleted,
        );
      },
      loading: () {
        if (widget.embedded) {
          return const Center(child: CircularProgressIndicator());
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.equipment_detail_loadingTitle),
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, _) {
        if (widget.embedded) {
          return Center(
            child: Text(context.l10n.equipment_detail_errorMessage('$error')),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.equipment_detail_errorTitle)),
          body: Center(
            child: Text(context.l10n.equipment_detail_errorMessage('$error')),
          ),
        );
      },
    );
  }
}

class _EquipmentDetailContent extends ConsumerWidget {
  final EquipmentItem equipment;
  final String equipmentId;
  final bool embedded;
  final VoidCallback? onDeleted;

  const _EquipmentDetailContent({
    required this.equipment,
    required this.equipmentId,
    required this.embedded,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    // The header's one clock: the most urgent of the item's own clocks and
    // its parts' through the rollup (issue #1487). Own clocks are read
    // separately so a retired item, absent from the active rollup, still
    // shows its state. Null when nothing is due, which draws no banner.
    RollupClock? headerClock;
    void consider(RollupClock? candidate) {
      if (candidate == null ||
          candidate.status.severity == ServiceClockSeverity.ok) {
        return;
      }
      if (headerClock == null ||
          isMoreUrgentClock(candidate.status, headerClock!.status)) {
        headerClock = candidate;
      }
    }

    consider(ref.watch(equipmentRollupClockProvider).value?[equipmentId]);
    for (final status
        in ref.watch(serviceClockStatusesProvider(equipmentId)).value ??
            const <ServiceClockStatus>[]) {
      consider((
        ownerId: equipmentId,
        ownerName: equipment.name,
        status: status,
      ));
    }
    // The avatar still reddens for overdue only, as the list tiles do; a
    // due-soon item keeps the plain avatar and says so in the banner.
    final isServiceOverdue =
        headerClock?.status.severity == ServiceClockSeverity.overdue;

    final body = SingleChildScrollView(
      controller: DetailScrollController.maybeOf(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EquipmentDetailHeaderCard(
            equipment: equipment,
            isServiceOverdue: isServiceOverdue,
            headerClock: headerClock,
          ),
          const SizedBox(height: 24),
          EquipmentDetailsCard(
            equipment: equipment,
            equipmentId: equipmentId,
            units: units,
          ),
          const SizedBox(height: 24),
          if (equipment.type == EquipmentType.tank) ...[
            PassportEntryCard(equipment: equipment),
            const SizedBox(height: 24),
          ],
          ServiceClocksCard(
            equipmentId: equipmentId,
            equipmentType: equipment.type,
            onLogService: (status) => _showAddServiceDialogForKind(
              context,
              ref,
              serviceKindId: status.kind.id,
            ),
          ),
          const SizedBox(height: 24),
          ExposureCard(equipmentId: equipmentId),
          // The findings and trend cards carry their own top gap and render
          // nothing when they have nothing to say, so the page never shows
          // a blank slot for a rule engine.
          ConditionFindingsCard(equipment: equipment),
          ConditionTrendCard(equipment: equipment),
          if (equipment.type == EquipmentType.rebreather)
            ConditionTrendCard(
              equipment: equipment,
              kind: ConditionTrendKind.scrubberMinutes,
            ),
          if (childHostTypes.contains(equipment.type)) ...[
            const SizedBox(height: 24),
            ChildrenCard(equipment: equipment),
          ],
          const SizedBox(height: 24),
          ObservationsCard(equipment: equipment),
          const SizedBox(height: 24),
          ComponentsCard(equipmentId: equipmentId),
          // Only rebreathers own configurations; every other type would show
          // a card that can never be anything but empty.
          if (equipment.type == EquipmentType.rebreather) ...[
            const SizedBox(height: 24),
            UnitConfigurationsCard(equipmentId: equipmentId),
          ],
          const SizedBox(height: 24),
          EquipmentDocumentsSection(
            equipmentId: equipmentId,
            onAttachPressed: () => DocumentOpenHelper.pickAndAttach(
              context: context,
              ref: ref,
              equipmentId: equipmentId,
            ),
            onOpenDocument: (item) =>
                DocumentOpenHelper.open(context, ref, item),
          ),
          const SizedBox(height: 24),
          // Who used it and every share (issue #2046); only with two or more
          // profiles, so a single-profile page keeps its spacing.
          if (ref.watch(hasMultipleDiversProvider)) ...[
            EquipmentHistoryCard(equipmentId: equipmentId),
            const SizedBox(height: 24),
          ],
          ServiceHistorySection(equipmentId: equipmentId),
          if (equipment.notes.isNotEmpty) ...[
            const SizedBox(height: 24),
            EquipmentNotesCard(notes: equipment.notes),
          ],
        ],
      ),
    );

    if (embedded) {
      return Column(
        children: [
          // No status line in this strip: the body below it carries the
          // page header's banner in embedded mode too, so a line here would
          // show and announce the same status twice.
          _buildEmbeddedHeader(context, ref, equipment, isServiceOverdue),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(equipment.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: context.l10n.equipment_detail_editTooltip,
            onPressed: () => context.push('/equipment/$equipmentId/edit'),
          ),
          if (_isOwner(ref, equipment))
            PopupMenuButton<String>(
              key: const ValueKey('equipment-detail-overflow'),
              onSelected: (value) => _handleMenuAction(context, ref, value),
              itemBuilder: (context) => _buildMenuItems(context),
            ),
        ],
      ),
      body: body,
    );
  }

  /// Delete is owner-only (issue #2046), so the page menu, whose one action
  /// is delete, shows only to the item's owner. With no diver or no owner
  /// every profile counts as the owner, as before sharing existed.
  bool _isOwner(WidgetRef ref, EquipmentItem equipment) {
    final activeDiver = ref.watch(validatedCurrentDiverIdProvider);
    // Hidden until the active diver is known, so a sharee never sees it flash.
    if (!activeDiver.hasValue) return false;
    return canDeleteEquipment(equipment, activeDiver.value);
  }

  Widget _buildEmbeddedHeader(
    BuildContext context,
    WidgetRef ref,
    EquipmentItem equipment,
    bool isServiceOverdue,
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
            radius: 20,
            backgroundColor: isServiceOverdue
                ? StatusColors.of(context).alert.container
                : colorScheme.tertiaryContainer,
            child: Icon(
              equipmentTypeIcon(equipment.type),
              size: 20,
              color: isServiceOverdue
                  ? StatusColors.of(context).alert.onContainer
                  : colorScheme.onTertiaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  equipment.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  equipment.type.localizedName(context.l10n),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            tooltip: context.l10n.equipment_detail_editTooltipShort,
            onPressed: () {
              final state = GoRouterState.of(context);
              final currentPath = state.uri.path;
              context.go('$currentPath?selected=$equipmentId&mode=edit');
            },
          ),
          if (_isOwner(ref, equipment))
            PopupMenuButton<String>(
              key: const ValueKey('equipment-detail-overflow'),
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) => _handleMenuAction(context, ref, value),
              itemBuilder: (context) => _buildMenuItems(context),
            ),
        ],
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context) {
    return [
      PopupMenuItem(
        value: 'delete',
        child: ListTile(
          leading: const Icon(Icons.delete, color: Colors.red),
          title: Text(
            context.l10n.equipment_menu_delete,
            style: const TextStyle(color: Colors.red),
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    ];
  }

  /// Opens the add-service dialog pre-tagged with a clock's kind so the
  /// saved record resets that clock.
  void _showAddServiceDialogForKind(
    BuildContext context,
    WidgetRef ref, {
    required String serviceKindId,
  }) {
    showDialog(
      context: context,
      builder: (context) => ServiceRecordDialog(
        equipmentId: equipmentId,
        serviceKindId: serviceKindId,
        onSave: (record) async {
          await ref
              .read(serviceRecordNotifierProvider(equipmentId).notifier)
              .addRecord(record);
        },
      ),
    );
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final notifier = ref.read(equipmentListNotifierProvider.notifier);

    switch (action) {
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.equipment_deleteDialog_title),
            content: Text(context.l10n.equipment_deleteDialog_content),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.equipment_deleteDialog_cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(context.l10n.equipment_deleteDialog_confirm),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          final deleted = await notifier.deleteEquipment(equipmentId);
          if (!deleted) {
            // Delete is owner-only (issue #2046): the item was kept, so stay
            // on it and say why.
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.equipment_delete_notOwner)),
              );
            }
            break;
          }
          if (context.mounted) {
            if (embedded) {
              onDeleted?.call();
            } else {
              context.go('/equipment');
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.equipment_snackbar_deleted)),
            );
          }
        }
        break;
    }
  }
}
