import 'package:drift/drift.dart' show QueryRow, Variable;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/enums.dart'
    show EquipmentStatus, EquipmentType;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/equipment_item_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/equipment_passport_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/equipment_replace_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/service_ledger_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_computer/data/clock_sync_preferences.dart';
import 'package:submersion/features/documents/domain/entities/document.dart'
    show DocumentOwner, DocumentOwnerKind;
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart'
    show TagScope;

/// Gear items, through the repository the equipment edit page uses, saved
/// whole as the page saves them. Status decides whether an item is in the
/// kit; a type change drops the attributes and the fitting the new type has
/// no place for; and a save says what it does to service clocks and devices.
class EquipmentWrites extends WritableEntry {
  EquipmentWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'equipment';

  @override
  String get table => 'equipment';

  @override
  late final Map<String, FieldCodec> fields = {
    'name': const FieldCodec.text(maxLength: 100, trim: true),
    'type': FieldCodec.enumName(EquipmentType.values),
    for (final key in const ['brand', 'model', 'serial_number'])
      key: const FieldCodec.text(maxLength: 100, nullable: true, trim: true),
    'status': FieldCodec.enumName(EquipmentStatus.values),
    'purchase_date': const FieldCodec.calendarDate(nullable: true),
    'purchase_price': const FieldCodec.number(
      min: 0,
      max: 10000000,
      nullable: true,
    ),
    'purchase_currency': const FieldCodec.text(maxLength: 3, trim: true),
    'notes': const FieldCodec.text(allowBlank: true, trim: true),
    'custom_reminder_enabled': const FieldCodec.flag(nullable: true),
    'custom_reminder_days': const FieldCodec.integerList(
      min: 1,
      max: 365,
      maxItems: 10,
    ),
    'parent_equipment_id': const FieldCodec.reference(
      'equipment',
      nullable: true,
    ),
    'attributes': attributeListCodec,
    replacesKey: const FieldCodec.reference('equipment'),
    passportKey: const FieldCodec.text(maxLength: 36, trim: true),
  };

  /// A new item names [newItemKeys] unless it replaces a part, which
  /// [replacementProblem] judges.
  @override
  Set<String> get requiredOnCreate => const {};

  @override
  final Map<String, RelationSpec> relations = const {
    'tags': RelationSpec(refEntity: 'tags'),
    'shared_with': RelationSpec(refEntity: 'divers'),
  };

  @override
  Future<Set<String>> currentRelation(String id, String relation) async {
    final (table, column, key) = switch (relation) {
      'tags' => (
        TagScope.equipment.table.junctionTable,
        'tag_id',
        TagScope.equipment.table.parentColumn,
      ),
      _ => ('equipment_shares', 'diver_id', 'equipment_id'),
    };
    final rows = await DatabaseService.instance.database
        .customSelect(
          'SELECT "$column" AS linked FROM "$table" WHERE "$key" = ?',
          variables: [Variable.withString(id)],
        )
        .get();
    return {for (final row in rows) row.read<String>('linked')};
  }

  @override
  String? titleOf(Map<String, Object?> document) => document['name'] as String?;

  @override
  String get note =>
      'a create names name and type, or only replaces_equipment_id to '
      'replace a fitted part (the new one copies it, the old one retires); '
      'custom_reminder_enabled true uses custom_reminder_days (some of 7, '
      '14 and 30; all three when none are named), null the app\'s default '
      'reminders; is_active follows status; last_service_date and '
      'service_interval_days are legacy and not writable; attributes are '
      'the whole list, built-in keys of the item\'s type plus custom ones '
      '(is_custom true), the app\'s own system keys left out';

