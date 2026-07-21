import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/service_kind_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_record_repository.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_field.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/services/service_due_engine.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

/// Repository provider
final equipmentRepositoryProvider = Provider<EquipmentRepository>((ref) {
  return EquipmentRepository();
});

/// Active equipment provider
final activeEquipmentProvider = FutureProvider<List<EquipmentItem>>((
  ref,
) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  return repository.getActiveEquipment(diverId: validatedDiverId);
});

/// Retired equipment provider
final retiredEquipmentProvider = FutureProvider<List<EquipmentItem>>((
  ref,
) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  return repository.getRetiredEquipment(diverId: validatedDiverId);
});

/// Equipment by status provider
final equipmentByStatusProvider =
    FutureProvider.family<List<EquipmentItem>, EquipmentStatus?>((
      ref,
      status,
    ) async {
      final repository = ref.watch(equipmentRepositoryProvider);
      final validatedDiverId = await ref.watch(
        validatedCurrentDiverIdProvider.future,
      );
      ref.invalidateSelfWhen(repository.watchEquipmentChanges());
      if (status == null) {
        return repository.getAllEquipment(diverId: validatedDiverId);
      }
      return repository.getEquipmentByStatus(status, diverId: validatedDiverId);
    });

/// All equipment provider (filtered by current diver).
///
/// A one-shot read that self-invalidates whenever the `equipment` table
/// changes (a sync apply, a local create/edit/delete, ...), so list UIs
/// refresh automatically while imperative
/// `ref.read(allEquipmentProvider.future)` reads still resolve.
final allEquipmentProvider = FutureProvider<List<EquipmentItem>>((ref) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );

  ref.invalidateSelfWhen(repository.watchEquipmentChanges());

  return repository.getAllEquipment(diverId: validatedDiverId);
});

/// Equipment sort state provider
final equipmentSortProvider = StateProvider<SortState<EquipmentSortField>>(
  (ref) => const SortState(
    field: EquipmentSortField.name,
    direction: SortDirection.descending,
  ),
);

/// Apply sorting to a list of equipment items.
///
/// [serviceUrgency] is the most-urgent clock per equipment id (from
/// [equipmentServiceUrgencyProvider]); it is only consulted for the
/// [EquipmentSortField.serviceDue] field.
List<EquipmentItem> applyEquipmentSorting(
  List<EquipmentItem> equipment,
  SortState<EquipmentSortField> sort, {
  Map<String, ServiceClockStatus> serviceUrgency = const {},
}) {
  final sorted = List<EquipmentItem>.from(equipment);

  // Rank for the service-due sort: overdue (2) > dueSoon (1) > ok (0); items
  // with no clock rank -1 so they sort last on ascending (most-urgent first).
  int urgencyRank(EquipmentItem e) =>
      serviceUrgency[e.id]?.severity.index ?? -1;

  sorted.sort((a, b) {
    int comparison;
    // For text fields, invert direction (user expects descending = A→Z)
    final invertForText =
        sort.field == EquipmentSortField.name ||
        sort.field == EquipmentSortField.type;

    switch (sort.field) {
      case EquipmentSortField.name:
        comparison = a.name.compareTo(b.name);
      case EquipmentSortField.type:
        comparison = a.type.displayName.compareTo(b.type.displayName);
      case EquipmentSortField.purchaseDate:
        comparison = (a.purchaseDate ?? DateTime(1900)).compareTo(
          b.purchaseDate ?? DateTime(1900),
        );
      case EquipmentSortField.lastServiceDate:
        comparison = (a.lastServiceDate ?? DateTime(1900)).compareTo(
          b.lastServiceDate ?? DateTime(1900),
        );
      case EquipmentSortField.serviceDue:
        final ra = urgencyRank(a), rb = urgencyRank(b);
        int cmp;
        if (ra != rb) {
          // Higher rank = more urgent; ascending lists most urgent first.
          cmp = rb.compareTo(ra);
        } else {
          final da = serviceUrgency[a.id]?.dueDate;
          final db = serviceUrgency[b.id]?.dueDate;
          cmp = (da ?? DateTime(9999)).compareTo(db ?? DateTime(9999));
          // Deterministic tie-break: List.sort is not stable, so equal-urgency
          // items (common while the urgency map is empty/loading) could reorder
          // between rebuilds and flicker. Fall back to name, then id.
          if (cmp == 0) cmp = a.name.compareTo(b.name);
          if (cmp == 0) cmp = a.id.compareTo(b.id);
        }
        return sort.direction == SortDirection.ascending ? cmp : -cmp;
    }

    if (invertForText) {
      return sort.direction == SortDirection.ascending
          ? -comparison
          : comparison;
    }
    return sort.direction == SortDirection.ascending ? comparison : -comparison;
  });

  return sorted;
}

