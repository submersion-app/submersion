import 'dart:async';

import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/divers/presentation/providers/new_record_diver.dart';
import 'package:submersion/features/equipment/data/services/gear_item_edit_save_service.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_new_sitting.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_clone_providers.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/record_creating.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_routes.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/equipment_detail_sections.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_detail_section_cards.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/pushed_route.dart';
import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/change_log/presentation/widgets/change_log_history_menu_item.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/widgets/open_in_connections.dart';
import 'package:submersion/features/cylinder_configs/presentation/widgets/unit_configurations_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_entry_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/twin_set_card.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_section.dart';
import 'package:submersion/features/dive_log/presentation/navigation/open_dive_list.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_colors.dart';
import 'package:submersion/features/equipment/domain/entities/condition_trend.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/services/equipment_ownership.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_position_label.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_cards.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_header_editor.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_sitting_host.dart';
import 'package:submersion/features/equipment/presentation/helpers/equipment_web_link_launcher.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/service_clock_snapshot_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_units.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_color_names.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_owned_for.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_transfer_gate.dart';
import 'package:submersion/features/equipment/presentation/utils/service_severity_colors.dart';
import 'package:submersion/features/equipment/presentation/widgets/children_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/components_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/condition_findings_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/condition_trend_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_avatar.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_bulk_transfer.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_delete_dialog.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_dive_time_row.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_documents_section.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_header_status.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_history_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_photos_section.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_sharing_row.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_tag_chips.dart';
import 'package:submersion/features/equipment/presentation/widgets/exposure_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/installed_in_row.dart';
import 'package:submersion/features/equipment/presentation/widgets/observations_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_clocks_card.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_history_section.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';
import 'package:submersion/features/gear_passports/presentation/widgets/gear_passport_entry_card.dart';
import 'package:submersion/features/media/presentation/helpers/document_open_helper.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/transmitters/presentation/widgets/transmitter_section.dart';
import 'package:submersion/features/trips/presentation/navigation/open_trip_list.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row_group.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';
import 'package:submersion/shared/widgets/master_detail/detail_scroll_retainer.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_fade.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_open_unlocked.dart';
import 'package:submersion/shared/widgets/record_editing/record_pane_row.dart';

part 'equipment_detail_page_body.dart';
part 'equipment_detail_page_creating.dart';
part 'equipment_detail_page_editing.dart';
part 'equipment_detail_page_menu.dart';
part 'equipment_detail_page_sections.dart';

/// A gear item's page. It opens locked and edits in place (issue #4527): its
/// cards are held in one sitting and written by one Save.
class EquipmentDetailPage extends ConsumerStatefulWidget {
  final String equipmentId;
  final bool embedded;
  final VoidCallback? onDeleted;

  /// Opens unlocked, as the old edit address asks (`?mode=edit`).
  final bool openUnlocked;

  /// Told when a sitting the page opened unlocked ends: the list pane's
  /// edit returns to the item in view.
  final VoidCallback? onSittingEnded;

  /// A new item or a clone (issue #4527, phase 3, plan 11): the page
  /// opened unlocked on an item not yet created, with what [request] asks.
  final NewGearItemRequest? newItem;

  /// The pane's own: given the new item's id once created.
  final void Function(String equipmentId)? onCreated;

  /// The pane's own: told when a new item's page leaves uncreated.
  final VoidCallback? onCreateCancelled;

  const EquipmentDetailPage({
    super.key,
    required this.equipmentId,
    this.embedded = false,
    this.onDeleted,
    this.openUnlocked = false,
    this.onSittingEnded,
  }) : newItem = null,
       onCreated = null,
       onCreateCancelled = null;

  /// A new item's page.
  const EquipmentDetailPage.newItem({
    super.key,
    NewGearItemRequest request = const NewGearItemRequest(),
    this.embedded = false,
    this.onCreated,
    this.onCreateCancelled,
  }) : newItem = request,
       equipmentId = '',
       onDeleted = null,
       openUnlocked = false,
       onSittingEnded = null;

  @override
  ConsumerState<EquipmentDetailPage> createState() =>
      _EquipmentDetailPageState();
}