  /// The attributes as the plan compares them: the app's system keys left
  /// out, built-in ones by key, custom ones in the diver's order.
  @override
  Future<Map<String, Object?>> stored(
    String id,
    Map<String, Object?> document,
  ) async {
    final item = await _r.equipment.getEquipmentById(id);
    return {
      ...document,
      'attributes': item == null ? const [] : attributeDocuments(item),
      passportKey: item == null ? null : passportOf(item),
    };
  }

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    final replacement = await replacementProblem(
      check,
      _r.equipment.getEquipmentById,
    );
    if (replacement != null || check.values.containsKey(replacesKey)) {
      return replacement;
    }
    if (await passportProblem(check, _r) case final block?) return block;
    final links =
        await _tagBlock(check) ?? _shareBlock(check) ?? reminderProblem(check);
    if (links != null) return links;
    final type = EquipmentType.values.byName(
      check.values['type'] as String? ?? check.document!['type']! as String,
    );
    if (check.values['attributes'] case final String attributes) {
      final problem = attributeProblem(attributes, type);
      if (problem != null) return PlanBlock(BlockReason.invalidValue, problem);
    }
    final parentId = check.values.containsKey('parent_equipment_id')
        ? check.values['parent_equipment_id'] as String?
        : null;
    if (parentId == null) return null;
    final parent = await _parentAsSoFar(parentId, check.soFar);
    final status =
        check.values['status'] as String? ??
        check.document?['status'] as String?;
    return parentProblem(
      type,
      parent,
      check.id,
      wanted: status == EquipmentStatus.wanted.name,
    );
  }

  /// [current] with [values] applied, with the item it is then fitted to as
  /// the changes [soFar] lists leave it.
  Future<EquipmentItem> _next(
    EquipmentItem current,
    Map<String, Object?> values, {
    SetSoFar soFar = const SetSoFar(),
  }) async {
    final parentId = values.containsKey('parent_equipment_id')
        ? values['parent_equipment_id'] as String?
        : current.parentEquipmentId;
    return nextItem(
      current,
      values,
      parent: parentId == null ? null : await _parentAsSoFar(parentId, soFar),
    );
  }

  /// Item [id] with the status and type a change earlier in the set writes,
  /// as the apply finds it when it saves a part after its parent.
  Future<EquipmentItem?> _parentAsSoFar(String id, SetSoFar soFar) async {
    final stored = await _r.equipment.getEquipmentById(id);
    if (stored == null) return null;
    final type = soFar.values[('equipment', id)]?['type'];
    return stored.copyWith(
      isActive: inKitSoFar(soFar, id, stored: stored.isActive),
      type: type is String ? EquipmentType.values.byName(type) : null,
    );
  }

  @override
  Future<Map<String, int>> alsoCreates(
    String diverId,
    Map<String, Object?> values,
  ) async {
    final replaced = values[replacesKey] as String?;
    final old = replaced == null
        ? null
        : await _r.equipment.getEquipmentById(replaced);
    final kinds = await ServiceScheduleRepository().autoAttachKindsFor(
      type: old?.type ?? EquipmentType.values.byName(values['type']! as String),
      diverId: old?.diverId ?? diverId,
    );
    return {if (kinds.isNotEmpty) 'service_schedules': kinds.length};
  }

  /// A part is replaced once, so two replacements of it in a set cannot
  /// both pass.
  @override
  UniqueClaim? uniqueKey(WriteCheck check) =>
      switch (check.values[replacesKey]) {
        final String oldId when check.kind == ChangeKind.create => UniqueClaim(
          'replace/$oldId',
        ),
        _ => null,
      };

  /// A replacement's claim, and a passport id's: one tag on one item of a
  /// profile, as the store holds it, so a second item given the same id in
  /// the set is refused here rather than at apply.
  @override
  List<UniqueClaim> uniqueKeys(WriteCheck check) => [
    ?uniqueKey(check),
    if (check.values[passportKey] case final String passport)
      UniqueClaim('passport/$passport'),
  ];

  /// The currency the edit page starts a new item in, listed in the plan.
  @override
  Future<Map<String, Object?>> createDefaults(
    String diverId,
    Map<String, Object?> values,
  ) async => values.containsKey(replacesKey)
      ? const {}
      : {'purchase_currency': await defaultCurrencyOf(diverId)};

  /// A replacement retires the part it replaces.
  @override
  Future<Map<String, int>> createTouched(
    String diverId,
    Map<String, Object?> values,
  ) async =>
      values.containsKey(replacesKey) ? const {'equipment': 1} : const {};

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async {
    final current = await _r.equipment.getEquipmentById(id);
    if (current == null) return const SideEffects();
    // Each share and unshare writes an event to the item's ownership log.
    var events = 0;
    if (update.relations['shared_with'] case final shares?) {
      final now = await currentRelation(id, 'shared_with');
      events =
          shares.add.difference(now).length +
          shares.remove.intersection(now).length;
    }
    final passport = update.values[passportKey] as String?;
    final logged = {
      if (events > 0) 'equipment_ownership_events': events,
      if (passport != null)
        ...await passportTouched(id, passport, passportOf(current)),
    };
    // Only a field change saves the item, so a change of tags, shares or
    // the passport alone derives nothing and renames no device.
    final values = _itemValues(update.values);
    if (values.isEmpty) return SideEffects(touched: logged);
    final next = await _next(current, values, soFar: update.soFar);
    return SideEffects(
      fields: derivedFields(current, next, values),
      touched: {...await touchedBy(current, next), ...logged},
    );
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    if (values[replacesKey] case final String oldId) {
      final old =
          await _r.equipment.getEquipmentById(oldId) ??
          (throw AgentToolException(
            AgentToolErrorCode.writeRefused,
            'Equipment $oldId no longer exists.',
            details: {'id': oldId},
          ));
      return (await _r.equipment.replaceChild(old)).id;
    }
    final blank = EquipmentItem(
      id: '',
      diverId: diverId,
      name: values['name']! as String,
      type: EquipmentType.values.byName(values['type']! as String),
      status: EquipmentStatus.active,
      purchaseCurrency:
          values['purchase_currency'] as String? ??
          await defaultCurrencyOf(diverId),
    );
    final id = (await _r.equipment.createEquipment(
      await _next(blank, _itemValues(values)),
    )).id;
    if (values[passportKey] case final String passport) {
      await _r.cylinderPassports.assignPassportId(
        equipmentId: id,
        passportId: passport,
        diverId: diverId,
      );
    }
    return id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final values = _itemValues(update.values);
    if (values.isNotEmpty) {
      final current =
          await _r.equipment.getEquipmentById(id) ??
          (throw AgentToolException(
            AgentToolErrorCode.writeRefused,
            'Equipment $id no longer exists.',
            details: {'id': id},
          ));
      await _r.equipment.updateEquipment(await _next(current, values));
    }
    if (update.values[passportKey] case final String passport) {
      await _r.cylinderPassports.assignPassportId(
        equipmentId: id,
        passportId: passport,
        diverId: ownerId,
      );
    }
    // Tags and shares as the edit page and the share checklist save them,
    // the whole new list at once.
    if (update.relations['tags'] case final tags? when !tags.isEmpty) {
      final now = await currentRelation(id, 'tags');
      await _r.equipmentTags.replaceTags(id, [
        ...now.difference(tags.remove),
        ...tags.add,
      ]);
    }
    if (update.relations['shared_with'] case final shares?
        when !shares.isEmpty) {
      final now = await currentRelation(id, 'shared_with');
      await _r.equipmentShares.setShares(
        equipmentId: id,
        diverIds: {...now.difference(shares.remove), ...shares.add},
        actingDiverId: ownerId!,
      );
    }
  }

  /// A block for a tag the edit page would not offer: one not used for
  /// equipment, as a change earlier in the set leaves it.
  Future<PlanBlock?> _tagBlock(WriteCheck check) async {
    final added = check.relations['tags']?.add ?? const <String>{};
    if (added.isEmpty) return null;
    final rows = await DatabaseService.instance.database
        .customSelect(
          'SELECT id, applies_to_equipment FROM tags WHERE id IN '
          '(${List.filled(added.length, '?').join(', ')})',
          variables: [for (final id in added) Variable.withString(id)],
        )
        .get();
    bool forGear(QueryRow row) => switch (check.soFar.values[(
      'tags',
      row.read<String>('id'),
    )]?['scopes']) {
      final String scopes => scopes.split(',').contains('equipment'),
      _ => row.read<bool>('applies_to_equipment'),
    };
    final other = [
      for (final row in rows)
        if (!forGear(row)) row.read<String>('id'),
    ];
    if (other.isEmpty) return null;
    return PlanBlock(
      BlockReason.invalidValue,
      'tags: ${other.join(', ')} is not used for equipment. Add equipment to '
      'its scopes first.',
    );
  }

  /// A block for a share the share checklist refuses: an item with no owner
  /// has no one to share it, and its owner holds it already.
  PlanBlock? _shareBlock(WriteCheck check) {
    final shares = check.relations['shared_with'];
    if (shares == null || shares.isEmpty) return null;
    final owner = check.ownerId;
    if (owner == null) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'shared_with: an item with no owner has no one to share it.',
      );
    }
    if (shares.add.contains(owner)) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'shared_with: an item is its owner\'s already.',
      );
    }
    return null;
  }

  /// A transmitter item's serial feeds the stored gear-serial mismatch
  /// finding (issue #3367), so its dives are rescanned, as the edit page's
  /// save does.
  @override
  Future<void> afterApply(List<AppliedChange> changes, ApplyRun run) async {
    for (final change in changes) {
      if (change.kind == ChangeKind.update &&
          change.changed.contains('serial_number')) {
        await _r.transmitters.rescanDivesForTransmitterItem(change.id);
      }
    }
  }

  /// Every agent write acts as the record's owner, so the owner's delete.
  /// A computer's item takes the computer with it, so this install's clock
  /// sync choice for it goes too, as the equipment page's delete forgets it.
  @override
  Future<void> delete(String id, String? ownerId) async {
    final computers = await _r.computers.getComputersForEquipment(id);
    await _r.equipment.deleteOwnedEquipment(
      id,
      actingDiverId: ownerId,
      // A revert restores the rows, and its media needs the blobs still there.
      holdRemoteMedia: true,
    );
    if (computers.isEmpty) return;
    final clockSync = ClockSyncPreferences(
      await SharedPreferences.getInstance(),
    );
    for (final computer in computers) {
      await clockSync.forget(computer.id);
    }
  }

  @override
  Future<List<DocumentOwner>> deletedDocumentOwners(String id) async => [
    DocumentOwner(DocumentOwnerKind.equipment, id),
  ];

  /// What a delete takes: its clocks, records, parts, moves and shares
  /// cascade; the dive computer or transmitter it is the one entry for
  /// goes through its own repository; fills, cylinders and the rest lose
  /// their link.
  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async {
    final documents = await countDocuments(await deletedDocumentOwners(id));
    // A photo only of the item goes; one a dive or site also holds stays.
    final media = await _r.media.partitionMediaForEquipmentDeletion([id]);
    final computers = await countRows(
      'dive_computers',
      'equipment_id = ?1',
      id,
    );
    final keys = await countRows(
      'transmitters',
      'transmitter_equipment_id = ?1',
      id,
    );
    final cylinderKeys = await countRows(
      'transmitters',
      'equipment_id = ?1 AND (transmitter_equipment_id IS NULL '
          'OR transmitter_equipment_id != ?1)',
      id,
    );
    return DeleteReach(
      records: {
        if (documents > 0) 'documents': documents,
        if (computers > 0) 'dive_computers': computers,
        if (keys > 0) 'transmitters': keys,
        if (media.doomed.isNotEmpty) 'media': media.doomed.length,
      },
      parts: await countCascaded('equipment', id, except: const {'documents'}),
      unlinked: {
        ...await countUnlinked(
          'equipment',
          id,
          except: const {
            'dive_computers',
            'transmitters',
            'documents',
            'media',
          },
        ),
        if (cylinderKeys > 0) 'transmitters': cylinderKeys,
        if (media.unlinkIds.isNotEmpty) 'media': media.unlinkIds.length,
      },
    );
  }

  /// [values] without the passport id, which the tag dialog writes on its
  /// own, outside the item save.
  static Map<String, Object?> _itemValues(Map<String, Object?> values) => {
    for (final MapEntry(:key, :value) in values.entries)
      if (key != passportKey) key: value,
  };
}