/// Single equipment item provider
final equipmentItemProvider = FutureProvider.family<EquipmentItem?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  return repository.getEquipmentById(id);
});

/// Dive count for equipment provider
final equipmentDiveCountProvider = FutureProvider.family<int, String>((
  ref,
  equipmentId,
) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  return repository.getDiveCountForEquipment(equipmentId);
});

/// Trip count for equipment provider
final equipmentTripCountProvider = FutureProvider.family<int, String>((
  ref,
  equipmentId,
) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  return repository.getTripCountForEquipment(equipmentId);
});

/// Trip IDs for equipment provider
final equipmentTripIdsProvider = FutureProvider.family<List<String>, String>((
  ref,
  equipmentId,
) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  return repository.getTripIdsForEquipment(equipmentId);
});

/// Equipment with service due provider
final serviceDueEquipmentProvider = FutureProvider<List<EquipmentItem>>((
  ref,
) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  ref.invalidateSelfWhen(repository.watchEquipmentChanges());
  return repository.getEquipmentWithServiceDue(diverId: validatedDiverId);
});

/// Equipment search provider
final equipmentSearchProvider =
    FutureProvider.family<List<EquipmentItem>, String>((ref, query) async {
      final validatedDiverId = await ref.watch(
        validatedCurrentDiverIdProvider.future,
      );
      if (query.isEmpty) {
        return ref.watch(allEquipmentProvider).value ?? [];
      }
      final repository = ref.watch(equipmentRepositoryProvider);
      return repository.searchEquipment(query, diverId: validatedDiverId);
    });

/// Equipment list notifier for mutations
class EquipmentListNotifier
    extends StateNotifier<AsyncValue<List<EquipmentItem>>> {
  final EquipmentRepository _repository;
  final Ref _ref;
  String? _validatedDiverId;

  EquipmentListNotifier(this._repository, this._ref)
    : super(const AsyncValue.loading()) {
    _initializeAndLoad();

    // Listen for diver changes and reload
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) {
        state = const AsyncValue.loading();
        _ref.invalidate(validatedCurrentDiverIdProvider);
        _ref.invalidate(allEquipmentProvider);
        _initializeAndLoad();
      }
    });
  }

  Future<void> _initializeAndLoad() async {
    state = const AsyncValue.loading();
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    _validatedDiverId = validatedId;
    await _loadEquipment();
  }

  Future<void> _loadEquipment() async {
    state = const AsyncValue.loading();
    try {
      final equipment = await _repository.getActiveEquipment(
        diverId: _validatedDiverId,
      );
      state = AsyncValue.data(equipment);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    // Get fresh validated diver ID before loading
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    _validatedDiverId = validatedId;
    await _loadEquipment();
    _ref.invalidate(activeEquipmentProvider);
    _ref.invalidate(retiredEquipmentProvider);
    _ref.invalidate(allEquipmentProvider);
    _ref.invalidate(serviceDueEquipmentProvider);
    // Invalidate all status filters
    for (final status in EquipmentStatus.values) {
      _ref.invalidate(equipmentByStatusProvider(status));
    }
    _ref.invalidate(equipmentByStatusProvider(null));
  }

  Future<EquipmentItem> addEquipment(EquipmentItem equipment) async {
    // Get fresh validated diver ID before creating
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);

    // Always set diverId to the current validated diver for new items
    final equipmentWithDiver = validatedId != null
        ? equipment.copyWith(diverId: validatedId)
        : equipment;
    final newEquipment = await _repository.createEquipment(equipmentWithDiver);
    await refresh();
    return newEquipment;
  }

  Future<void> updateEquipment(EquipmentItem equipment) async {
    await _repository.updateEquipment(equipment);
    await refresh();
  }

  Future<void> deleteEquipment(String id) async {
    await _repository.deleteEquipment(id);
    await refresh();
  }

  Future<void> markAsServiced(String id) async {
    await _repository.markAsServiced(id);
    await refresh();
  }

  Future<void> retireEquipment(String id) async {
    await _repository.retireEquipment(id);
    await refresh();
  }

  Future<void> reactivateEquipment(String id) async {
    await _repository.reactivateEquipment(id);
    await refresh();
  }
}

