import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/enums.dart';
// The dependency-only module, not dive_providers.dart: that file imports
// trip_providers.dart, which imports this feature's repository impl.
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
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
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/domain/models/equipment_picker_filter.dart';
import 'package:submersion/features/equipment/domain/services/exposure_classifier.dart';
import 'package:submersion/features/equipment/domain/services/service_due_engine.dart';
import 'package:submersion/features/equipment/presentation/providers/exposure_thresholds_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/notifications/presentation/providers/notification_providers.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';
import 'package:submersion/core/utils/log_failure.dart';

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
  ref.invalidateSelfWhen(repository.watchEquipmentChanges());
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
  ref.invalidateSelfWhen(repository.watchEquipmentChanges());
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

/// Equipment filter state provider.
///
/// Holds the status and category axes edited in the equipment filter panel.
/// Kept outside the list widget so the panel can be opened from any of the
/// three layouts (phone app bar, master-detail compact bar, table mode's
/// TableModeLayout actions) and they all narrow the same list.
final equipmentFilterProvider = StateProvider<EquipmentFilterState>(
  (ref) => const EquipmentFilterState(),
);

/// The gear categories the diver actually owns, in [EquipmentType] order.
///
/// Drives the filter panel's category chips so it never offers a type with no
/// gear behind it. Derived from every item -- including retired -- because the
/// status axis can put retired gear back on screen.
final ownedEquipmentTypesProvider = Provider<List<EquipmentType>>((ref) {
  final all = ref.watch(allEquipmentProvider).value ?? const <EquipmentItem>[];
  final present = all.map((e) => e.type).toSet();
  return EquipmentType.values.where(present.contains).toList();
});

/// The Add Equipment picker's own filter (#1576).
///
/// Separate from [equipmentFilterProvider], which belongs to the Equipment
/// page: sharing one would mean narrowing the gear list silently narrowed the
/// dive picker, which is not what either control implies.
///
/// autoDispose so it resets when the picker closes. A plain StateProvider
/// lives for the whole ProviderContainer, i.e. the app session, so a
/// narrowing applied to find one regulator would still be hiding gear the
/// next time a dive's picker opened, with only a badge to explain the short
/// list. The picker is the sole listener, so losing it is exactly the signal
/// that the narrowing is done with.
final equipmentPickerFilterProvider =
    StateProvider.autoDispose<EquipmentPickerFilter>(
      (ref) => EquipmentPickerFilter.none,
    );

