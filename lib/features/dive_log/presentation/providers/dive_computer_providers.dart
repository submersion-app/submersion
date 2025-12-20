import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../divers/presentation/providers/diver_providers.dart';
import '../../data/repositories/dive_computer_repository_impl.dart';
import '../../domain/entities/dive_computer.dart';

/// Repository provider for dive computers
final diveComputerRepositoryProvider = Provider<DiveComputerRepository>((ref) {
  return DiveComputerRepository();
});

/// All dive computers
final allDiveComputersProvider = FutureProvider<List<DiveComputer>>((ref) async {
  final repository = ref.watch(diveComputerRepositoryProvider);
  final validatedDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.getAllComputers(diverId: validatedDiverId);
});

/// Get a dive computer by ID
final diveComputerByIdProvider =
    FutureProvider.family<DiveComputer?, String>((ref, id) async {
  final repository = ref.watch(diveComputerRepositoryProvider);
  return repository.getComputerById(id);
});

/// Get the favorite (primary) dive computer
final favoriteDiveComputerProvider = FutureProvider<DiveComputer?>((ref) async {
  final repository = ref.watch(diveComputerRepositoryProvider);
  final validatedDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.getFavoriteComputer(diverId: validatedDiverId);
});

/// Get dive computers for a specific dive
final computersForDiveProvider =
    FutureProvider.family<List<DiveComputer>, String>((ref, diveId) async {
  final repository = ref.watch(diveComputerRepositoryProvider);
  return repository.getComputersForDive(diveId);
});

/// Get the primary computer ID for a dive
final primaryComputerIdProvider =
    FutureProvider.family<String?, String>((ref, diveId) async {
  final repository = ref.watch(diveComputerRepositoryProvider);
  return repository.getPrimaryComputerId(diveId);
});

/// State notifier for selected computer on dive detail view
class SelectedComputerNotifier extends StateNotifier<String?> {
  final DiveComputerRepository _repository;
  final String _diveId;

  SelectedComputerNotifier(this._repository, this._diveId) : super(null) {
    _loadPrimaryComputer();
  }

  Future<void> _loadPrimaryComputer() async {
    final primaryId = await _repository.getPrimaryComputerId(_diveId);
    if (primaryId != null) {
      state = primaryId;
    } else {
      // Fall back to first available computer
      final computers = await _repository.getComputersForDive(_diveId);
      if (computers.isNotEmpty) {
        state = computers.first.id;
      }
    }
  }

  void selectComputer(String computerId) {
    state = computerId;
  }

  Future<void> setPrimaryComputer(String computerId) async {
    await _repository.setPrimaryProfile(_diveId, computerId);
    state = computerId;
  }
}

/// Provider for selected computer on dive detail view
final selectedComputerProvider = StateNotifierProvider.family<
    SelectedComputerNotifier, String?, String>((ref, diveId) {
  final repository = ref.watch(diveComputerRepositoryProvider);
  return SelectedComputerNotifier(repository, diveId);
});

/// State notifier for managing dive computers
class DiveComputerNotifier extends StateNotifier<AsyncValue<List<DiveComputer>>> {
  final DiveComputerRepository _repository;
  final Ref _ref;
  String? _validatedDiverId;

  DiveComputerNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
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
    await _load();
  }

  Future<void> _load() async {
    try {
      final computers = await _repository.getAllComputers(diverId: _validatedDiverId);
      state = AsyncValue.data(computers);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _load();
    _ref.invalidate(allDiveComputersProvider);
    _ref.invalidate(favoriteDiveComputerProvider);
  }

  Future<DiveComputer> create(DiveComputer computer) async {
    // Get fresh validated diver ID before creating
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);

    // Ensure diverId is set on new computers
    final computerWithDiver = computer.diverId == null && validatedId != null
        ? computer.copyWith(diverId: validatedId)
        : computer;
    final created = await _repository.createComputer(computerWithDiver);
    await _load();
    return created;
  }

  Future<void> update(DiveComputer computer) async {
    await _repository.updateComputer(computer);
    await _load();
  }

  Future<void> delete(String id) async {
    await _repository.deleteComputer(id);
    await _load();
  }

  Future<void> setFavorite(String id) async {
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    await _repository.setFavoriteComputer(id, diverId: validatedId);
    await _load();
  }
}

/// Provider for dive computer management
final diveComputerNotifierProvider =
    StateNotifierProvider<DiveComputerNotifier, AsyncValue<List<DiveComputer>>>(
        (ref) {
  final repository = ref.watch(diveComputerRepositoryProvider);
  return DiveComputerNotifier(repository, ref);
});

/// State for dive profile viewing (which computer's profile to display)
class DiveProfileViewState {
  /// Currently selected computer ID (null = merged/primary)
  final String? selectedComputerId;

  /// Whether to show ceiling curve
  final bool showCeiling;

  /// Whether to show ascent rate coloring
  final bool showAscentRate;

  /// Whether to show events
  final bool showEvents;

  /// Whether to show temperature curve
  final bool showTemperature;

  /// Whether to show tank pressure curve
  final bool showPressure;

  const DiveProfileViewState({
    this.selectedComputerId,
    this.showCeiling = true,
    this.showAscentRate = true,
    this.showEvents = true,
    this.showTemperature = false,
    this.showPressure = false,
  });

  DiveProfileViewState copyWith({
    String? selectedComputerId,
    bool? showCeiling,
    bool? showAscentRate,
    bool? showEvents,
    bool? showTemperature,
    bool? showPressure,
    bool clearComputerId = false,
  }) {
    return DiveProfileViewState(
      selectedComputerId: clearComputerId ? null : (selectedComputerId ?? this.selectedComputerId),
      showCeiling: showCeiling ?? this.showCeiling,
      showAscentRate: showAscentRate ?? this.showAscentRate,
      showEvents: showEvents ?? this.showEvents,
      showTemperature: showTemperature ?? this.showTemperature,
      showPressure: showPressure ?? this.showPressure,
    );
  }
}

/// State notifier for dive profile view state
class DiveProfileViewNotifier extends StateNotifier<DiveProfileViewState> {
  DiveProfileViewNotifier() : super(const DiveProfileViewState());

  void selectComputer(String? computerId) {
    state = state.copyWith(
      selectedComputerId: computerId,
      clearComputerId: computerId == null,
    );
  }

  void toggleCeiling() {
    state = state.copyWith(showCeiling: !state.showCeiling);
  }

  void toggleAscentRate() {
    state = state.copyWith(showAscentRate: !state.showAscentRate);
  }

  void toggleEvents() {
    state = state.copyWith(showEvents: !state.showEvents);
  }

  void toggleTemperature() {
    state = state.copyWith(showTemperature: !state.showTemperature);
  }

  void togglePressure() {
    state = state.copyWith(showPressure: !state.showPressure);
  }

  void setCeiling(bool show) {
    state = state.copyWith(showCeiling: show);
  }

  void setAscentRate(bool show) {
    state = state.copyWith(showAscentRate: show);
  }

  void setEvents(bool show) {
    state = state.copyWith(showEvents: show);
  }

  void reset() {
    state = const DiveProfileViewState();
  }
}

/// Provider for dive profile view state
final diveProfileViewProvider =
    StateNotifierProvider.family<DiveProfileViewNotifier, DiveProfileViewState, String>(
        (ref, diveId) {
  return DiveProfileViewNotifier();
});