final equipmentListNotifierProvider =
    StateNotifierProvider<
      EquipmentListNotifier,
      AsyncValue<List<EquipmentItem>>
    >((ref) {
      final repository = ref.watch(equipmentRepositoryProvider);
      return EquipmentListNotifier(repository, ref);
    });

// ============================================================================
// Service Record Providers
// ============================================================================

/// Service record repository provider
final serviceRecordRepositoryProvider = Provider<ServiceRecordRepository>((
  ref,
) {
  return ServiceRecordRepository();
});

/// Service records for an equipment item
final serviceRecordsForEquipmentProvider =
    FutureProvider.family<List<ServiceRecord>, String>((
      ref,
      equipmentId,
    ) async {
      final repository = ref.watch(serviceRecordRepositoryProvider);
      return repository.getRecordsForEquipment(equipmentId);
    });

/// Single service record provider
final serviceRecordByIdProvider = FutureProvider.family<ServiceRecord?, String>(
  (ref, id) async {
    final repository = ref.watch(serviceRecordRepositoryProvider);
    return repository.getRecordById(id);
  },
);

/// Most recent service record for equipment
final mostRecentServiceRecordProvider =
    FutureProvider.family<ServiceRecord?, String>((ref, equipmentId) async {
      final repository = ref.watch(serviceRecordRepositoryProvider);
      return repository.getMostRecentRecord(equipmentId);
    });

/// Total service cost for equipment
final serviceRecordTotalCostProvider = FutureProvider.family<double, String>((
  ref,
  equipmentId,
) async {
  final repository = ref.watch(serviceRecordRepositoryProvider);
  return repository.getTotalServiceCost(equipmentId);
});

/// Service record count for equipment
final serviceRecordCountProvider = FutureProvider.family<int, String>((
  ref,
  equipmentId,
) async {
  final repository = ref.watch(serviceRecordRepositoryProvider);
  return repository.getRecordCount(equipmentId);
});