/// Equipment sort state provider.
///
/// Ascending means A to Z and oldest first, the same as the dive surfaces'
/// `EquipmentArrangement`, because both sheets now share one layout and the
/// same arrow must mean the same thing on each.
final equipmentSortProvider = StateProvider<SortState<EquipmentSortField>>(
  (ref) => const SortState(
    field: EquipmentSortField.name,
    direction: SortDirection.ascending,
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
  return List<EquipmentItem>.from(equipment)
    ..sort(equipmentSortComparator(sort, serviceUrgency: serviceUrgency));
}

/// The Equipment page's item order as a comparator.
///
/// Separate from [applyEquipmentSorting] so the grouped list can hand it to
/// `arrangeEquipment`, which orders the type axis itself and needs only the
/// order inside each group.
///
/// Matches the arranger's conventions: names compare case-insensitively,
/// undated gear sorts last in both directions, and every field falls through
/// to a name-then-id tie-break that is never inverted. List.sort is not
/// stable, so without the tie-break equal items reorder between rebuilds.
Comparator<EquipmentItem> equipmentSortComparator(
  SortState<EquipmentSortField> sort, {
  Map<String, ServiceClockStatus> serviceUrgency = const {},
}) {
  // Rank for the service-due sort: overdue (2) > dueSoon (1) > ok (0); items
  // with no clock rank -1 so they sort last on ascending (most-urgent first).
  int urgencyRank(EquipmentItem e) =>
      serviceUrgency[e.id]?.severity.index ?? -1;

  // Lowercased once per item rather than per comparison, as the arranger does.
  final lowerNames = <String, String>{};
  String lowerName(EquipmentItem item) =>
      lowerNames[item.id] ??= item.name.toLowerCase();

  DateTime? dateOf(EquipmentItem item) => switch (sort.field) {
    EquipmentSortField.purchaseDate => item.purchaseDate,
    EquipmentSortField.lastServiceDate => item.lastServiceDate,
    _ => null,
  };
  final byDate =
      sort.field == EquipmentSortField.purchaseDate ||
      sort.field == EquipmentSortField.lastServiceDate;

  return (a, b) {
    if (byDate) {
      // Undated gear sorts last in BOTH directions, so flipping the direction
      // never buries the dated items the diver was looking for.
      final aMissing = dateOf(a) == null;
      final bMissing = dateOf(b) == null;
      if (aMissing != bMissing) return aMissing ? 1 : -1;
    }

    int primary;
    switch (sort.field) {
      case EquipmentSortField.name:
        primary = lowerName(a).compareTo(lowerName(b));
      case EquipmentSortField.purchaseDate:
      case EquipmentSortField.lastServiceDate:
        final da = dateOf(a), db = dateOf(b);
        primary = da == null || db == null ? 0 : da.compareTo(db);
      case EquipmentSortField.serviceDue:
        final ra = urgencyRank(a), rb = urgencyRank(b);
        if (ra != rb) {
          // Higher rank = more urgent; ascending lists most urgent first.
          primary = rb.compareTo(ra);
        } else {
          final da = serviceUrgency[a.id]?.dueDate;
          final db = serviceUrgency[b.id]?.dueDate;
          primary = (da ?? DateTime(9999)).compareTo(db ?? DateTime(9999));
        }
    }
    if (sort.direction == SortDirection.descending) primary = -primary;
    if (primary != 0) return primary;

    final byName = lowerName(a).compareTo(lowerName(b));
    return byName != 0 ? byName : a.id.compareTo(b.id);
  };
}

/// Single equipment item provider
final equipmentItemProvider = FutureProvider.family<EquipmentItem?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchEquipmentChanges());
  return repository.getEquipmentById(id);
});

/// The active children installed in a parent, for the children card
/// (condition phase 4a): cells by slot, then batteries, then any other part
/// by type name, each group by name after that. The order is spelled out
/// rather than read from `EquipmentType.index`, which only records when each
/// type was added.
final childEquipmentProvider =
    FutureProvider.family<List<EquipmentItem>, String>((ref, parentId) async {
      final repository = ref.watch(equipmentRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchEquipmentChanges());
      // Slots and install dates are attributes, written without touching
      // the equipment row.
      ref.invalidateSelfWhen(repository.watchAttributeChanges());
      final children = await repository.getChildEquipment(parentId);
      int slotOf(EquipmentItem e) => e.cellSlot ?? 1 << 20;
      int rankOf(EquipmentType t) => switch (t) {
        EquipmentType.o2Cell => 0,
        EquipmentType.battery => 1,
        _ => 2,
      };
      // isFitted, not isActive: a legacy row can be retired or sold with
      // isActive left true, and must not show as an installed part.
      return children.where((c) => c.isFitted).toList()..sort((a, b) {
        final byRank = rankOf(a.type).compareTo(rankOf(b.type));
        if (byRank != 0) return byRank;
        final byType = a.type.name.compareTo(b.type.name);
        if (byType != 0) return byType;
        final bySlot = slotOf(a).compareTo(slotOf(b));
        if (bySlot != 0) return bySlot;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    });

/// Dive count for equipment provider.
///
/// Backs the "Used on N dives" figure. A junction read over `dive_equipment`,
/// whose rows vanish by cascade when a dive is deleted, so it over-counted
/// after a merge until it took the dives tick as well (issue #974).
final equipmentDiveCountProvider = FutureProvider.family<int, String>((
  ref,
  equipmentId,
) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchEquipmentChanges());
  ref.invalidateSelfWhen(ref.read(diveRepositoryProvider).watchDivesChanges());
  return repository.getDiveCountForEquipment(equipmentId);
});

