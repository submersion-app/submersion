import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/change_log/presentation/widgets/change_log_history_menu_item.dart';
import 'package:submersion/features/equipment/data/services/equipment_set_edit_save_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
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
import 'package:submersion/features/equipment/presentation/widgets/equipment_group_header.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';
import 'package:submersion/features/equipment/presentation/widgets/set_bundle_summary.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_open_unlocked.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';
import 'package:submersion/shared/widgets/record_editing/unlock_record_editing_flag.dart';

part 'equipment_set_detail_page_editing.dart';
part 'equipment_set_detail_page_sections.dart';

/// An equipment set's page. Behind phase 3's switch ([unlockEditing]) it
/// opens locked and edits in place (issue #4527): its cards are held in one
/// sitting and written by one Save.
class EquipmentSetDetailPage extends ConsumerStatefulWidget {
  final String setId;

  /// Whether the page edits in place: phase 3's switch, a parameter so a
  /// test can turn it on.
  final bool unlockEditing;

  /// Opens unlocked, as the old edit address asks (`?mode=edit`).
  final bool openUnlocked;

  /// Told when a sitting the page opened unlocked ends: the sets pane's
  /// edit returns to the set in view.
  final VoidCallback? onSittingEnded;

  const EquipmentSetDetailPage({
    super.key,
    required this.setId,
    this.unlockEditing = kUnlockRecordEditing,
    this.openUnlocked = false,
    this.onSittingEnded,
  });

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
        _EquipmentSetDetailPageSections {
  /// The menu value that shows or hides the diver figure, shared by the menu
  /// item and its handler so the two cannot drift apart.
  static const _toggleFigureAction = 'toggleFigure';

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
    final setAsync = ref.watch(equipmentSetProvider(setId));
    if (hostsEditing) followStored(equipmentSetProvider(setId));

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
        if (!hostsEditing) return _buildContent(context, set, set);
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