class _EquipmentDetailPageState extends ConsumerState<EquipmentDetailPage>
    with
        RecordEditHost<EquipmentDetailPage, EquipmentItem>,
        RecordOpenUnlocked<EquipmentDetailPage, EquipmentItem>,
        GearItemSittingHost<EquipmentDetailPage>,
        _EquipmentDetailPageEditing,
        RecordCreating<EquipmentDetailPage, EquipmentItem>,
        _EquipmentDetailPageCreating {
  bool _hasRedirected = false;

  @override
  void dispose() {
    disposeEditing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isCreating) {
      final seed = newRecordSeed;
      return newRecordWaiting(context) ??
          _EquipmentDetailContent(
            equipment: shownRecord(seed!),
            stored: seed,
            equipmentId: seed.id,
            embedded: widget.embedded,
            host: this,
          );
    }
    // Desktop redirect: a root visit (deep link, sidebar) moves into the
    // master-detail split. A pushed page, opened from a dive's details
    // say, stays put: the redirect's go() would erase the page under it
    // and its back arrow (#3292).
    if (!_hasRedirected &&
        shouldRedirectToMasterDetail(
          context,
          embedded: widget.embedded,
          viewMode: ref.read(equipmentListViewModeProvider),
        )) {
      _hasRedirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Into the pane, unlocked when the edit address asked for it.
          context.go(
            gearItemPaneLocation(
              widget.equipmentId,
              openUnlocked: widget.openUnlocked,
            ),
          );
        }
      });
    }

    final equipmentAsync = ref.watch(equipmentItemProvider(widget.equipmentId));
    followStored(equipmentItemProvider(widget.equipmentId));

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
        openUnlockedOnce(equipment);
        return _EquipmentDetailContent(
          equipment: shownRecord(equipment),
          stored: equipment,
          equipmentId: widget.equipmentId,
          embedded: widget.embedded,
          onDeleted: widget.onDeleted,
          host: this,
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
  /// The item the cards show: the sitting's while unlocked.
  final EquipmentItem equipment;

  /// The item as stored.
  final EquipmentItem stored;
  final String equipmentId;
  final bool embedded;
  final VoidCallback? onDeleted;

  /// The page, which edits in place.
  final _EquipmentDetailPageState host;

  const _EquipmentDetailContent({
    required this.equipment,
    required this.stored,
    required this.equipmentId,
    required this.embedded,
    required this.host,
    this.onDeleted,
  });

  /// An item not yet created: only the cards of its own values are shown.
  bool get _creating => host.isCreating;

  /// [child] as the card [id].
  Widget _framed(GearItemCardId id, Widget child, {double topGap = 0}) =>
      host._framed(id, child, topGap: topGap);

  /// The page's sitting, while it has one.
  EditSession<EquipmentItem>? get _session => host.maybeEditController?.session;

  /// Whether the empty card [id] is shown in the sitting.
  bool _shows(GearItemCardId id) => host._showsWhileEmpty(id);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitFormatterProvider);
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

    // Wishlist gear (#2025) is out of service clocks: a schedule kept from
    // when it was owned shows nothing until the item is bought again. An
    // item not yet created has no clock to show (plan 11).
    if (!equipment.isWanted && !_creating) {
      consider(ref.watch(equipmentRollupClockProvider).value?[equipmentId]);
      // The same read as the Service clocks card, so the two never disagree
      // and the clocks are evaluated once (issue #5042).
      for (final status
          in ref
                  .watch(serviceClockSnapshotProvider(equipmentId))
                  .value
                  ?.statuses ??
              const <ServiceClockStatus>[]) {
        consider((
          ownerId: equipmentId,
          ownerName: equipment.name,
          status: status,
        ));
      }
    }
    // The avatar still reddens for overdue only, as the list tiles do; a
    // due-soon item keeps the plain avatar and says so in the banner.
    final isServiceOverdue =
        headerClock?.status.severity == ServiceClockSeverity.overdue;

    // An item not yet created has no clock, so its header has no banner;
    // which cards follow, and in what order, is the body's.
    final body = _body(
      context,
      ref,
      units,
      header: _framed(
        GearItemCardId.header,
        _buildHeaderSection(context, equipment, isServiceOverdue, headerClock),
      ),
    );

    if (embedded) {
      // No status line in this strip: the body below it carries the page
      // header's banner in embedded mode too, so a line here would show and
      // announce the same status twice.
      return host.editPane(
        header: RecordPaneRow(
          locked: _buildEmbeddedHeader(context, ref, isServiceOverdue),
          unlocked: host.isSittingOpen
              ? host.editingPaneRow(stored, menu: _buildMenu(context, ref))
              : null,
        ),
        shown: equipment,
        content: body,
      );
    }

    final bar = AppBar(
      title: Text(equipment.name),
      actions: [host.lockButton(equipment), _buildMenu(context, ref)],
    );
    return host.editScaffold(
      record: stored,
      shown: equipment,
      lockedBar: bar,
      unlockedActions: [_buildMenu(context, ref)],
      content: body,
    );
  }

  /// Delete is owner-only (issue #2046), so the page menu offers it only to
  /// the item's owner. With no diver or no owner every profile counts as the
  /// owner, as before sharing existed.
  /// Transfer is owner-only too (issue #2852), needs a real owner, and
  /// shows only with two or more profiles, like the sharing row.
  bool _canTransfer(WidgetRef ref) => canTransferEquipmentOnceKnown(
    ref.watch(validatedCurrentDiverIdProvider),
    stored,
    multipleDivers: ref.watch(hasMultipleDiversProvider),
  );

  bool _isOwner(WidgetRef ref) {
    final activeDiver = ref.watch(validatedCurrentDiverIdProvider);
    // Hidden until the active diver is known, so a sharee never sees it flash.
    if (!activeDiver.hasValue) return false;
    return canDeleteEquipment(stored, activeDiver.value);
  }

  Widget _buildEmbeddedHeader(
    BuildContext context,
    WidgetRef ref,
    bool isServiceOverdue,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final host = this.host;

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
          EquipmentAvatar(
            item: equipment,
            radius: 20,
            iconSize: 20,
            backgroundColor: isServiceOverdue
                ? StatusColors.of(context).alert.container
                : colorScheme.tertiaryContainer,
            iconColor: isServiceOverdue
                ? StatusColors.of(context).alert.onContainer
                : colorScheme.onTertiaryContainer,
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
          host.lockButton(equipment, compact: true),
          _buildMenu(context, ref),
        ],
      ),
    );
  }
}
