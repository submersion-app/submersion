import 'package:submersion/core/constants/enums.dart'
    show EquipmentType, ServiceCategory;
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/built_in_rule.dart';
import 'package:submersion/features/agent_access/data/writes/families/service_ledger_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';

/// Service types, through the repository the service types page uses. A
/// custom type is its diver's to change; a built-in one is the app's, which
/// the page lets a diver hide but never edit or delete. A delete takes the
/// clocks of that type with it; the service history keeps its records.
class ServiceKindWrites extends WritableEntry {
  ServiceKindWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'service_kinds';

  @override
  String get table => 'service_kinds';

  @override
  late final Map<String, FieldCodec> fields = {
    'name': const FieldCodec.text(maxLength: 100, trim: true),
    'applicable_types': FieldCodec.enumSet(EquipmentType.values),
    'default_interval_days': const FieldCodec.integer(
      min: 1,
      max: 100000,
      nullable: true,
    ),
    'default_interval_dives': const FieldCodec.integer(
      min: 1,
      max: 100000,
      nullable: true,
    ),
    'default_interval_hours': const FieldCodec.number(
      min: 0.1,
      max: 100000,
      nullable: true,
    ),
    'exposure_intervals': exposureIntervalsCodec,
    'default_cost': const FieldCodec.number(
      min: 0,
      max: 10000000,
      nullable: true,
    ),
    'default_currency': currencyCodec,
    'default_category': FieldCodec.enumName(
      ServiceCategory.values,
      nullable: true,
    ),
    'auto_attach': const FieldCodec.flag(),
  };

  @override
  Set<String> get requiredOnCreate => const {'name'};

  @override
  String? titleOf(Map<String, Object?> document) => document['name'] as String?;

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async =>
      builtInBlock(check, 'service types') ??
      wholeCountProblem(check, 'exposure_intervals') ??
      currencyProblem(check, 'default_currency');

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async => DeleteReach(parts: await countCascaded('service_kinds', id));

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final now = DateTime.now();
    final blank = ServiceKind(
      id: '',
      diverId: diverId,
      name: values['name']! as String,
      createdAt: now,
      updatedAt: now,
    );
    return (await _r.serviceKinds.createKind(_applied(blank, values))).id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current =
        await _r.serviceKinds.getKindById(id) ??
        (throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Service type $id no longer exists.',
          details: {'id': id},
        ));
    await _r.serviceKinds.updateKind(_applied(current, update.values));
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.serviceKinds.deleteKind(id);

  /// [kind] with [values] applied, a named null clearing its field.
  static ServiceKind _applied(ServiceKind kind, Map<String, Object?> values) {
    T? kept<T>(String key, T? now) =>
        values.containsKey(key) ? values[key] as T? : now;
    final types = values['applicable_types'];
    return kind.copyWith(
      name: values['name'] as String?,
      applicableTypes: types is String
          ? [
              for (final name in types.split(','))
                if (name.isNotEmpty) EquipmentType.values.byName(name),
            ]
          : null,
      defaultIntervalDays: kept(
        'default_interval_days',
        kind.defaultIntervalDays,
      ),
      defaultIntervalDives: kept(
        'default_interval_dives',
        kind.defaultIntervalDives,
      ),
      defaultIntervalHours: (kept<num>(
        'default_interval_hours',
        kind.defaultIntervalHours,
      ))?.toDouble(),
      exposureIntervals: values.containsKey('exposure_intervals')
          ? exposureFrom(values['exposure_intervals'])
          : null,
      defaultCost: (kept<num>('default_cost', kind.defaultCost))?.toDouble(),
      defaultCurrency: kept('default_currency', kind.defaultCurrency),
      defaultCategory: values.containsKey('default_category')
          ? (values['default_category'] == null
                ? null
                : ServiceCategory.values.byName(
                    values['default_category']! as String,
                  ))
          : kind.defaultCategory,
      autoAttach: values['auto_attach'] as bool?,
    );
  }
}
