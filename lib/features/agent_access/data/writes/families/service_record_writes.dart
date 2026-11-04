import 'package:submersion/core/constants/enums.dart' show ServiceCategory;
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/service_ledger_rules.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/services/default_service_cost_resolver.dart';

/// An item's service history, through the repository the log service dialog
/// uses. A record names a service type the dialog offers and a day that has
/// happened; a new one takes the category and prices the dialog fills in.
/// The repository keeps the item's last service date, so the plan says when
/// a change moves it.
class ServiceRecordWrites extends WritableEntry {
  ServiceRecordWrites(this._r, {this.refreshReminders});

  final RecordRepositories _r;

  /// Re-arms the item's reminders after the apply; null in tests.
  final GearReminderRefresh? refreshReminders;

  @override
  String get name => 'service_records';

  @override
  String get table => 'service_records';

  @override
  ChildOf get parent =>
      const ChildOf(entity: 'equipment', field: 'equipment_id');

  @override
  late final Map<String, FieldCodec> fields = {
    'equipment_id': const FieldCodec.reference('equipment'),
    'service_kind_id': const FieldCodec.reference('service_kinds'),
    'category': FieldCodec.enumName(ServiceCategory.values),
    'service_date': const FieldCodec.calendarDate(),
    'next_service_due_date': const FieldCodec.calendarDate(nullable: true),
    'provider': const FieldCodec.text(
      maxLength: 200,
      nullable: true,
      trim: true,
    ),
    'cost': const FieldCodec.number(min: 0, max: 10000000, nullable: true),
    'currency': currencyCodec,
    'notes': const FieldCodec.text(allowBlank: true, trim: true),
  };

