import 'dart:io';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/wearables/data/services/fit_parser_service.dart';
import 'package:submersion/features/wearables/data/services/healthkit_service.dart';
import 'package:submersion/features/wearables/domain/entities/wearable_dive.dart';
import 'package:submersion/features/wearables/domain/services/dive_matcher.dart';
import 'package:submersion/features/wearables/domain/services/wearable_dive_converter.dart';
import 'package:submersion/features/wearables/domain/services/wearable_import_service.dart';
import 'package:submersion/features/wearables/presentation/widgets/wearable_dive_card.dart';

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

/// Provider for the wearable dive converter.
final wearableDiveConverterProvider = Provider<WearableDiveConverter>((ref) {
  return const WearableDiveConverter();
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
    this.isImporting = false,
    this.error,
    this.availableDives = const [],
    this.selectedDiveIds = const {},
    this.matchResults = const {},
    this.importedCount = 0,
    this.mergedCount = 0,
    this.skippedCount = 0,
  });

  final bool isLoading;
  final bool isImporting;
  final String? error;
  final List<WearableDive> availableDives;
  final Set<String> selectedDiveIds;
  final Map<String, WearableDiveMatchStatus> matchResults;
  final int importedCount;
  final int mergedCount;
  final int skippedCount;

  WearableImportState copyWith({
    bool? isLoading,
    bool? isImporting,
    String? error,
    List<WearableDive>? availableDives,
    Set<String>? selectedDiveIds,
    Map<String, WearableDiveMatchStatus>? matchResults,
    int? importedCount,
    int? mergedCount,
    int? skippedCount,
  }) {
    return WearableImportState(
      isLoading: isLoading ?? this.isLoading,
      isImporting: isImporting ?? this.isImporting,
      error: error,
      availableDives: availableDives ?? this.availableDives,
      selectedDiveIds: selectedDiveIds ?? this.selectedDiveIds,
      matchResults: matchResults ?? this.matchResults,
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

  /// Load pre-parsed dives directly into state.
  ///
  /// Used by FIT file import which parses files independently
  /// rather than fetching from a platform health API.
  void loadDives(List<WearableDive> dives) {
    state = state.copyWith(
      isLoading: false,
      error: null,
      availableDives: dives,
      selectedDiveIds: {},
      matchResults: {},
    );
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

  /// Check selected dives for duplicates against existing dive log.
  ///
  /// For each selected dive:
  /// 1. Exact match on wearableId -> alreadyImported
  /// 2. Fuzzy match score >= 0.7 -> probable
  /// 3. Fuzzy match score >= 0.5 -> possible
  /// 4. No match -> none
  Future<void> checkForDuplicates({
    required DiveRepository repository,
    required DiveMatcher matcher,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get all previously imported wearable IDs for exact matching
      final importedIds = await repository.getWearableIds();

      // Get existing dives in a wide range around selected dives
      final selectedDives = state.availableDives
          .where((d) => state.selectedDiveIds.contains(d.sourceId))
          .toList();

      if (selectedDives.isEmpty) {
        state = state.copyWith(isLoading: false, matchResults: {});
        return;
      }

      // Build a date range that covers all selected dives with padding
      final earliest = selectedDives
          .map((d) => d.startTime)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final latest = selectedDives
          .map((d) => d.endTime)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final rangeStart = earliest.subtract(const Duration(hours: 1));
      final rangeEnd = latest.add(const Duration(hours: 1));

      final existingDives = await repository.getDivesInRange(
        rangeStart,
        rangeEnd,
      );

      // Match each selected dive
      final results = <String, WearableDiveMatchStatus>{};

      for (final wDive in selectedDives) {
        // 1. Exact wearableId match
        if (importedIds.contains(wDive.sourceId)) {
          results[wDive.sourceId] = WearableDiveMatchStatus.alreadyImported;
          continue;
        }

        // 2. Fuzzy match against existing dives
        var bestScore = 0.0;
        for (final existing in existingDives) {
          final score = matcher.calculateMatchScore(
            wearableStartTime: wDive.startTime,
            wearableMaxDepth: wDive.maxDepth,
            wearableDurationSeconds: wDive.durationSeconds,
            existingStartTime: existing.effectiveEntryTime,
            existingMaxDepth: existing.maxDepth ?? 0,
            existingDurationSeconds: existing.duration?.inSeconds ?? 0,
          );
          if (score > bestScore) bestScore = score;
        }

        if (bestScore >= 0.7) {
          results[wDive.sourceId] = WearableDiveMatchStatus.probable;
        } else if (bestScore >= 0.5) {
          results[wDive.sourceId] = WearableDiveMatchStatus.possible;
        } else {
          results[wDive.sourceId] = WearableDiveMatchStatus.none;
        }
      }

      state = state.copyWith(isLoading: false, matchResults: results);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to check for duplicates: $e',
      );
    }
  }

  /// Import selected dives into the dive log.
  ///
  /// Skips dives marked as alreadyImported or probable duplicates.
  /// Imports all others (including possible duplicates — user chose them).
  Future<void> performImport({
    required DiveRepository repository,
    required WearableDiveConverter converter,
    String? diverId,
  }) async {
    state = state.copyWith(isImporting: true, error: null);

    var imported = 0;
    var skipped = 0;

    try {
      for (final sourceId in state.selectedDiveIds) {
        final wDive = state.getDiveById(sourceId);
        if (wDive == null) continue;

        final matchStatus = state.matchResults[sourceId];

        // Skip already imported and probable duplicates
        if (matchStatus == WearableDiveMatchStatus.alreadyImported ||
            matchStatus == WearableDiveMatchStatus.probable) {
          skipped++;
          continue;
        }

        // Get the next dive number for proper ordering
        final diveNumber = await repository.getDiveNumberForDate(
          wDive.startTime,
          diverId: diverId,
        );

        final dive = converter.convert(
          wDive,
          diverId: diverId,
          diveNumber: diveNumber,
        );

        await repository.createDive(dive);
        imported++;
      }

      state = state.copyWith(
        isImporting: false,
        importedCount: imported,
        mergedCount: 0,
        skippedCount: skipped,
      );
    } catch (e) {
      state = state.copyWith(
        isImporting: false,
        error: 'Failed to import dives: $e',
      );
    }
  }
}

/// Provider for the wearable import state notifier.
final wearableImportProvider =
    StateNotifierProvider<WearableImportNotifier, WearableImportState>((ref) {
      final service = ref.watch(wearableImportServiceProvider);
      return WearableImportNotifier(service);
    });

// ============================================================================
// FIT File Import Providers
// ============================================================================

/// Provider for the FIT parser service.
final fitParserServiceProvider = Provider<FitParserService>((ref) {
  return const FitParserService();
});

/// Provider for FIT file import state (separate from HealthKit import).
///
/// Uses null service since FIT import parses files directly via [loadDives]
/// rather than fetching from a platform health API.
final fitImportProvider =
    StateNotifierProvider<WearableImportNotifier, WearableImportState>((ref) {
      return WearableImportNotifier(null);
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
