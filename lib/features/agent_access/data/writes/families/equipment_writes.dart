import 'package:drift/drift.dart' show QueryRow, Variable;

import 'package:submersion/core/constants/enums.dart'
    show EquipmentStatus, EquipmentType;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/equipment_item_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
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
    'custom_reminder_enabled': const FieldCodec.flag(),
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
  };

  @override
  Set<String> get requiredOnCreate => const {'name', 'type'};

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
      'is_active follows status; last_service_date and '
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
    };
  }

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    final links = await _tagBlock(check) ?? _shareBlock(check);
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
    final parent = await _r.equipment.getEquipmentById(parentId);
    return parentProblem(type, parent, check.id);
  }

  @override
  Future<Map<String, int>> alsoCreates(
    String diverId,
    Map<String, Object?> values,
  ) async {
    final kinds = await ServiceScheduleRepository().autoAttachKindsFor(
      type: EquipmentType.values.byName(values['type']! as String),
      diverId: diverId,
    );
    return {if (kinds.isNotEmpty) 'service_schedules': kinds.length};
  }

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async {
    final current = await _r.equipment.getEquipmentById(id);
    if (current == null) return const SideEffects();
    final next = nextItem(current, update.values);
    return SideEffects(
      fields: derivedFields(current, next, update.values),
      touched: await touchedBy(current, next),
    );
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final blank = EquipmentItem(
      id: '',
      diverId: diverId,
      name: values['name']! as String,
      type: EquipmentType.values.byName(values['type']! as String),
      status: EquipmentStatus.active,
      purchaseCurrency:
          values['purchase_currency'] as String? ??
          await _defaultCurrency(diverId),
    );
    return (await _r.equipment.createEquipment(nextItem(blank, values))).id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    if (update.values.isNotEmpty) {
      final current =
          await _r.equipment.getEquipmentById(id) ??
          (throw AgentToolException(
            AgentToolErrorCode.writeRefused,
            'Equipment $id no longer exists.',
            details: {'id': id},
          ));
      await _r.equipment.updateEquipment(nextItem(current, update.values));
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

  /// Every agent write acts as the record's owner, so the owner's delete.
  @override
  Future<void> delete(String id, String? ownerId) async {
    await _r.equipment.deleteOwnedEquipment(
      id,
      actingDiverId: ownerId,
      // A revert restores the rows, and its media needs the blobs still there.
      holdRemoteMedia: true,
    );
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

  /// The currency a new item takes when none is named: the diver's default,
  /// as the edit page starts one.
  Future<String> _defaultCurrency(String diverId) async {
    final row = await DatabaseService.instance.database
        .customSelect(
          'SELECT default_currency FROM diver_settings WHERE diver_id = ?',
          variables: [Variable.withString(diverId)],
        )
        .getSingleOrNull();
    final code = (row?.read<String?>('default_currency') ?? '')
        .trim()
        .toUpperCase();
    return code.isEmpty ? 'USD' : code;
  }
}
