import 'package:submersion/core/constants/enums.dart' show EquipmentType;
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/gas_fraction_rules.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';

/// A cylinder's fills, through the repositories the log fill sheet and the
/// blender use. A fill is a possible mix on a tank, in bar and degrees; the
/// tank's passport id is minted on its first fill, as the blender mints it.
/// The wire gives the gas as fractions, as a read lists them; the store
/// keeps percent.
class CylinderFillWrites extends WritableEntry {
  CylinderFillWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'cylinder_fills';

  @override
  String get table => 'cylinder_fills';

  @override
  ChildOf get parent =>
      const ChildOf(entity: 'equipment', field: 'equipment_id');

  @override
  late final Map<String, FieldCodec> fields = {
    'equipment_id': const FieldCodec.reference('equipment'),
    'filled_at': const FieldCodec.instant(),
    'o2_fraction': const FieldCodec.number(min: 0, max: 1),
    'he_fraction': const FieldCodec.number(min: 0, max: 1),
    'pressure_bar': const FieldCodec.number(min: 0, max: 400, nullable: true),
    'temperature_c': const FieldCodec.number(min: -30, max: 60, nullable: true),
    'analyzer': const FieldCodec.text(
      maxLength: 100,
      nullable: true,
      trim: true,
    ),
    'station_name': const FieldCodec.text(
      maxLength: 100,
      nullable: true,
      trim: true,
    ),
    'notes': const FieldCodec.text(allowBlank: true, trim: true),
  };

  @override
  Set<String> get requiredOnCreate => const {'o2_fraction'};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    if (check.document?['signed_record'] != null) {
      return const PlanBlock(
        BlockReason.notPermitted,
        'A signed fill keeps the values its signature covers; delete it and '
        'log another instead.',
      );
    }
    double fraction(String key) =>
        ((check.values.containsKey(key)
                    ? check.values[key]
                    : check.document?[key] ?? (key == 'he_fraction' ? 0 : 0))
                as num)
            .toDouble();
    final o2 = fraction('o2_fraction');
    final he = fraction('he_fraction');
    // CylinderFill.isPossibleMix, in fractions.
    if (o2 <= 0 || o2 + he > 1) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'o2_fraction, he_fraction: oxygen above 0 and the two together at '
        'most 1.',
      );
    }
    final itemId =
        check.values['equipment_id'] as String? ??
        check.document?['equipment_id'] as String?;
    if (itemId == null) return null;
    final item = await _r.equipment.getEquipmentById(itemId);
    if (item != null && item.type != EquipmentType.tank) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'equipment_id: a fill belongs to a tank.',
      );
    }
    return null;
  }

  /// What the log fill sheet starts a fill with: air, now.
  @override
  Future<Map<String, Object?>> createDefaults(
    String diverId,
    Map<String, Object?> values,
  ) async => {'he_fraction': 0.0, 'filled_at': DateTime.now().toUtc()};

  /// A tank's first fill mints its passport id.
  @override
  Future<Map<String, int>> alsoCreates(
    String diverId,
    Map<String, Object?> values,
  ) async {
    final itemId = values['equipment_id'] as String?;
    if (itemId == null) return const {};
    final held = await _r.cylinderPassports.getPassportId(itemId);
    return held == null ? const {'equipment_attributes': 1} : const {};
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final itemId = values['equipment_id']! as String;
    final passport = await _r.cylinderPassports.ensurePassportId(
      itemId,
      diverId: diverId,
    );
    final now = DateTime.now();
    return (await _r.cylinderFills.create(
      CylinderFill(
        id: '',
        diverId: diverId,
        passportId: passport,
        equipmentId: itemId,
        filledAt: values['filled_at']! as DateTime,
        o2Percent: percentOf(values['o2_fraction'])!,
        hePercent: percentOf(values['he_fraction']) ?? 0,
        pressureBar: (values['pressure_bar'] as num?)?.toDouble(),
        temperatureC: (values['temperature_c'] as num?)?.toDouble(),
        analyzer: values['analyzer'] as String?,
        stationName: values['station_name'] as String?,
        notes: values['notes'] as String? ?? '',
        createdAt: now,
        updatedAt: now,
      ),
    )).id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current =
        await _r.cylinderFills.getById(id) ??
        (throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Fill $id no longer exists.',
          details: {'id': id},
        ));
    final v = update.values;
    bool cleared(String key) => v.containsKey(key) && v[key] == null;
    await _r.cylinderFills.update(
      current.copyWith(
        filledAt: v['filled_at'] as DateTime?,
        o2Percent: percentOf(v['o2_fraction']),
        hePercent: percentOf(v['he_fraction']),
        pressureBar: (v['pressure_bar'] as num?)?.toDouble(),
        clearPressureBar: cleared('pressure_bar'),
        temperatureC: (v['temperature_c'] as num?)?.toDouble(),
        clearTemperatureC: cleared('temperature_c'),
        analyzer: v['analyzer'] as String?,
        clearAnalyzer: cleared('analyzer'),
        stationName: v['station_name'] as String?,
        clearStationName: cleared('station_name'),
        notes: v['notes'] as String?,
      ),
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.cylinderFills.delete(id);
}