/// Service record notifier for mutations
class ServiceRecordNotifier
    extends StateNotifier<AsyncValue<List<ServiceRecord>>> {
  final ServiceRecordRepository _repository;
  final Ref _ref;
  final String equipmentId;

  ServiceRecordNotifier(this._repository, this._ref, this.equipmentId)
    : super(const AsyncValue.loading()) {
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    state = const AsyncValue.loading();
    try {
      final records = await _repository.getRecordsForEquipment(equipmentId);
      state = AsyncValue.data(records);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadRecords();
    _ref.invalidate(serviceRecordsForEquipmentProvider(equipmentId));
    _ref.invalidate(mostRecentServiceRecordProvider(equipmentId));
    _ref.invalidate(serviceRecordTotalCostProvider(equipmentId));
    _ref.invalidate(serviceRecordCountProvider(equipmentId));
    // Also refresh equipment to update lastServiceDate
    _ref.invalidate(equipmentItemProvider(equipmentId));
    // A new record of kind X resets clock X: re-evaluate clocks and lists.
    _ref.invalidate(serviceClockStatusesProvider(equipmentId));
    _ref.invalidate(dueClocksProvider);
  }

  Future<ServiceRecord> addRecord(ServiceRecord record) async {
    final newRecord = await _repository.createRecord(record);
    await refresh();
    return newRecord;
  }

  Future<void> updateRecord(ServiceRecord record) async {
    await _repository.updateRecord(record);
    await refresh();
    _ref.invalidate(serviceRecordByIdProvider(record.id));
  }

  Future<void> deleteRecord(String id) async {
    await _repository.deleteRecord(id);
    await refresh();
  }
}

final serviceRecordNotifierProvider =
    StateNotifierProvider.family<
      ServiceRecordNotifier,
      AsyncValue<List<ServiceRecord>>,
      String
    >((ref, equipmentId) {
      final repository = ref.watch(serviceRecordRepositoryProvider);
      return ServiceRecordNotifier(repository, ref, equipmentId);
    });

// ============================================================================
// Equipment Highlighted ID (for table mode detail pane)
// ============================================================================

/// Tracks the currently highlighted equipment item. Used by the table's
/// row highlight and by the phone-mode list to tint the last-visited
/// equipment card on return from the detail page.
final highlightedEquipmentIdProvider = StateProvider<String?>((ref) => null);

// ============================================================================
// Equipment Table View Config
// ============================================================================

/// Provider for the equipment table view column configuration.
///
/// Persists column visibility, order, widths, and sort state per diver using
/// [ViewConfigRepository] under the key 'table_equipment'.
final equipmentTableConfigProvider =
    StateNotifierProvider<
      EntityTableConfigNotifier<EquipmentField>,
      EntityTableViewConfig<EquipmentField>
    >((ref) {
      final notifier = EntityTableConfigNotifier<EquipmentField>(
        defaultConfig: EntityTableViewConfig<EquipmentField>(
          columns: [
            EntityTableColumnConfig(
              field: EquipmentField.itemName,
              isPinned: true,
            ),
            EntityTableColumnConfig(field: EquipmentField.type),
            EntityTableColumnConfig(field: EquipmentField.brand),
            EntityTableColumnConfig(field: EquipmentField.model),
            EntityTableColumnConfig(field: EquipmentField.status),
            EntityTableColumnConfig(field: EquipmentField.lastServiceDate),
          ],
        ),
        fieldFromName: EquipmentFieldAdapter.instance.fieldFromName,
      );
      final diverId = ref.watch(currentDiverIdProvider);
      if (diverId != null) {
        final repo = ref.watch(viewConfigRepositoryProvider);
        notifier.init(repo, diverId, 'table_equipment');
      }
      return notifier;
    });

// ============================================================================
// Equipment Card View Config
// ============================================================================

/// Default card slot configuration for the detailed equipment card view.
final equipmentDetailedCardConfigProvider =
    StateProvider<EntityCardViewConfig<EquipmentField>>(
      (ref) => const EntityCardViewConfig<EquipmentField>(
        slots: [
          EntityCardSlotConfig(slotId: 'title', field: EquipmentField.itemName),
          EntityCardSlotConfig(slotId: 'subtitle', field: EquipmentField.type),
          EntityCardSlotConfig(slotId: 'stat1', field: EquipmentField.brand),
          EntityCardSlotConfig(slotId: 'stat2', field: EquipmentField.status),
        ],
        extraFields: [],
      ),
    );

/// Default card slot configuration for the compact equipment card view.
final equipmentCompactCardConfigProvider =
    StateProvider<EntityCardViewConfig<EquipmentField>>(
      (ref) => const EntityCardViewConfig<EquipmentField>(
        slots: [
          EntityCardSlotConfig(slotId: 'title', field: EquipmentField.itemName),
          EntityCardSlotConfig(slotId: 'subtitle', field: EquipmentField.type),
          EntityCardSlotConfig(slotId: 'stat1', field: EquipmentField.brand),
          EntityCardSlotConfig(slotId: 'stat2', field: EquipmentField.status),
        ],
      ),
    );

// ---------------------------------------------------------------------------
// Service ledger (multi-clock service tracking)
// ---------------------------------------------------------------------------

/// One equipment item paired with one evaluated service clock, for
/// cross-equipment lists (dashboard card, trip alerts, list badges).
typedef DueClock = ({EquipmentItem item, ServiceClockStatus status});

final serviceKindRepositoryProvider = Provider<ServiceKindRepository>((ref) {
  return ServiceKindRepository();
});

final serviceScheduleRepositoryProvider = Provider<ServiceScheduleRepository>((
  ref,
) {
  return ServiceScheduleRepository();
});

/// Built-in kinds plus the current diver's custom kinds.
final serviceKindsProvider = FutureProvider<List<ServiceKind>>((ref) async {
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  return ref
      .watch(serviceKindRepositoryProvider)
      .getAllKinds(diverId: validatedDiverId);
});

/// The dueSoon window: the widest configured reminder-days value for the
/// current diver, so a clock turns amber as soon as its earliest reminder
/// would fire.
final serviceDueSoonWindowDaysProvider = FutureProvider<int>((ref) async {
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  return ref
      .watch(serviceScheduleRepositoryProvider)
      .getDueSoonWindowDays(diverId: validatedDiverId);
});

/// Evaluates every enabled clock on [item] at this moment.
Future<List<ServiceClockStatus>> _evaluateClocksFor(
  Ref ref,
  EquipmentItem item, {
  List<ServiceKind>? kinds,
}) async {
  final schedules = await ref
      .watch(serviceScheduleRepositoryProvider)
      .getSchedulesForEquipment(item.id);
  if (schedules.isEmpty) return const [];
  final allKinds =
      kinds ?? await ref.watch(serviceKindRepositoryProvider).getAllKinds();
  final records = await ref
      .watch(serviceRecordRepositoryProvider)
      .getRecordsForEquipment(item.id);
  final usage = await ref
      .watch(equipmentRepositoryProvider)
      .getUsageSamplesForEquipment(item.id);
  final window = await ref.watch(serviceDueSoonWindowDaysProvider.future);
  return const ServiceDueEngine().evaluate(
    schedules: schedules,
    kindsById: {for (final k in allKinds) k.id: k},
    records: records,
    usage: usage,
    purchaseDate: item.purchaseDate,
    equipmentCreatedAt: item.createdAt ?? DateTime.now(),
    dueSoonWindowDays: window,
    now: DateTime.now(),
  );
}

/// All evaluated clocks for one equipment item (detail page).
final serviceClockStatusesProvider =
    FutureProvider.family<List<ServiceClockStatus>, String>((
      ref,
      equipmentId,
    ) async {
      final repository = ref.watch(equipmentRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchEquipmentChanges());
      final item = await repository.getEquipmentById(equipmentId);
      if (item == null) return const [];
      return _evaluateClocksFor(ref, item);
    });

/// One active equipment item paired with every evaluated clock on it.
typedef EquipmentClocks = ({
  EquipmentItem item,
  List<ServiceClockStatus> statuses,
});

/// Evaluates the clocks of every active gear item exactly once. Both
/// [dueClocksProvider] (badges/dashboard/trip) and
/// [equipmentServiceUrgencyProvider] (sort/table columns) derive from this, so
/// a screen watching both pays the per-item DB evaluation (schedules + records
/// + usage + window) a single time instead of twice. Invalidate THIS provider
/// (not the derived ones) to force a re-evaluation after schedule/kind edits.
final activeEquipmentClocksProvider = FutureProvider<List<EquipmentClocks>>((
  ref,
) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  ref.invalidateSelfWhen(repository.watchEquipmentChanges());

  final items = await repository.getActiveEquipment(diverId: validatedDiverId);
  final kinds = await ref.watch(serviceKindRepositoryProvider).getAllKinds();
  return [
    for (final item in items)
      (item: item, statuses: await _evaluateClocksFor(ref, item, kinds: kinds)),
  ];
});