/// Trip count for equipment provider.
///
/// Reaches trips through the equipment's dives, so it takes the trips tick as
/// well: deleting a trip changes the count without writing `equipment`.
final equipmentTripCountProvider = FutureProvider.family<int, String>((
  ref,
  equipmentId,
) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchEquipmentChanges());
  ref.invalidateSelfWhen(ref.read(tripRepositoryProvider).watchTripsChanges());
  return repository.getTripCountForEquipment(equipmentId);
});

/// Trip IDs for equipment provider.
///
/// Same junction read as [equipmentTripCountProvider].
final equipmentTripIdsProvider = FutureProvider.family<List<String>, String>((
  ref,
  equipmentId,
) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchEquipmentChanges());
  ref.invalidateSelfWhen(ref.read(tripRepositoryProvider).watchTripsChanges());
  return repository.getTripIdsForEquipment(equipmentId);
});

/// Active gear with at least one service clock due soon or overdue, worst
/// first.
///
/// Reads the service ledger (schedules + records + usage, via
/// [dueClocksProvider]), the same source as the row badges and the dashboard
/// card. It must not go back to the legacy `EquipmentItem.isServiceDue`
/// getter: that reads `serviceIntervalDays`, a column the v122/v131
/// migrations copied into the ledger and no in-app editor writes any more, so
/// the Service Due filter always came back empty while the badges said
/// overdue.
final serviceDueEquipmentProvider = FutureProvider<List<EquipmentItem>>((
  ref,
) async {
  final due = await ref.watch(dueClocksProvider.future);
  final items = <String, EquipmentItem>{};
  for (final clock in due) {
    items.putIfAbsent(clock.item.id, () => clock.item);
  }
  return items.values.toList();
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
      ref.invalidateSelfWhen(repository.watchEquipmentChanges());
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
    logFailure(
      _initializeAndLoad(),
      EquipmentListNotifier,
      'initialize and load',
    );

    // Listen for diver changes and reload
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) {
        state = const AsyncValue.loading();
        _ref.invalidate(validatedCurrentDiverIdProvider);
        _ref.invalidate(allEquipmentProvider);
        logFailure(
          _initializeAndLoad(),
          EquipmentListNotifier,
          'initialize and load',
        );
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
    // The service-due list derives from the clock evaluation, which caches per
    // item; invalidating the leaf alone would replay the cached verdicts.
    _ref.invalidate(activeEquipmentClocksProvider);
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
      ref.invalidateSelfWhen(repository.watchServiceRecordsChanges());
      return repository.getRecordsForEquipment(equipmentId);
    });

/// Single service record provider
final serviceRecordByIdProvider = FutureProvider.family<ServiceRecord?, String>(
  (ref, id) async {
    final repository = ref.watch(serviceRecordRepositoryProvider);
    ref.invalidateSelfWhen(repository.watchServiceRecordsChanges());
    return repository.getRecordById(id);
  },
);

/// Most recent service record for equipment
final mostRecentServiceRecordProvider =
    FutureProvider.family<ServiceRecord?, String>((ref, equipmentId) async {
      final repository = ref.watch(serviceRecordRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchServiceRecordsChanges());
      return repository.getMostRecentRecord(equipmentId);
    });

/// Service record count for equipment
final serviceRecordCountProvider = FutureProvider.family<int, String>((
  ref,
  equipmentId,
) async {
  final repository = ref.watch(serviceRecordRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchServiceRecordsChanges());
  return repository.getRecordCount(equipmentId);
});