  @override
  Set<String> get requiredOnCreate => const {'service_kind_id', 'service_date'};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    final now = today();
    return dayRangeProblem(
          check,
          'service_date',
          from: DateTime(1950),
          to: now,
        ) ??
        dayRangeProblem(
          check,
          'next_service_due_date',
          from: DateTime(1950),
          to: DateTime(now.year + 10, now.month, now.day),
        ) ??
        currencyProblem(check, 'currency') ??
        await _kindBlock(check);
  }

  /// A block for a service type the dialog would not offer: the owner's
  /// types without the built-ins they hid, and the types of the item's
  /// clocks; an edit may keep the record's own type.
  Future<PlanBlock?> _kindBlock(WriteCheck check) async {
    final kindId = check.values['service_kind_id'] as String?;
    if (kindId == null || kindId == check.document?['service_kind_id']) {
      return null;
    }
    final itemId =
        check.values['equipment_id'] as String? ??
        check.document!['equipment_id']! as String;
    final clocks = await _r.serviceSchedules.getSchedulesForEquipment(itemId);
    if (clocks.any((c) => c.serviceKindId == kindId)) return null;
    final kind = await _r.serviceKinds.getKindById(kindId);
    if (kind == null) return null;
    final hidden = await _r.serviceSchedules.hiddenServiceKindIds(
      check.ownerId,
    );
    if (kind.isBuiltIn && hidden.contains(kind.id)) {
      return PlanBlock(
        BlockReason.invalidValue,
        'service_kind_id: ${kind.name} is hidden in Settings; show it there '
        'first.',
      );
    }
    return null;
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final itemId = values['equipment_id']! as String;
    final kindId = values['service_kind_id']! as String;
    final kind = await _r.serviceKinds.getKindById(kindId);
    final kinds = [?kind];
    final prices = resolveDefaultServiceCost(
      serviceKindId: kindId,
      schedules: await _r.serviceSchedules.getSchedulesForEquipment(itemId),
      kinds: kinds,
    );
    final now = DateTime.now();
    final category = values['category'] as String?;
    return (await _r.serviceRecords.createRecord(
      ServiceRecord(
        id: '',
        equipmentId: itemId,
        serviceKindId: kindId,
        serviceCategory: category != null
            ? ServiceCategory.values.byName(category)
            : resolveDefaultServiceCategory(
                    serviceKindId: kindId,
                    kinds: kinds,
                  ) ??
                  ServiceCategory.annual,
        serviceDate: calendarDay(values['service_date'])!,
        nextServiceDue: calendarDay(values['next_service_due_date']),
        provider: values['provider'] as String?,
        cost: values.containsKey('cost')
            ? (values['cost'] as num?)?.toDouble()
            : prices.cost,
        currency:
            values['currency'] as String? ??
            prices.currency ??
            await defaultCurrencyOf(diverId),
        notes: values['notes'] as String? ?? '',
        createdAt: now,
        updatedAt: now,
      ),
    )).id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current = await _record(id);
    final v = update.values;
    T? kept<T>(String key, T? held) => v.containsKey(key) ? v[key] as T? : held;
    final category = v['category'] as String?;
    await _r.serviceRecords.updateRecord(
      ServiceRecord(
        id: id,
        equipmentId: current.equipmentId,
        serviceKindId: v['service_kind_id'] as String? ?? current.serviceKindId,
        serviceCategory: category == null
            ? current.serviceCategory
            : ServiceCategory.values.byName(category),
        serviceDate: calendarDay(v['service_date']) ?? current.serviceDate,
        nextServiceDue: v.containsKey('next_service_due_date')
            ? calendarDay(v['next_service_due_date'])
            : current.nextServiceDue,
        provider: kept('provider', current.provider),
        cost: kept<num>('cost', current.cost)?.toDouble(),
        currency: v.containsKey('currency')
            ? v['currency'] as String? ?? await defaultCurrencyOf(ownerId ?? '')
            : current.currency,
        notes: v['notes'] as String? ?? current.notes,
        createdAt: current.createdAt,
        updatedAt: current.updatedAt,
      ),
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.serviceRecords.deleteRecord(id);

  @override
  Future<void> afterApply(AppliedChange change) async {
    if (change.parentId case final itemId?) {
      await refreshReminders?.call(itemId);
    }
  }

  /// The item a create moves the last service date of: the repository
  /// writes the new record's day as it is (issue #4201).
  @override
  Future<Map<String, int>> createTouched(
    String diverId,
    Map<String, Object?> values,
  ) async => _moved(
    values['equipment_id']! as String,
    calendarDay(values['service_date']),
  );

  /// The item an edit moves the last service date of: the repository sets
  /// it to the newest record's day.
  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async {
    final day = calendarDay(update.values['service_date']);
    if (day == null) return const SideEffects();
    final itemId = document['equipment_id']! as String;
    final days = [
      for (final r in await _r.serviceRecords.getRecordsForEquipment(itemId))
        r.id == id ? day : r.serviceDate,
    ];
    return SideEffects(touched: await _moved(itemId, _newest(days)));
  }

  /// The item a delete moves the last service date of: the newest record
  /// left, or none.
  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async {
    final current = await _r.serviceRecords.getRecordById(id);
    if (current == null) return const DeleteReach();
    final days = [
      for (final r in await _r.serviceRecords.getRecordsForEquipment(
        current.equipmentId,
      ))
        if (r.id != id) r.serviceDate,
    ];
    return DeleteReach(
      touched: await _moved(current.equipmentId, _newest(days)),
    );
  }

  static DateTime? _newest(List<DateTime> days) =>
      days.isEmpty ? null : days.reduce((a, b) => a.isAfter(b) ? a : b);

  /// `{'equipment': 1}` when item [itemId]'s last service date becomes
  /// [day], else nothing.
  Future<Map<String, int>> _moved(String itemId, DateTime? day) async {
    final item = await _r.equipment.getEquipmentById(itemId);
    if (item == null || item.lastServiceDate == day) return const {};
    return const {'equipment': 1};
  }

  Future<ServiceRecord> _record(String id) async =>
      await _r.serviceRecords.getRecordById(id) ??
      (throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        'Service record $id no longer exists.',
        details: {'id': id},
      ));
}