/// Every clock on active gear that is due soon or overdue, overdue first.
final dueClocksProvider = FutureProvider<List<DueClock>>((ref) async {
  final evaluated = await ref.watch(activeEquipmentClocksProvider.future);
  final due = <DueClock>[
    for (final e in evaluated)
      for (final s in e.statuses)
        if (s.severity != ServiceClockSeverity.ok) (item: e.item, status: s),
  ];
  due.sort((a, b) {
    if (a.status.severity != b.status.severity) {
      return b.status.severity.index.compareTo(a.status.severity.index);
    }
    final ad = a.status.dueDate, bd = b.status.dueDate;
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  });
  return due;
});

/// Worst due clock per equipment id (absent = all clocks ok); list badges
/// read this so they do not run per-row queries. dueClocksProvider is sorted
/// overdue-first, so the first clock seen per item is its worst.
final equipmentWorstClockProvider = FutureProvider<Map<String, DueClock>>((
  ref,
) async {
  final due = await ref.watch(dueClocksProvider.future);
  final worst = <String, DueClock>{};
  for (final d in due) {
    worst.putIfAbsent(d.item.id, () => d);
  }
  return worst;
});

/// Most-urgent clock per active equipment id, INCLUDING ok (not-yet-due)
/// clocks -- unlike [equipmentWorstClockProvider], which only carries due or
/// overdue clocks. Backs the service-due sort and the Next Service Due table
/// column so not-yet-due gear still sorts and displays its upcoming date.
final equipmentServiceUrgencyProvider =
    FutureProvider<Map<String, ServiceClockStatus>>((ref) async {
      final evaluated = await ref.watch(activeEquipmentClocksProvider.future);
      return {
        for (final e in evaluated)
          if (e.statuses.isNotEmpty)
            // Engine returns statuses worst-severity-first, then dueDate asc.
            e.item.id: e.statuses.first,
      };
    });

