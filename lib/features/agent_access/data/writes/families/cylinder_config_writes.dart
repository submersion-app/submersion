import 'package:submersion/core/constants/enums.dart'
    show TankMaterial, TankRole;
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/object_list_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';

/// Cylinder configs, through the repository the config editor uses. The
/// cylinders are replaced whole, in the order given; a cylinder keeps the
/// id of the one at its place before, as an edit in the editor does. Gas is
/// written as fractions, as a read lists it, and stored as percent.
class CylinderConfigWrites extends WritableEntry {
  CylinderConfigWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'cylinder_configs';

  @override
  String get table => 'cylinder_configs';

  @override
  late final Map<String, FieldCodec> fields = {
    'name': const FieldCodec.text(maxLength: 100),
    'description': const FieldCodec.text(allowBlank: true),
    'sort_order': const FieldCodec.integer(min: 0, max: 999),
    'equipment_id': const FieldCodec.reference('equipment', nullable: true),
    'items': ObjectListCodec(
      {
        'role': FieldCodec.enumName(TankRole.values),
        'label': const FieldCodec.text(maxLength: 60, nullable: true),
        'volume_l': const FieldCodec.number(min: 0.1, max: 60, nullable: true),
        'working_pressure_bar': const FieldCodec.number(
          min: 1,
          max: 450,
          nullable: true,
        ),
        'material': FieldCodec.enumName(TankMaterial.values, nullable: true),
        'o2_fraction': const FieldCodec.number(
          min: 0.05,
          max: 1,
          fractionDigits: 3,
        ),
        'he_fraction': const FieldCodec.number(
          min: 0,
          max: 0.95,
          fractionDigits: 3,
        ),
        'default_start_pressure_bar': const FieldCodec.number(
          min: 0,
          max: 450,
          nullable: true,
        ),
        'deco_switch_depth_m': const FieldCodec.number(
          min: 0,
          max: 150,
          nullable: true,
        ),
      },
      defaults: const {'o2_fraction': 0.21, 'he_fraction': 0.0},
      rule: _gasRule,
      maxItems: 12,
    ),
  };

  @override
  Set<String> get requiredOnCreate => const {'name'};

  /// The cylinders a read lists only on request, so a plan compares them.
  @override
  Future<Map<String, Object?>> stored(
    String id,
    Map<String, Object?> document,
  ) async {
    final config = await _r.cylinderConfigs.getConfigById(id);
    return {
      ...document,
      'items': [
        for (final i in config?.items ?? const <CylinderConfigItem>[])
          {
            'role': i.tankRole.name,
            'label': i.label,
            'volume_l': i.volumeL,
            'working_pressure_bar': i.workingPressureBar,
            'material': i.tankMaterial?.name,
            'o2_fraction': i.o2Percent / 100,
            'he_fraction': i.hePercent / 100,
            'default_start_pressure_bar': i.defaultStartPressureBar,
            'deco_switch_depth_m': i.decoSwitchDepth,
          },
      ],
    };
  }

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async => DeleteReach(parts: await countCascaded('cylinder_configs', id));

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final id = await _r.cylinderConfigs.createConfig(
      diverId: diverId,
      equipmentId: values['equipment_id'] as String?,
      name: values['name']! as String,
      description: values['description'] as String? ?? '',
      sortOrder: values['sort_order'] as int? ?? 0,
    );
    if (values.containsKey('items')) {
      await _r.cylinderConfigs.saveItems(id, _items(id, values['items']));
    }
    return id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current =
        await _r.cylinderConfigs.getConfigById(id) ??
        (throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Cylinder config $id no longer exists.',
          details: {'id': id},
        ));
    final v = update.values;
    // Saved even for a change to the cylinders alone, as the editor saves
    // it, so the config's stamp moves with them.
    await _r.cylinderConfigs.updateConfig(
      CylinderConfig(
        id: id,
        diverId: current.diverId,
        equipmentId: v.containsKey('equipment_id')
            ? v['equipment_id'] as String?
            : current.equipmentId,
        name: v['name'] as String? ?? current.name,
        description: v['description'] as String? ?? current.description,
        sortOrder: v['sort_order'] as int? ?? current.sortOrder,
        createdAt: current.createdAt,
        updatedAt: current.updatedAt,
      ),
    );
    if (v.containsKey('items')) {
      await _r.cylinderConfigs.saveItems(
        id,
        _items(id, v['items'], keep: current.items),
      );
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.cylinderConfigs.deleteConfig(id);

  /// The cylinders [parsed] lists, each taking the id of the cylinder at its
  /// place in [keep]; a new place gets a new id from the repository.
  List<CylinderConfigItem> _items(
    String configId,
    Object? parsed, {
    List<CylinderConfigItem> keep = const [],
  }) {
    final now = DateTime.now();
    return [
      for (final (index, item) in ObjectListCodec.items(parsed).indexed)
        CylinderConfigItem(
          id: index < keep.length ? keep[index].id : '',
          configId: configId,
          sortOrder: index,
          label: item['label'] as String?,
          tankRole: TankRole.values.byName(item['role']! as String),
          volumeL: (item['volume_l'] as num?)?.toDouble(),
          workingPressureBar: (item['working_pressure_bar'] as num?)
              ?.toDouble(),
          tankMaterial: item['material'] == null
              ? null
              : TankMaterial.values.byName(item['material']! as String),
          o2Percent: _percent(item['o2_fraction']! as num),
          hePercent: _percent(item['he_fraction']! as num),
          defaultStartPressureBar: (item['default_start_pressure_bar'] as num?)
              ?.toDouble(),
          decoSwitchDepth: (item['deco_switch_depth_m'] as num?)?.toDouble(),
          createdAt: now,
          updatedAt: now,
        ),
    ];
  }
}

/// A fraction as the percent the table keeps, to a tenth, so 0.32 is 32 and
/// not 32.000000000000004.
double _percent(num fraction) => (fraction * 1000).round() / 10;

String? _gasRule(Map<String, Object?> item) {
  final o2 = item['o2_fraction']! as num;
  final he = item['he_fraction']! as num;
  return o2 + he > 1.0005 ? 'o2_fraction and he_fraction add up past 1.' : null;
}
