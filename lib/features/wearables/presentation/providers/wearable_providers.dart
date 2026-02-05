import 'dart:io';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/wearables/data/services/healthkit_service.dart';
import 'package:submersion/features/wearables/domain/entities/wearable_dive.dart';
import 'package:submersion/features/wearables/domain/services/dive_matcher.dart';
import 'package:submersion/features/wearables/domain/services/wearable_import_service.dart';

// ============================================================================
// Service Providers
// ============================================================================

/// Provider for the HealthKit service (Apple platforms only).
final healthKitServiceProvider = Provider<HealthKitService?>((ref) {
  if (!Platform.isIOS && !Platform.isMacOS) {
    return null;
  }
  return HealthKitService();
});

/// Provider for the active wearable import service.
///
/// Currently returns HealthKitService on Apple platforms, null elsewhere.
/// Future: Could include Garmin, Suunto services based on platform/settings.
final wearableImportServiceProvider = Provider<WearableImportService?>((ref) {
  return ref.watch(healthKitServiceProvider);
});

/// Provider for the dive matcher service.
final diveMatcherProvider = Provider<DiveMatcher>((ref) {
  return const DiveMatcher();
});

// ============================================================================
// Availability Providers
// ============================================================================

/// Whether wearable import is available on this platform.
final wearableAvailableProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(wearableImportServiceProvider);
  if (service == null) return false;
  return service.isAvailable();
});

/// Whether we have HealthKit permissions.
final wearableHasPermissionsProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(wearableImportServiceProvider);
  if (service == null) return false;
  return service.hasPermissions();
});

// ============================================================================
// Import State Providers
// ============================================================================

/// State for the wearable import process.
class WearableImportState {
  const WearableImportState({
    this.isLoading = false,
    this.error,
    this.availableDives = const [],
    this.selectedDiveIds = const {},
    this.importedCount = 0,
    this.mergedCount = 0,
    this.skippedCount = 0,
  });

  final bool isLoading;
  final String? error;
  final List<WearableDive> availableDives;
  final Set<String> selectedDiveIds;
  final int importedCount;
  final int mergedCount;
  final int skippedCount;

  WearableImportState copyWith({
    bool? isLoading,
    String? error,
    List<WearableDive>? availableDives,
    Set<String>? selectedDiveIds,
    int? importedCount,
    int? mergedCount,
    int? skippedCount,
  }) {
    return WearableImportState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      availableDives: availableDives ?? this.availableDives,
      selectedDiveIds: selectedDiveIds ?? this.selectedDiveIds,
      importedCount: importedCount ?? this.importedCount,
      mergedCount: mergedCount ?? this.mergedCount,
      skippedCount: skippedCount ?? this.skippedCount,
    );
  }

  /// Total dives selected for import.
  int get selectedCount => selectedDiveIds.length;

  /// Whether any dives are selected.
  bool get hasSelection => selectedDiveIds.isNotEmpty;

  /// Get a dive by its source ID.
  WearableDive? getDiveById(String sourceId) {
    try {
      return availableDives.firstWhere((d) => d.sourceId == sourceId);
    } catch (_) {
      return null;
    }
  }

  /// Whether a dive is selected.
  bool isSelected(String sourceId) => selectedDiveIds.contains(sourceId);
}

/// StateNotifier for managing wearable import state.
class WearableImportNotifier extends StateNotifier<WearableImportState> {
  WearableImportNotifier(this._service) : super(const WearableImportState());

  final WearableImportService? _service;

  /// Request HealthKit permissions.
  Future<bool> requestPermissions() async {
    if (_service == null) return false;
    return _service.requestPermissions();
  }

  /// Fetch available dives from the wearable source.
  Future<void> fetchDives({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (_service == null) {
      state = state.copyWith(
        error: 'Wearable import not available on this platform',
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final dives = await _service.fetchDives(
        startDate: startDate,
        endDate: endDate,
      );

      state = state.copyWith(
        isLoading: false,
        availableDives: dives,
        selectedDiveIds: {}, // Reset selection
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to fetch dives: $e',
      );
    }
  }

  /// Toggle selection of a dive.
  void toggleSelection(String sourceId) {
    final newSelection = Set<String>.from(state.selectedDiveIds);
    if (newSelection.contains(sourceId)) {
      newSelection.remove(sourceId);
    } else {
      newSelection.add(sourceId);
    }
    state = state.copyWith(selectedDiveIds: newSelection);
  }

  /// Select all available dives.
  void selectAll() {
    state = state.copyWith(
      selectedDiveIds: state.availableDives.map((d) => d.sourceId).toSet(),
    );
  }

  /// Deselect all dives.
  void deselectAll() {
    state = state.copyWith(selectedDiveIds: {});
  }

  /// Clear the import state.
  void reset() {
    state = const WearableImportState();
  }

  /// Update import counts after processing.
  void updateCounts({
    required int imported,
    required int merged,
    required int skipped,
  }) {
    state = state.copyWith(
      importedCount: imported,
      mergedCount: merged,
      skippedCount: skipped,
    );
  }
}

/// Provider for the wearable import state notifier.
final wearableImportProvider =
    StateNotifierProvider<WearableImportNotifier, WearableImportState>((ref) {
      final service = ref.watch(wearableImportServiceProvider);
      return WearableImportNotifier(service);
    });

// ============================================================================
// Date Range Provider
// ============================================================================

/// State for the date range filter.
class DateRangeState {
  const DateRangeState({required this.startDate, required this.endDate});

  final DateTime startDate;
  final DateTime endDate;

  /// Default: last 30 days.
  factory DateRangeState.defaultRange() {
    final now = DateTime.now();
    return DateRangeState(
      startDate: now.subtract(const Duration(days: 30)),
      endDate: now,
    );
  }

  DateRangeState copyWith({DateTime? startDate, DateTime? endDate}) {
    return DateRangeState(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}

/// StateNotifier for date range selection.
class DateRangeNotifier extends StateNotifier<DateRangeState> {
  DateRangeNotifier() : super(DateRangeState.defaultRange());

  void setRange(DateTime start, DateTime end) {
    state = DateRangeState(startDate: start, endDate: end);
  }

  void setStartDate(DateTime start) {
    state = state.copyWith(startDate: start);
  }

  void setEndDate(DateTime end) {
    state = state.copyWith(endDate: end);
  }

  void resetToDefault() {
    state = DateRangeState.defaultRange();
  }
}

/// Provider for the import date range filter.
final importDateRangeProvider =
    StateNotifierProvider<DateRangeNotifier, DateRangeState>((ref) {
      return DateRangeNotifier();
    });