/// Clocks that block an upcoming trip: date trigger before the trip ends, or
/// already due/overdue now. Usage triggers are never forecast into the trip.
final tripServiceAlertsProvider = FutureProvider.family<List<DueClock>, String>(
  (ref, tripId) async {
    final trip = await ref.watch(tripByIdProvider(tripId).future);
    if (trip == null) return const [];

    final repository = ref.watch(equipmentRepositoryProvider);
    final validatedDiverId = await ref.watch(
      validatedCurrentDiverIdProvider.future,
    );
    ref.invalidateSelfWhen(repository.watchEquipmentChanges());

    final items = await repository.getActiveEquipment(
      diverId: validatedDiverId,
    );
    final kinds = await ref.watch(serviceKindRepositoryProvider).getAllKinds();
    final alerts = <DueClock>[];
    for (final item in items) {
      final statuses = await _evaluateClocksFor(ref, item, kinds: kinds);
      alerts.addAll([
        for (final s in statuses)
          if (s.severity == ServiceClockSeverity.overdue ||
              (s.dueDate != null && s.dueDate!.isBefore(trip.endDate)))
            (item: item, status: s),
      ]);
    }
    alerts.sort((a, b) {
      final ad = a.status.dueDate, bd = b.status.dueDate;
      if (ad == null && bd == null) return 0;
      if (ad == null) return -1; // usage-overdue first
      if (bd == null) return 1;
      return ad.compareTo(bd);
    });
    return alerts;
  },
);

/// Schedules (raw, unevaluated) for one item -- used by edit surfaces.
final serviceSchedulesForEquipmentProvider =
    FutureProvider.family<List<ServiceSchedule>, String>((
      ref,
      equipmentId,
    ) async {
      return ref
          .watch(serviceScheduleRepositoryProvider)
          .getSchedulesForEquipment(equipmentId);
    });
