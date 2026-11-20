import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_new_sitting.dart';
import 'package:submersion/features/equipment/presentation/helpers/saved_equipment_visibility.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/query/presentation/providers/query_cache_awaits.dart';
import 'package:submersion/features/query/presentation/providers/query_id_set_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/open_new_record.dart';

final _log = LoggerService.forClass(EquipmentDetailPage);

/// Where the old gear item edit address (`/equipment/<id>/edit`) goes
/// (issue #4527, phase 3, plan 6): the item's page opened unlocked.
String gearItemEditLocation(String equipmentId) =>
    '/equipment/$equipmentId?mode=edit';

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
/// table mode's `editBuilder`: the item's page opened unlocked, back to the
/// item in view mode ([onCancel]) once its sitting ends. [onSaved] is the
/// scaffold's, and unused: a sitting saves in place.
Widget gearItemEditPane(
  BuildContext context,
  String id,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  VoidCallback? onDeleted,
}) => EquipmentDetailPage(
  equipmentId: id,
  embedded: true,
  openUnlocked: true,
  onSittingEnded: onCancel,
  // A delete from the pane returns it to the list, as from view mode.
  onDeleted: onDeleted,
);

/// After a Save in the list's pane, says so when the list's view no longer
/// shows item [equipmentId] of [status] and offers the view that does (#3068):
/// an item the list hides seemed not to have saved at all. A check that fails
/// says the item was updated instead.
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

/// The new-item address (`/equipment/new`, with `type`, `serial`, `parent`
/// and `cloneFrom` in [query]; issue #4527, phase 3, plan 11): the item
/// page opened unlocked on a new item or a clone.
Widget newGearItemPage(Map<String, String> query) =>
    EquipmentDetailPage.newItem(request: NewGearItemRequest.fromQuery(query));

/// The gear list's new-item pane (`?mode=new`), as the master-detail
/// scaffold's `createBuilder`: the item page on a new item, whose created
/// id is handed to [onSaved].
Widget newGearItemPane(
  BuildContext context,
  void Function(String savedId) onSaved,
  VoidCallback onCancel,
) => EquipmentDetailPage.newItem(
  embedded: true,
  onCreated: onSaved,
  onCreateCancelled: onCancel,
);

/// Opens a new item from the gear list on a phone, in table mode or from
/// its empty state: the item opens, locked, once created, as a new site
/// does (plan 11, Question 3).
Future<void> openNewGearItem(BuildContext context) => openNewRecord(
  context,
  newLocation: '/equipment/new',
  recordLocation: (id) => '/equipment/$id',
);
