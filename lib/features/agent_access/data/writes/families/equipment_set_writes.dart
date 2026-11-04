import 'package:drift/drift.dart' show Variable;
import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/data/writes/families/equipment_item_rules.dart';

import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/object_list_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';

/// Equipment sets, through the repository the sets page uses: members the
/// owner can use, one default per diver, the figure, and the places a set
/// applies near, replaced whole and matched by position.
class EquipmentSetWrites extends WritableEntry {
  EquipmentSetWrites(this._r);

  final RecordRepositories _r;

  static const _uuid = Uuid();

  @override
  String get name => 'equipment_sets';

  @override
  String get table => 'equipment_sets';

  @override
  late final Map<String, FieldCodec> fields = {
    'name': const FieldCodec.text(maxLength: 100, trim: true),
    'description': const FieldCodec.text(allowBlank: true, trim: true),
    'is_default': const FieldCodec.flag(),
    'auto_apply_on_computer_import': const FieldCodec.flag(),
    'show_figure': const FieldCodec.flag(),
    'geofences': const ObjectListCodec({
      'label': FieldCodec.text(maxLength: 60, nullable: true, trim: true),
      'latitude': FieldCodec.number(min: -90, max: 90),
      'longitude': FieldCodec.number(min: -180, max: 180),
      // The geofence editor's slider range.
      'radius_m': FieldCodec.number(min: 500, max: 100000),
    }, maxItems: 20),
  };

  @override
  Set<String> get requiredOnCreate => const {'name'};

  @override
  final Map<String, RelationSpec> relations = const {
    'equipment_ids': RelationSpec(refEntity: 'equipment'),
  };

  @override
  Future<Set<String>> currentRelation(String id, String relation) async =>
      (await _r.equipmentSets.getEquipmentIdsInSet(id)).toSet();

  /// The geofences a read lists only on request, so a plan compares them.
  @override
  Future<Map<String, Object?>> stored(
    String id,
    Map<String, Object?> document,
  ) async => {
    ...document,
    'geofences': [
      for (final g in await _r.equipmentSets.getGeofencesForSet(id))
        {
          'label': g.label,
          'latitude': g.latitude,
          'longitude': g.longitude,
          'radius_m': g.radiusMeters,
        },
    ],
  };

  /// A new set becomes the default through an update once it exists, so
  /// the plan can list the set it takes the default from.
  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    // The set editor offers only gear in the kit, as the set leaves it.
    final added = check.relations['equipment_ids']?.add ?? const <String>{};
    if (added.isNotEmpty) {
      final rows = await DatabaseService.instance.database
          .customSelect(
            'SELECT id, is_active FROM equipment WHERE id IN '
            '(${List.filled(added.length, '?').join(', ')})',
            variables: [for (final id in added) Variable.withString(id)],
          )
          .get();
      final out = [
        for (final row in rows)
          if (!inKitSoFar(
            check.soFar,
            row.read<String>('id'),
            stored: row.read<bool>('is_active'),
          ))
            row.read<String>('id'),
      ];
      if (out.isNotEmpty) {
        return PlanBlock(
          BlockReason.invalidValue,
          'equipment_ids: ${out.join(', ')} is not in the kit (retired, sold '
          'or wanted).',
        );
      }
    }
    if (check.kind == ChangeKind.create && check.values['is_default'] == true) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'is_default: make a set the default with an update once it exists.',
      );
    }
    return null;
  }

  /// Making a set the default takes the flag from the diver's other one.
  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async {
    if (update.values['is_default'] != true) return const SideEffects();
    final others = ownerId == null
        ? await countRows(
            'equipment_sets',
            'id != ?1 AND is_default = 1 AND diver_id IS NULL',
            id,
          )
        : await countRows(
            'equipment_sets',
            'id != ?1 AND is_default = 1 AND diver_id = ?2',
            id,
            [ownerId],
          );
    return SideEffects(touched: {if (others > 0) 'equipment_sets': others});
  }

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async => DeleteReach(parts: await countCascaded('equipment_sets', id));

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final now = DateTime.now();
    final set = await _r.equipmentSets.createSet(
      EquipmentSet(
        id: '',
        diverId: diverId,
        name: values['name']! as String,
        description: values['description'] as String? ?? '',
        autoApplyOnComputerImport:
            values['auto_apply_on_computer_import'] as bool? ?? false,
        showFigure: values['show_figure'] as bool? ?? true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (values.containsKey('geofences')) {
      await _saveGeofences(set.id, values['geofences'], const []);
    }
    return set.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final sets = _r.equipmentSets;
    final current =
        await sets.getSetById(id) ??
        (throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Equipment set $id no longer exists.',
          details: {'id': id},
        ));
    final v = update.values;
    final members = update.relations['equipment_ids'];
    if (v.keys.any(
          const {
            'name',
            'description',
            'auto_apply_on_computer_import',
          }.contains,
        ) ||
        (members != null && !members.isEmpty)) {
      final ids = current.equipmentIds.toSet();
      await sets.updateSet(
        EquipmentSet(
          id: id,
          diverId: current.diverId,
          name: v['name'] as String? ?? current.name,
          description: v['description'] as String? ?? current.description,
          equipmentIds: [
            ...current.equipmentIds.where(
              (e) => !(members?.remove.contains(e) ?? false),
            ),
            for (final e in members?.add ?? const <String>{})
              if (!ids.contains(e)) e,
          ],
          isDefault: current.isDefault,
          autoApplyOnComputerImport:
              v['auto_apply_on_computer_import'] as bool? ??
              current.autoApplyOnComputerImport,
          showFigure: current.showFigure,
          createdAt: current.createdAt,
          updatedAt: current.updatedAt,
        ),
      );
    }
    if (v['show_figure'] case final bool show) {
      await sets.setShowFigure(id, show);
    }
    switch (v['is_default']) {
      case true:
        await sets.setAsDefault(id, diverId: ownerId);
      case false:
        await sets.clearDefault(id);
    }
    if (v.containsKey('geofences')) {
      await _saveGeofences(
        id,
        v['geofences'],
        await sets.getGeofencesForSet(id),
      );
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.equipmentSets.deleteSet(id);

  /// Writes the geofences [parsed] lists, each taking the place of the one
  /// at its position in [current]; the rest of [current] go.
  Future<void> _saveGeofences(
    String setId,
    Object? parsed,
    List<EquipmentSetGeofence> current,
  ) async {
    final sets = _r.equipmentSets;
    final wanted = ObjectListCodec.items(parsed);
    final now = DateTime.now();
    for (final (index, item) in wanted.indexed) {
      final kept = index < current.length ? current[index] : null;
      final fence = EquipmentSetGeofence(
        id: kept?.id ?? _uuid.v4(),
        setId: setId,
        label: item['label'] as String?,
        latitude: (item['latitude']! as num).toDouble(),
        longitude: (item['longitude']! as num).toDouble(),
        radiusMeters: (item['radius_m']! as num).toDouble(),
        createdAt: kept?.createdAt ?? now,
        updatedAt: now,
      );
      await (kept == null
          ? sets.addGeofence(fence)
          : sets.updateGeofence(fence));
    }
    for (final gone in current.skip(wanted.length)) {
      await sets.removeGeofence(gone.id);
    }
  }
}
