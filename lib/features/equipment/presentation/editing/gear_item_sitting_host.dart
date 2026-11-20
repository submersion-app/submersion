import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/write_fill_to_tag.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/dive_computer/presentation/editing/dive_computer_settings_sitting.dart';
import 'package:submersion/features/dive_computer/presentation/providers/clock_sync_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/editing/record_document_links_sitting.dart';
import 'package:submersion/features/equipment/data/services/gear_item_edit_save_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_shares_sharing_adapter.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_check_ins_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_components_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_fills_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_findings_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_header_editor.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_location_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_media_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_passport_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_service_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_sharing_sitting.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_share_providers.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';

/// What a sitting on a gear item loads and how it is saved, for every page
/// that holds one: the item page and its passports (issue #4527, phase 3).
/// A passport opened alone saves exactly as the item page does, as one
/// History entry on the item.
mixin GearItemSittingHost<W extends ConsumerStatefulWidget>
    on ConsumerState<W>, RecordEditHost<W, EquipmentItem> {
  @override
  String recordIdOf(EquipmentItem record) => record.id;

  @override
  EquipmentItem? get storedForUnlock =>
      ref.read(equipmentItemProvider(hostRecordId)).value;

  @override
  String editingTitle(EquipmentItem record) =>
      context.l10n.recordEdit_editingTitle(record.name);

  @override
  void onSittingStart(
    EditSession<EquipmentItem> session,
    ProviderContainer container,
  ) => loadGearItemSitting(session, container);

  /// Told once a sitting this page saved is written, before the follow-ups
  /// run; [after] is null when the item's row did not change. The page may
  /// be gone by then: check `mounted` before using its context.
  void onGearItemSaved(
    EditSession<EquipmentItem> session,
    EquipmentItem? after,
    ProviderContainer container,
  ) {}

  /// Writes the sitting through the item's save service: its changed values
  /// and its held writes, in one transaction and one History entry. Then
  /// what the list notifier does after a write today ([afterGearItemSave]).
  @override
  Future<void> saveSitting(EditSession<EquipmentItem> session) async {
    // Read before the write: the page can be gone by the time it is done.
    final service = ref.read(gearItemEditSaveServiceProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    // Read now: the sitting ends with the Save.
    final clockSync = heldClockSync(session);
    final changedCards = session.changedCardIds;
    final loggedFills = newFillsOf(session);
    // A failed write takes back what the media write did outside the
    // database.
    final result = await undoMediaOnFailure(
      session,
      () => service.save(
        // The item the sitting was opened on, whatever the page shows by
        // the time the write is asked for.
        equipmentId: session.stored.id,
        apply: (stored) => gearItemToSave(stored, session.applyTo(stored)),
        changedCardIds: session.changedCardIds,
        alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
        alsoWriteIsAChange: session.hasHeldChanges,
      ),
    );
    justSavedRecord = result?.after ?? session.working;
    onGearItemSaved(session, result?.after, container);
    // A fill logged in the sitting is offered for the cylinder's tag once
    // it is stored, never before: a Cancel would leave it on the tag only.
    // The newest one (the list is newest first), read back so a twin fill
    // offers its partner's tag too.
    // Best effort, as the other steps after a save: a failure is logged.
    if (loggedFills.isNotEmpty && mounted) {
      logFailure(
        _offerLoggedFill(
          loggedFills.first.id,
          equipmentId: session.stored.id,
          fills: ref.read(cylinderFillRepositoryProvider),
        ),
        GearItemSittingHost,
        'offer the logged fill for its tag',
      );
    }
    afterGearItemSave(
      container,
      equipmentId: session.stored.id,
      before: result?.before,
      after: result?.after,
      clockSync: clockSync,
      afterCommit: gearItemAfterCommit(session),
      changedCardIds: changedCards,
    );
  }

  /// Offers to write the stored fill [fillId] (and its twin partner's) to
  /// the tags, as logging it outside a sitting does.
  Future<void> _offerLoggedFill(
    String fillId, {
    required String equipmentId,
    required CylinderFillRepository fills,
  }) async {
    final logged = await savedLoggedFill(fills, fillId);
    if (logged == null || !mounted) return;
    await offerWriteFillsToTags(context, ref, logged, equipmentId: equipmentId);
  }

  @override
  Future<EquipmentItem?> rereadStored(
    ProviderContainer container,
    EquipmentItem stored,
  ) {
    container.invalidate(equipmentItemProvider(stored.id));
    return container.read(equipmentItemProvider(stored.id).future);
  }
}

/// Reads what the cards hold beside the item's own values, so they show the
/// sitting's rows once they change; the documents attached and detached in
/// the sitting are filed under the item.
void loadGearItemSitting(
  EditSession<EquipmentItem> session,
  ProviderContainer container,
) {
  gearItemTagsList.load(session);
  gearItemMovesList.load(session);
  gearItemClocksList.load(session);
  gearItemServiceRecordsList.load(session);
  // Who it is shared with, for an item with an owner. Read whether or not
  // the profiles are known yet: the sharing row shows once they are, and a
  // choice made there must find the sharing read.
  if (session.stored.diverId != null) {
    gearItemSharing.load(
      session,
      EquipmentSharesSharingAdapter(
        container.read(equipmentShareRepositoryProvider),
      ),
      actingDiverId: container.read(validatedCurrentDiverIdProvider).value,
      // A new item is shared with no one: gear has no sharing default.
      newRecordSharing: session.isNew ? const <String>{} : null,
    );
  }
  holdDocumentLinks(
    session,
    container.read,
    owner: DocumentOwner(DocumentOwnerKind.equipment, session.stored.id),
    cardId: GearItemCardId.documents.name,
  );
  // The photos, the older linked files and the check-ins' photos are
  // written with the container's readers, which outlive the page.
  final writers = SittingMediaWriters.forEquipment(container.read);
  holdSittingMedia(session, writers, cardId: GearItemCardId.photos.name);
  holdLegacyFiles(session, writers);
  holdCheckIns(session, writers);
  gearItemCheckInsList.load(session);
  holdFindingDismissals(session, container.read);
  holdGearItemComponents(session, container.read);
  gearItemTripsList.load(session);
  loadGearItemFills(session);
}

/// Reads what a passport's cards hold, for a passport that holds a sitting
/// of its own: its clocks (and the service records Log service adds to),
/// moves, trips and fills. The item page's other lists stay unread; their
/// held writes are never made from a passport. A passport that joins the
/// item page's sitting uses what the item page read.
void loadGearPassportSitting(EditSession<EquipmentItem> session) {
  gearItemClocksList.load(session);
  gearItemServiceRecordsList.load(session);
  gearItemMovesList.load(session);
  gearItemTripsList.load(session);
  loadGearItemFills(session);
}

/// What a saved sitting still has to do outside the database: uploads and
/// the remote deletes the unlinks held. Read before the follow-ups run.
List<Future<void> Function()> gearItemAfterCommit(
  EditSession<EquipmentItem> session,
) => [
  ...mediaAfterCommit(session),
  ...legacyFilesAfterCommit(session),
  ...checkInsAfterCommit(session),
  ...componentsAfterCommit(session),
];

/// What the list notifier does after it writes an item today, done once a
/// sitting on item [equipmentId] has been saved (issue #4527, phase 3, plan
/// 6): the lists and the clocks refreshed, the service reminders
/// rescheduled, and the dives a transmitter item's registry entries match
/// rescanned when its serial changed. [before] and [after] are null when the
/// row did not change.
///
/// [clockSync], a dive computer's clock sync choice the sitting held, is
/// written here, once the sitting has committed: it lives in this
/// installation's preferences, outside the database and its History.
///
/// The sitting is saved by now, so each step is best effort: one that fails
/// is logged, never reported as the Save failing.
void afterGearItemSave(
  ProviderContainer container, {
  required String equipmentId,
  EquipmentItem? before,
  EquipmentItem? after,
  HeldClockSync? clockSync,
  List<Future<void> Function()> afterCommit = const [],
  Set<String> changedCardIds = const {},
}) {
  void bestEffort(Future<void> Function() work, String task) =>
      logFailure(Future.sync(work), GearItemSittingHost, task);

  for (final step in afterCommit) {
    bestEffort(step, 'a follow-up after a save');
  }

  if (clockSync != null) {
    bestEffort(
      () => container
          .read(clockSyncSettingsNotifierProvider.notifier)
          .setOverride(clockSync.computerId, clockSync.value),
      'write the held clock sync choice',
    );
  }
  // The item, its computer, clocks, photos, files and check-ins need no
  // invalidation here: each of their providers refreshes itself when its
  // table changes, so one here would only read it twice.
  if (before != null &&
      after != null &&
      before.serialNumber != after.serialNumber) {
    bestEffort(
      () => container
          .read(transmitterRepositoryProvider)
          .rescanDivesForTransmitterItem(equipmentId),
      'rescan dives for the transmitter item',
    );
  }
  // The service reminders follow the clocks, the records, the item's own
  // reminder days and its dates (Details): rescheduled when one of those
  // cards changed, not on every Save.
  if (changedCardIds.any(_serviceCards.contains)) {
    bestEffort(
      () => container
          .read(serviceRecordNotifierProvider(equipmentId).notifier)
          .refresh(),
      'reschedule service reminders after a save',
    );
  }
  bestEffort(
    () => container.read(equipmentListNotifierProvider.notifier).refresh(),
    'refresh the equipment lists after a save',
  );
}

/// The cards whose changes move the item's service reminders.
final Set<String> _serviceCards = {
  GearItemCardId.serviceClocks.name,
  GearItemCardId.serviceHistory.name,
  GearItemCardId.details.name,
};
