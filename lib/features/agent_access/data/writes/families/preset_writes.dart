import 'package:submersion/core/constants/enums.dart'
    show TankMaterial, WeightType;
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/built_in_rule.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/object_list_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';

/// The diver's own tank presets, through the repository the tank presets
/// page uses. The built-in ones are constants of the app, not records. A
/// preset's internal name follows its display name, as the editor sets it.
class TankPresetWrites extends WritableEntry {
  TankPresetWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'tank_presets';

  @override
  String get table => 'tank_presets';

  @override
  late final Map<String, FieldCodec> fields = {
    'display_name': const FieldCodec.text(maxLength: 100),
    'volume_l': const FieldCodec.number(min: 0.1, max: 60),
    'working_pressure_bar': const FieldCodec.number(min: 1, max: 450),
    'material': FieldCodec.enumName(TankMaterial.values),
    'description': const FieldCodec.text(allowBlank: true),
    'sort_order': const FieldCodec.integer(min: 0, max: 999),
  };

  @override
  Set<String> get requiredOnCreate => const {
    'display_name',
    'volume_l',
    'working_pressure_bar',
    'material',
  };

  @override
  String? titleOf(Map<String, Object?> document) =>
      document['display_name'] as String?;

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async => appendSlotBlock(check);

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final displayName = values['display_name']! as String;
    final preset = await _r.tankPresets.createPreset(
      TankPresetEntity.create(
        id: '',
        name: TankPresetEntity.generateSlug(displayName),
        displayName: displayName,
        volumeLiters: values['volume_l']! as double,
        workingPressureBar: values['working_pressure_bar']! as double,
        material: TankMaterial.values.byName(values['material']! as String),
        diverId: diverId,
        description: values['description'] as String? ?? '',
        sortOrder: values['sort_order'] as int? ?? 0,
      ),
    );
    return preset.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current =
        await _r.tankPresets.getPresetById(id) ??
        _gone('Tank preset $id no longer exists.', id);
    final v = update.values;
    final displayName = v['display_name'] as String? ?? current.displayName;
    await _r.tankPresets.updatePreset(
      TankPresetEntity(
        id: id,
        diverId: current.diverId,
        name: v.containsKey('display_name')
            ? TankPresetEntity.generateSlug(displayName)
            : current.name,
        displayName: displayName,
        volumeLiters: v['volume_l'] as double? ?? current.volumeLiters,
        workingPressureBar:
            v['working_pressure_bar'] as double? ?? current.workingPressureBar,
        material: v['material'] == null
            ? current.material
            : TankMaterial.values.byName(v['material']! as String),
        description: v['description'] as String? ?? current.description,
        sortOrder: v['sort_order'] as int? ?? current.sortOrder,
        createdAt: current.createdAt,
        updatedAt: current.updatedAt,
        ratedCapacityCuft: current.ratedCapacityCuft,
      ),
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.tankPresets.deletePreset(id);
}

/// The diver's weight presets, through the repository the weight presets
/// page uses. The entries are replaced whole, in the order given.
class WeightPresetWrites extends WritableEntry {
  WeightPresetWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'weight_presets';

  @override
  String get table => 'weight_presets';

  @override
  late final Map<String, FieldCodec> fields = {
    'display_name': const FieldCodec.text(maxLength: 100, trim: true),
    'notes': const FieldCodec.text(allowBlank: true, trim: true),
    'entries': ObjectListCodec(
      {
        'type': FieldCodec.enumName(WeightType.values),
        'amount_kg': const FieldCodec.number(min: 0, max: 30),
        'label': const FieldCodec.text(maxLength: 60, allowBlank: true),
        'notes': const FieldCodec.text(allowBlank: true),
      },
      defaults: const {'label': '', 'notes': ''},
      maxItems: 20,
    ),
  };

  @override
  Set<String> get requiredOnCreate => const {'display_name'};

  @override
  String? titleOf(Map<String, Object?> document) =>
      document['display_name'] as String?;

  /// The entries a read lists only on request, so a plan compares them.
  @override
  Future<Map<String, Object?>> stored(
    String id,
    Map<String, Object?> document,
  ) async {
    final preset = await _r.weightPresets.getPresetById(id);
    return {
      ...document,
      'entries': [
        for (final e in preset?.entries ?? const <WeightPresetEntry>[])
          {
            'type': e.weightType.name,
            'amount_kg': e.amountKg,
            'label': e.label,
            'notes': e.notes,
          },
      ],
    };
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async =>
      (await _r.weightPresets.createPreset(
        diverId: diverId,
        displayName: values['display_name']! as String,
        entries: _drafts(values['entries']),
        notes: values['notes'] as String? ?? '',
      )).id;

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current =
        await _r.weightPresets.getPresetById(id) ??
        _gone('Weight preset $id no longer exists.', id);
    final v = update.values;
    final displayName = v['display_name'] as String? ?? current.displayName;
    final notes = v['notes'] as String? ?? current.notes;
    if (!v.containsKey('entries')) {
      return _r.weightPresets.renamePreset(
        id: id,
        displayName: displayName,
        notes: notes,
      );
    }
    await _r.weightPresets.updatePreset(
      id: id,
      displayName: displayName,
      notes: notes,
      entries: _drafts(v['entries']),
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.weightPresets.deletePreset(id);

  List<WeightEntryDraft> _drafts(Object? parsed) => parsed == null
      ? const []
      : [
          for (final item in ObjectListCodec.items(parsed))
            (
              weightType: WeightType.values.byName(item['type']! as String),
              amountKg: (item['amount_kg']! as num).toDouble(),
              notes: item['notes']! as String,
              label: item['label']! as String,
            ),
        ];
}

Never _gone(String message, String id) => throw AgentToolException(
  AgentToolErrorCode.writeRefused,
  message,
  details: {'id': id},
);
