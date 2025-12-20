import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../divers/presentation/providers/diver_providers.dart';
import '../../data/repositories/equipment_repository_impl.dart';
import '../../data/repositories/service_record_repository.dart';
import '../../domain/entities/equipment_item.dart';
import '../../domain/entities/service_record.dart';

/// Repository provider
final equipmentRepositoryProvider = Provider<EquipmentRepository>((ref) {
  return EquipmentRepository();
});

/// Active equipment provider
final activeEquipmentProvider = FutureProvider<List<EquipmentItem>>((ref) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  final validatedDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.getActiveEquipment(diverId: validatedDiverId);
});

/// Retired equipment provider
final retiredEquipmentProvider = FutureProvider<List<EquipmentItem>>((ref) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  final validatedDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.getRetiredEquipment(diverId: validatedDiverId);
});

/// Equipment by status provider
final equipmentByStatusProvider = FutureProvider.family<List<EquipmentItem>, EquipmentStatus?>((ref, status) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  final validatedDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  if (status == null) {
    return repository.getAllEquipment(diverId: validatedDiverId);
  }
  return repository.getEquipmentByStatus(status);
});

/// All equipment provider
final allEquipmentProvider = FutureProvider<List<EquipmentItem>>((ref) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  final validatedDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.getAllEquipment(diverId: validatedDiverId);
});

/// Single equipment item provider
final equipmentItemProvider = FutureProvider.family<EquipmentItem?, String>((ref, id) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  return repository.getEquipmentById(id);
});

/// Equipment with service due provider
final serviceDueEquipmentProvider = FutureProvider<List<EquipmentItem>>((ref) async {
  final repository = ref.watch(equipmentRepositoryProvider);
  return repository.getEquipmentWithServiceDue();
});

/// Equipment search provider
final equipmentSearchProvider = FutureProvider.family<List<EquipmentItem>, String>((ref, query) async {
  if (query.isEmpty) {
    return ref.watch(allEquipmentProvider).value ?? [];
  }
  final repository = ref.watch(equipmentRepositoryProvider);
  return repository.searchEquipment(query);
});

/// Equipment list notifier for mutations
class EquipmentListNotifier extends StateNotifier<AsyncValue<List<EquipmentItem>>> {
  final EquipmentRepository _repository;
  final Ref _ref;
  String? _validatedDiverId;

  EquipmentListNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    _initializeAndLoad();

    // Listen for diver changes and reload
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) {
        _initializeAndLoad();
      }
    });
  }

  Future<void> _initializeAndLoad() async {
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    _validatedDiverId = validatedId;
    await _loadEquipment();
  }

  Future<void> _loadEquipment() async {
    state = const AsyncValue.loading();
    try {
      final equipment = await _repository.getActiveEquipment(diverId: _validatedDiverId);
      state = AsyncValue.data(equipment);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadEquipment();
    _ref.invalidate(retiredEquipmentProvider);
    _ref.invalidate(serviceDueEquipmentProvider);
  }

  Future<EquipmentItem> addEquipment(EquipmentItem equipment) async {
    // Get fresh validated diver ID before creating
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);

    // Ensure diverId is set on new equipment
    final equipmentWithDiver = equipment.diverId == null && validatedId != null
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
    StateNotifierProvider<EquipmentListNotifier, AsyncValue<List<EquipmentItem>>>((ref) {
  final repository = ref.watch(equipmentRepositoryProvider);
  return EquipmentListNotifier(repository, ref);
});

// ============================================================================
// Service Record Providers
// ============================================================================

/// Service record repository provider
final serviceRecordRepositoryProvider = Provider<ServiceRecordRepository>((ref) {
  return ServiceRecordRepository();
});

/// Service records for an equipment item
final serviceRecordsForEquipmentProvider =
    FutureProvider.family<List<ServiceRecord>, String>((ref, equipmentId) async {
  final repository = ref.watch(serviceRecordRepositoryProvider);
  return repository.getRecordsForEquipment(equipmentId);
});

/// Single service record provider
final serviceRecordByIdProvider =
    FutureProvider.family<ServiceRecord?, String>((ref, id) async {
  final repository = ref.watch(serviceRecordRepositoryProvider);
  return repository.getRecordById(id);
});

/// Most recent service record for equipment
final mostRecentServiceRecordProvider =
    FutureProvider.family<ServiceRecord?, String>((ref, equipmentId) async {
  final repository = ref.watch(serviceRecordRepositoryProvider);
  return repository.getMostRecentRecord(equipmentId);
});

/// Total service cost for equipment
final serviceRecordTotalCostProvider =
    FutureProvider.family<double, String>((ref, equipmentId) async {
  final repository = ref.watch(serviceRecordRepositoryProvider);
  return repository.getTotalServiceCost(equipmentId);
});

/// Service record count for equipment
final serviceRecordCountProvider =
    FutureProvider.family<int, String>((ref, equipmentId) async {
  final repository = ref.watch(serviceRecordRepositoryProvider);
  return repository.getRecordCount(equipmentId);
});

/// Service record notifier for mutations
class ServiceRecordNotifier extends StateNotifier<AsyncValue<List<ServiceRecord>>> {
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

final serviceRecordNotifierProvider = StateNotifierProvider.family<
    ServiceRecordNotifier, AsyncValue<List<ServiceRecord>>, String>((ref, equipmentId) {
  final repository = ref.watch(serviceRecordRepositoryProvider);
  return ServiceRecordNotifier(repository, ref, equipmentId);
});