/// Service record notifier for mutations
class ServiceRecordNotifier
    extends StateNotifier<AsyncValue<List<ServiceRecord>>> {
  static final _log = LoggerService.forClass(ServiceRecordNotifier);
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
    _ref.invalidate(serviceRecordCountProvider(equipmentId));
    // Also refresh equipment to update lastServiceDate
    _ref.invalidate(equipmentItemProvider(equipmentId));
    // A new record of kind X resets clock X: re-evaluate clocks and lists.
    _ref.invalidate(serviceClockStatusesProvider(equipmentId));
    // The base evaluation, not the derived lists: dueClocksProvider and the
    // service-due list would otherwise rebuild off its cached verdicts.
    _ref.invalidate(activeEquipmentClocksProvider);
    await _rescheduleNotifications();
  }

  /// A record moves the clock anchor, so a usage reminder armed for the old
  /// anchor may no longer be due. Re-evaluate this item's reminders now
  /// rather than at the next app start; a failure here must not fail the
  /// record write.
  Future<void> _rescheduleNotifications() async {
    try {
      final settings = _ref.read(settingsProvider);
      if (!settings.notificationsEnabled) return;
      final item = await _ref
          .read(equipmentRepositoryProvider)
          .getEquipmentById(equipmentId);
      if (item == null) return;
      await _ref
          .read(notificationSchedulerProvider)
          .updateForEquipment(item: item, globalSettings: settings);
    } catch (e, stackTrace) {
      _log.warning(
        'Failed to reschedule reminders after a service record',
        error: e,
        stackTrace: stackTrace,
      );
    }
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
  final repository = ref.watch(serviceKindRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchServiceKindsChanges());
  return repository.getAllKinds(diverId: validatedDiverId);
});

/// The dueSoon window: the widest configured reminder-days value for the
/// current diver, so a clock turns amber as soon as its earliest reminder
/// would fire.
final serviceDueSoonWindowDaysProvider = FutureProvider<int>((ref) async {
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  final repository = ref.watch(serviceScheduleRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchSchedulesChanges());
  return repository.getDueSoonWindowDays(diverId: validatedDiverId);
});

/// Evaluates every enabled clock on [item] at this moment. [siblings] is the
/// active gear list when the caller already has it, so the parent and
/// children lookups cost no query per item.
Future<List<ServiceClockStatus>> _evaluateClocksFor(
  Ref ref,
  EquipmentItem item, {
  List<ServiceKind>? kinds,
  List<EquipmentItem>? siblings,
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
  // A transmitter's dives include the tanks that carried its registered
  // serials, and assigning a serial writes only the registry.
  if (item.type == EquipmentType.transmitter) {
    ref.invalidateSelfWhen(
      ref.watch(transmitterRepositoryProvider).watchTransmittersChanges(),
    );
  }
  // The repository's one wiring, shared with the exposure card, the
  // reminders and the condition engine: fitted parts only, and a replaced
  // part's dives stop at its successor.
  final exposure = await ref
      .watch(equipmentRepositoryProvider)
      .getItemExposure(item, siblings: siblings);
  final usage = exposure.samples;
  final classifier = ExposureClassifier(
    thresholds: ref.watch(exposureThresholdsProvider),
    loopTimeOnly: exposure.isRebreather,
    hasBatteryChild: exposure.fittedChildren.any(
      (c) => c.type == EquipmentType.battery,
    ),
  );
  final window = await ref.watch(serviceDueSoonWindowDaysProvider.future);
  return const ServiceDueEngine().evaluate(
    schedules: schedules,
    kindsById: {for (final k in allKinds) k.id: k},
    records: records,
    usage: usage,
    classifier: classifier,
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
      // The same inputs as the item page's exposure card, so the two never
      // disagree: install dates and slots live in the attribute table, and
      // a dive link or profile edit writes no equipment row.
      ref.invalidateSelfWhen(repository.watchAttributeChanges());
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
      );
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
  // Install dates and slots decide which dives a part owns. Rare writes,
  // unlike the dive detail stream (media ticks it), which would re-evaluate
  // every item's clocks far too often for a list-wide provider.
  ref.invalidateSelfWhen(repository.watchAttributeChanges());

  final items = await repository.getActiveEquipment(diverId: validatedDiverId);
  final kinds = await ref.watch(serviceKindRepositoryProvider).getAllKinds();
  return [
    for (final item in items)
      (
        item: item,
        statuses: await _evaluateClocksFor(
          ref,
          item,
          kinds: kinds,
          siblings: items,
        ),
      ),
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
      final statuses = await _evaluateClocksFor(
        ref,
        item,
        kinds: kinds,
        siblings: items,
      );
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
      final repository = ref.watch(serviceScheduleRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchSchedulesChanges());
      return repository.getSchedulesForEquipment(equipmentId);
    });
