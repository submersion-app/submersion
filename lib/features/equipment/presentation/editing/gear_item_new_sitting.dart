import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/new_record_diver.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/equipment_clone_service.dart';
import 'package:submersion/features/equipment/data/services/equipment_move_flow.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_fitting.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/services/equipment_clone_seed.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_header_editor.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_location_sitting.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_clone_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_creating.dart';

/// A new gear item's sitting (issue #4527, phase 3, plan 11): what its
/// opener asks for, its seed, a clone's copy of another item, the cards
/// laid out open, and what the opener brings put on as changes.

/// What a new gear item's page was opened with: a type and a serial from
/// the dive computer and transmitter lists and the transmitter setup, the
/// item a part is fitted to (Add part), or the item to clone. Each is a
/// change of the card that shows it.
@immutable
class NewGearItemRequest {
  const NewGearItemRequest({
    this.type,
    this.serial,
    this.parentId,
    this.cloneFromId,
  });

  /// The request in `/equipment/new`'s address, as the route reads it:
  /// `type`, `serial`, `parent` and `cloneFrom`.
  factory NewGearItemRequest.fromQuery(Map<String, String> query) {
    String? text(String key) {
      final value = query[key]?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    return NewGearItemRequest(
      type: EquipmentType.values.asNameMap()[query['type']],
      serial: text('serial'),
      parentId: text('parent'),
      cloneFromId: text('cloneFrom'),
    );
  }

  final EquipmentType? type;
  final String? serial;
  final String? parentId;
  final String? cloneFromId;

  bool get isClone => cloneFromId != null;
}

/// What a clone copies from another item (issue #3184): its form seed
/// ([cloneFormSeed]), the active diver's own tags and own place among the
/// source's, and the source's id, which its extras are copied from at Save.
typedef GearCloneSource = ({
  String sourceId,
  EquipmentItem copy,
  List<Tag> ownTags,
  EquipmentLocation? ownPlace,
});

/// A new gear item's starting record under [id]: the active diver's, a
/// regulator, active, in the diver's default currency, as the form started
/// one. A diver that cannot be read leaves none, for Save to take.
Future<EquipmentItem> newGearItemSeed(
  RecordSeedRead read, {
  required String id,
}) async {
  final diverId = await newRecordDiverId(read, record: 'gear item');
  return EquipmentItem(
    id: id,
    diverId: diverId,
    name: '',
    type: EquipmentType.regulator,
    purchaseCurrency: read(defaultCurrencyProvider),
  );
}

/// Reads [itemId] for a clone named by [copyName], or null when the active
/// diver can neither own nor share it. Only the diver's own tags and place
/// come with it: cloning shared gear must not bring the owner's (#2046).
/// Tags or a place that cannot be read are left behind, as the form left
/// them: the clone still opens.
Future<GearCloneSource?> readGearClone(
  RecordSeedRead read,
  String itemId, {
  required String Function(String name) copyName,
}) async {
  final source = await read(cloneSourceProvider(itemId).future);
  if (source == null) return null;
  final diverId = await read(validatedCurrentDiverIdProvider.future);
  final tags = await _readOrNull(
    () => read(tagsForEquipmentProvider(itemId).future),
    'tags',
  );
  final place = await _readOrNull(() async {
    final places = await read(currentEquipmentLocationsProvider.future);
    final mine = await read(equipmentLocationsProvider.future);
    final place = places[itemId];
    return place != null && mine.any((l) => l.id == place.id) ? place : null;
  }, 'place');
  return (
    sourceId: itemId,
    copy: cloneFormSeed(source, copyName: copyName),
    ownTags: [
      for (final t in tags ?? const <Tag>[])
        if (isOwnOrUnowned(ownerId: t.diverId, activeDiverId: diverId)) t,
    ],
    ownPlace: place,
  );
}

/// [readValue]'s value, or null, logged, when it cannot be read.
Future<T?> _readOrNull<T>(Future<T> Function() readValue, String what) async {
  try {
    return await readValue();
  } catch (e, st) {
    const LoggerService(
      'readGearClone',
    ).warning('A clone opened without its $what', error: e, stackTrace: st);
    return null;
  }
}

/// The cards a new gear item opens with: the header block, Details and
/// Location.
final List<String> newGearItemLaidOut = List.unmodifiable([
  GearItemCardId.header.name,
  GearItemCardId.details.name,
  GearItemCardId.location.name,
]);

const _cloneExtrasKey = 'equipment.new.cloneExtras';

/// Puts what [request] or [clone] brings on [session], each through its
/// card's field, so each is a change. A clone's place is held as the
/// item's first move, as its Location card holds one, and its extras
/// (clocks without a baseline, set memberships, document copies) as one
/// write of the clone, made at Save after the row: if one fails the Save
/// fails, where the form copied them after the item, best effort (plan
/// 11, Question 8).
Future<void> applyNewGearItemPrefill(
  EditSession<EquipmentItem> session, {
  NewGearItemRequest? request,
  GearCloneSource? clone,
  required EquipmentCloneService cloneService,
}) async {
  bool gone() => session.isDisposed || session.isFrozen;
  if (gone()) return;
  if (clone != null) {
    final copy = clone.copy;
    session
      ..set(gearNameField, copy.name)
      ..set(gearTypeField, copy.type)
      ..set(gearStatusField, gearShownStatus(copy))
      ..set(gearParentField, copy.parentEquipmentId)
      ..set(gearBrandField, copy.brand)
      ..set(gearModelField, copy.model)
      ..set(gearPurchaseDateField, copy.purchaseDate)
      ..set(gearPriceField, (
        price: copy.purchasePrice,
        currency: copy.purchaseCurrency,
      ))
      ..set(gearCustomReminderField, (
        enabled: copy.customReminderEnabled,
        days: copy.customReminderDays,
      ))
      ..set(gearNotesField, copy.notes)
      ..set(gearCustomFieldsField, [
        for (final a in copy.attributes)
          if (a.isCustom) a,
      ]);
    for (final a in copy.attributes) {
      if (!a.isCustom) session.set(gearAttributeField(a.key), a);
    }
    final itemId = session.stored.id;
    // The item's first move, held as a move made on its Location card is,
    // so the card shows the place and a move made by hand replaces it.
    if (clone.ownPlace case final place?) {
      holdGearItemMove(
        session,
        HeldGearItemMove(
          pick: PlacePick(place),
          plan: EquipmentMovePlan(
            items: {itemId: session.valueOf(gearStatusField)},
            movedAt: DateTime.now(),
          ),
        ),
      );
    }
    session.holdChange(
      _cloneExtrasKey,
      cardId: GearItemCardId.details.name,
      write: () async {
        // For the diver the item was created for, which Save may have read
        // when the seed could not.
        final created = await EquipmentRepository().getEquipmentById(itemId);
        final failed = await cloneService.copyExtras(
          sourceId: clone.sourceId,
          cloneId: itemId,
          cloneType: session.working.type,
          diverId: created?.diverId ?? session.working.diverId,
        );
        if (failed.isNotEmpty) {
          throw StateError(
            'Copying ${failed.map((s) => s.name).join(', ')} to the clone '
            'failed',
          );
        }
      },
    );
    // Nothing is stored for the clone: its tags start empty, without a
    // read (which the prefill, tracked itself, must not wait for), and take
    // the source's own.
    if (clone.ownTags.isNotEmpty) {
      gearItemTagsList
        ..loadNone(session)
        ..set(session, clone.ownTags);
    }
    return;
  }
  if (request == null) return;
  if (request.type case final type?) session.set(gearTypeField, type);
  if (request.serial case final serial?) session.set(gearSerialField, serial);
  if (request.parentId case final parent?) {
    session.set(gearParentField, parent);
  }
}

/// The parent a new item of [type] is created fitted to, as the form
/// decides it at Save: [parentId] only when that item exists, takes parts,
/// is the active diver's or shared with them (#2046), and can hold [type];
/// none otherwise (a part added from a host, then made a type that host
/// cannot hold).
Future<String?> gearParentToSave(
  EquipmentRepository equipment, {
  required EquipmentType type,
  required String? parentId,
  required String? diverId,
}) async {
  if (parentId == null) return null;
  final parent = await equipment.getEquipmentById(parentId);
  if (parent == null || !parent.isFitted) return null;
  if (diverId != null && !await equipment.isVisibleTo(parentId, diverId)) {
    return null;
  }
  return parentTypesFor(type).contains(parent.type) ? parentId : null;
}
