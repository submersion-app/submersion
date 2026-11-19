import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/helpers/saved_equipment_visibility.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_cache_awaits.dart';
import 'package:submersion/features/query/presentation/providers/query_id_set_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/unlock_record_editing_flag.dart';

final _log = LoggerService.forClass(EquipmentDetailPage);

/// Where the old gear item edit address (`/equipment/<id>/edit`) goes
/// (issue #4527, phase 3, plan 6): with [unlockEditing], the item's page
/// opened unlocked; null, keeping the edit form, otherwise.
String? gearItemEditLocation(
  String equipmentId, {
  bool unlockEditing = kUnlockRecordEditing,
}) => unlockEditing ? '/equipment/$equipmentId?mode=edit' : null;

/// The edit route's redirect: [gearItemEditLocation] for its address.
String? gearItemEditRedirect(BuildContext context, GoRouterState state) =>
    gearItemEditLocation(state.pathParameters['equipmentId']!);

/// Where a wide screen shows item [equipmentId]: the list with it selected,
/// in its pane, unlocked when [openUnlocked].
String gearItemPaneLocation(String equipmentId, {bool openUnlocked = false}) =>
    openUnlocked
    ? '/equipment?selected=$equipmentId&mode=edit'
    : '/equipment?selected=$equipmentId';

/// The equipment list's edit pane, as the master-detail scaffold's and
/// table mode's `editBuilder`: with [unlockEditing], the item's page opened
/// unlocked, back to the item in view mode ([onCancel]) once its sitting
/// ends; else the edit form as before.
Widget gearItemEditPane(
  BuildContext context,
  String id,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  VoidCallback? onDeleted,
  bool unlockEditing = kUnlockRecordEditing,
}) {
  if (unlockEditing) {
    return EquipmentDetailPage(
      equipmentId: id,
      embedded: true,
      unlockEditing: unlockEditing,
      openUnlocked: true,
      onSittingEnded: onCancel,
      // A delete from the pane returns it to the list, as from view mode.
      onDeleted: onDeleted,
    );
  }
  return EquipmentEditPage(
    equipmentId: id,
    embedded: true,
    onSaved: onSaved,
    onCancel: onCancel,
  );
}

/// After a Save in the list's pane, says so when the list's view no longer
/// shows item [equipmentId] of [status] and offers the view that does, as
/// the edit form does (#3068): an item the list hides seemed not to have
/// saved at all. A check that fails says the item was updated instead.
///
/// Runs on [container] and [messenger], taken before the Save ended the
/// pane's sitting: the pane's page is replaced as it ends, so its own ref
/// may be gone before the check answers.
Future<void> offerViewRevealingSavedItem({
  required ScaffoldMessengerState messenger,
  required AppLocalizations l10n,
  required ProviderContainer container,
  required String equipmentId,
  required EquipmentStatus status,
}) async {
  final filterNotifier = container.read(equipmentFilterProvider.notifier);
  final highlightNotifier = container.read(
    highlightedEquipmentIdProvider.notifier,
  );
  try {
    final view = await viewRevealingSavedEquipment(
      runner: container.read(queryIdSetRunnerProvider),
      filter: container.read(effectiveEquipmentFilterProvider),
      diverId: await container.read(validatedCurrentDiverIdProvider.future),
      equipmentId: equipmentId,
      status: status,
      beforeQuery: (tables) =>
          awaitQueryCachesIfReadFromContainer(container, tables),
      defaultStatuses: container.read(equipmentDefaultStatusesProvider),
    );
    if (view == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.equipment_edit_snackbar_hiddenByView),
        persist: false,
        action: SnackBarAction(
          label: l10n.equipment_edit_snackbar_showAction,
          onPressed: () {
            filterNotifier.state = view;
            highlightNotifier.state = equipmentId;
          },
        ),
      ),
    );
  } catch (e, st) {
    _log.error(
      "Failed to check the saved item's visibility",
      error: e,
      stackTrace: st,
    );
    // The item is saved: a failed check cannot vouch for the list, so it
    // confirms in words.
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.equipment_edit_snackbar_updated)),
    );
  }
}
