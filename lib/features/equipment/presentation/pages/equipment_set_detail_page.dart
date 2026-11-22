import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/change_log/presentation/widgets/change_log_history_menu_item.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/new_record_diver.dart';
import 'package:submersion/features/equipment/data/services/equipment_set_edit_save_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/domain/services/set_history_diff.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_inputs.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_model_memo.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_number_badge.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_palette_theme.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_selection.dart';
import 'package:submersion/features/equipment/figure/presentation/gear_figure.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_set_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_set_edit_cards.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_set_members_editor.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_set_new_sitting.dart';
import 'package:submersion/features/equipment/presentation/helpers/equipment_set_clone_action.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_label.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_labels_of.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_chips.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_history_dialog.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_group_header.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';
import 'package:submersion/features/equipment/presentation/widgets/set_bundle_summary.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_creating.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_open_unlocked.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

part 'equipment_set_detail_page_creating.dart';
part 'equipment_set_detail_page_editing.dart';
part 'equipment_set_detail_page_sections.dart';

/// An equipment set's page. It opens locked and edits in place (issue #4527):
/// its cards are held in one sitting and written by one Save.
class EquipmentSetDetailPage extends ConsumerStatefulWidget {
  final String setId;

  /// Opens unlocked, as the old edit address asks (`?mode=edit`).
  final bool openUnlocked;

  /// Told when a sitting the page opened unlocked ends: the sets pane's
  /// edit returns to the set in view.
  final VoidCallback? onSittingEnded;

  /// A new set, or a clone of [cloneFromId] (issue #4527, phase 3, plan
  /// 11): the page opened unlocked on a set not yet created.
  final ({String? cloneFromId})? newSet;

  const EquipmentSetDetailPage({
    super.key,
    required this.setId,
    this.openUnlocked = false,
    this.onSittingEnded,
  }) : newSet = null;

  /// A new set's page.
  const EquipmentSetDetailPage.newSet({super.key, String? cloneFromId})
    : newSet = (cloneFromId: cloneFromId),
      setId = '',
      openUnlocked = false,
      onSittingEnded = null;

  @override
  ConsumerState<EquipmentSetDetailPage> createState() =>
      _EquipmentSetDetailPageState();
}

class _EquipmentSetDetailPageState extends ConsumerState<EquipmentSetDetailPage>
    with
        FigureSelection<EquipmentSetDetailPage>,
        RecordEditHost<EquipmentSetDetailPage, EquipmentSet>,
        RecordOpenUnlocked<EquipmentSetDetailPage, EquipmentSet>,
        _EquipmentSetDetailPageEditing,
        _EquipmentSetDetailPageSections,
        RecordCreating<EquipmentSetDetailPage, EquipmentSet>,
        _EquipmentSetDetailPageCreating {
  /// The menu value that clones the set (issue #2156).
  static const _cloneAction = 'clone';

  /// The composed figure, reused by rebuilds that change none of its
  /// inputs (the highlight flash, for one), so the painter is not handed a
  /// new model and does not repaint.
  @override
  final _memo = FigureModelMemo();

  String get setId => widget.setId;

  @override
  void dispose() {
    disposeEditing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isCreating) {
      _dropCloneOnProfileSwitch();
      final seed = newRecordSeed;
      return newRecordWaiting(context) ??
          _buildContent(context, shownRecord(seed!), seed);
    }
    final setAsync = ref.watch(equipmentSetProvider(setId));
    followStored(equipmentSetProvider(setId));

    return setAsync.when(
      data: (set) {
        if (set == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.equipment_setDetail_notFoundTitle),
            ),
            body: Center(
              child: Text(context.l10n.equipment_setDetail_notFoundMessage),
            ),
          );
        }
        openUnlockedOnce(set);
        return _buildContent(context, shownRecord(set), set);
      },
      loading: () => Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.equipment_setDetail_loadingTitle),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.equipment_setDetail_errorTitle),
        ),
        body: Center(
          child: Text(context.l10n.equipment_setDetail_errorMessage('$error')),
        ),
      ),
    );
  }
}
