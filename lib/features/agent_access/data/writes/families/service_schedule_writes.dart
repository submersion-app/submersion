import 'package:submersion/core/constants/enums.dart'
    show EquipmentStatus, EquipmentType;
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/service_ledger_rules.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

/// An item's service clocks, through the repository its clocks card uses.
/// A clock is of one service type, once per item, a type that fits the
/// item's type and that its diver can see; wanted gear has none. A baseline
/// the diver names is stamped as picked, as the clock's dialog stamps it.
class ServiceScheduleWrites extends WritableEntry {
  ServiceScheduleWrites(this._r, {this.refreshReminders});

  final RecordRepositories _r;

  /// Re-arms the item's reminders after the apply; null in tests.
  final GearReminderRefresh? refreshReminders;

  @override
  String get name => 'service_schedules';

  @override
  String get table => 'service_schedules';

  @override
  ChildOf get parent =>
      const ChildOf(entity: 'equipment', field: 'equipment_id');

  @override
  late final Map<String, FieldCodec> fields = {
    'equipment_id': const FieldCodec.reference('equipment'),
    'service_kind_id': const FieldCodec.reference('service_kinds'),
    'interval_days': const FieldCodec.integer(
      min: 1,
      max: 100000,
      nullable: true,
    ),
    'interval_dives': const FieldCodec.integer(
      min: 1,
      max: 100000,
      nullable: true,
    ),
    'interval_hours': const FieldCodec.number(
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
    'anchor_date': const FieldCodec.calendarDate(nullable: true),
    'enabled': const FieldCodec.flag(),
  };

  @override
  Set<String> get requiredOnCreate => const {'service_kind_id'};

  /// One clock of a type per item, so two creates in a set cannot both add
  /// it.
  @override
  UniqueClaim? uniqueKey(WriteCheck check) {
    final kindId = check.values['service_kind_id'] as String?;
    if (check.kind != ChangeKind.create || kindId == null) return null;
    return UniqueClaim('${check.values['equipment_id']}/$kindId');
  }

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind != ChangeKind.create &&
        await _wanted(check, check.document!['equipment_id']! as String)) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'equipment_id: gear not bought yet shows no service clocks to '
        'change.',
      );
    }
    if (check.kind == ChangeKind.delete) return null;
    final dayBlock =
        dayRangeProblem(
          check,
          'anchor_date',
          from: DateTime(1950),
          to: today(),
        ) ??
        wholeCountProblem(check, 'exposure_intervals') ??
        currencyProblem(check, 'default_currency');
    if (dayBlock != null) return dayBlock;
    if (check.kind == ChangeKind.update) {
      final fixed = check.values.keys
          .where(const {'service_kind_id', 'equipment_id'}.contains)
          .toList();
      if (fixed.isNotEmpty) {
        return PlanBlock(
          BlockReason.invalidValue,
          '${fixed.join(', ')}: a clock keeps its type and its item; '
          'remove it and add another instead.',
        );
      }
      return _intervalBlock(
        check,
        check.document!['service_kind_id']! as String,
      );
    }
    return _createBlock(check);
  }

  /// A block for a clock the clocks card would not offer.
  Future<PlanBlock?> _createBlock(WriteCheck check) async {
    final itemId = check.values['equipment_id']! as String;
    final kindId = check.values['service_kind_id']! as String;
    final item = await _r.equipment.getEquipmentById(itemId);
    final kind = await _r.serviceKinds.getKindById(kindId);
    if (item == null || kind == null) return null;
    final earlier = check.soFar.values[('equipment', itemId)];
    final type = switch (earlier?['type']) {
      final String name => EquipmentType.values.byName(name),
      _ => item.type,
    };
    PlanBlock invalid(String why) =>
        PlanBlock(BlockReason.invalidValue, 'service_kind_id: $why');
    // The rules below read the type as stored.
    if (check.soFar.values.containsKey(('service_kinds', kindId))) {
      return invalid(
        'this set changes ${kind.name} earlier; add its clocks in a change '
        'set of its own.',
      );
    }
    if (await _wanted(check, itemId)) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'equipment_id: gear not bought yet has no service clocks.',
      );
    }
    if (!kind.appliesTo(type)) {
      return invalid('${kind.name} is not for a ${type.name}.');
    }
    if (!kind.isBuiltIn &&
        kind.diverId != null &&
        kind.diverId != check.ownerId) {
      return invalid('${kind.name} is another profile\'s service type.');
    }
    if (kind.isBuiltIn &&
        (await _r.serviceSchedules.hiddenServiceKindIds(
          check.ownerId,
        )).contains(kind.id)) {
      return invalid(
        '${kind.name} is hidden in Settings; show it there first.',
      );
    }
    if (await _intervalBlock(check, kindId) case final block?) return block;
    final gone = check.soFar.deleted[name] ?? const <String>{};
    final stored = await _r.serviceSchedules.getSchedulesForEquipment(itemId);
    if (stored.any((s) => s.serviceKindId == kindId && !gone.contains(s.id))) {
      return PlanBlock(
        BlockReason.duplicateRecord,
        'service_kind_id: this item has a ${kind.name} clock already.',
      );
    }
    return null;
  }

  /// Whether item [itemId] is wanted as the set's earlier changes leave it.
  Future<bool> _wanted(WriteCheck check, String itemId) async {
    final earlier = check.soFar.values[('equipment', itemId)]?['status'];
    final status =
        earlier as String? ??
        (await _r.equipment.getEquipmentById(itemId))?.status.name;
    return status == EquipmentStatus.wanted.name;
  }

  /// A block for a clock of type [kindId] that would count nothing down, as
  /// [check] leaves its overrides: the clock dialog asks for an interval
  /// when the type has none.
  Future<PlanBlock?> _intervalBlock(WriteCheck check, String kindId) async {
    final kind = await _r.serviceKinds.getKindById(kindId);
    if (kind == null ||
        kind.defaultIntervalDays != null ||
        kind.defaultIntervalDives != null ||
        kind.defaultIntervalHours != null ||
        kind.exposureIntervals.isNotEmpty) {
      return null;
    }
    Object? held(String key) => check.values.containsKey(key)
        ? check.values[key]
        : check.document?[key];
    final exposure = check.values.containsKey('exposure_intervals')
        ? exposureFrom(check.values['exposure_intervals']).isNotEmpty
        : (check.document?['exposure_intervals'] as Map?)?.isNotEmpty ?? false;
    if (held('interval_days') != null ||
        held('interval_dives') != null ||
        held('interval_hours') != null ||
        exposure) {
      return null;
    }
    return PlanBlock(
      BlockReason.invalidValue,
      'service_kind_id: ${kind.name} has no interval of its own; name '
      'interval_days, interval_dives, interval_hours or exposure_intervals.',
    );
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final itemId = values['equipment_id']! as String;
    final kindId = values['service_kind_id']! as String;
    // Nothing in the database keeps a type to one clock per item, and adding
    // a clock does not change the item, so this is checked again here.
    if ((await _r.serviceSchedules.getSchedulesForEquipment(
      itemId,
    )).any((s) => s.serviceKindId == kindId)) {
      throw const AgentToolException(
        AgentToolErrorCode.writeRefused,
        'A clock of this type was added to the item after the preview. '
        'Preview again.',
      );
    }
    final now = DateTime.now();
    final blank = ServiceSchedule(
      id: '',
      equipmentId: values['equipment_id']! as String,
      serviceKindId: values['service_kind_id']! as String,
      createdAt: now,
      updatedAt: now,
    );
    return (await _r.serviceSchedules.createSchedule(
      _applied(blank, values, now),
    )).id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current = await _clock(id);
    await _r.serviceSchedules.updateSchedule(
      _applied(current, update.values, DateTime.now()),
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.serviceSchedules.deleteSchedule(id);

  @override
  Future<void> afterApply(List<AppliedChange> changes) async {
    // Once per item, however many of its clocks or records the set changed.
    for (final itemId in {for (final c in changes) ?c.parentId}) {
      await refreshReminders?.call(itemId);
    }
  }

  /// [clock] with [values] applied, a named null clearing its field.
  static ServiceSchedule _applied(
    ServiceSchedule clock,
    Map<String, Object?> values,
    DateTime now,
  ) {
    T? kept<T>(String key, T? held) =>
        values.containsKey(key) ? values[key] as T? : held;
    final next = clock.copyWith(
      intervalDays: kept('interval_days', clock.intervalDays),
      intervalDives: kept('interval_dives', clock.intervalDives),
      intervalHours: kept<num>(
        'interval_hours',
        clock.intervalHours,
      )?.toDouble(),
      exposureIntervals: values.containsKey('exposure_intervals')
          ? exposureFrom(values['exposure_intervals'])
          : null,
      defaultCost: kept<num>('default_cost', clock.defaultCost)?.toDouble(),
      defaultCurrency: kept('default_currency', clock.defaultCurrency),
      enabled: values['enabled'] as bool?,
    );
    return values.containsKey('anchor_date')
        ? next.withBaseline(
            calendarDay(values['anchor_date']),
            now: now,
            picked: true,
          )
        : next;
  }

  /// Clock [id], found through the item it belongs to.
  Future<ServiceSchedule> _clock(String id) async {
    final all = await _r.serviceSchedules.getAllSchedules();
    return all.where((s) => s.id == id).firstOrNull ??
        (throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Service clock $id no longer exists.',
          details: {'id': id},
        ));
  }
}
