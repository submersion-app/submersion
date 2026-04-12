import 'dart:async';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/view_config_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/view_field_config.dart'
    as domain;

import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

export 'package:submersion/features/dive_log/domain/entities/view_field_config.dart'
    show
        TableViewConfig,
        TableColumnConfig,
        CardViewConfig,
        CardSlotConfig,
        FieldPreset;

// ---------------------------------------------------------------------------
// Repository provider
// ---------------------------------------------------------------------------

/// Singleton provider for [ViewConfigRepository].
final viewConfigRepositoryProvider = Provider<ViewConfigRepository>((ref) {
  return ViewConfigRepository(DatabaseService.instance.database);
});

// ---------------------------------------------------------------------------
// TableViewConfigNotifier
// ---------------------------------------------------------------------------

/// StateNotifier that manages in-memory [domain.TableViewConfig] state and
/// debounces persistence to the database.
class TableViewConfigNotifier extends StateNotifier<domain.TableViewConfig> {
  ViewConfigRepository? _repository;
  String? _diverId;
  Timer? _saveTimer;

  TableViewConfigNotifier() : super(domain.TableViewConfig.defaultConfig());

  /// Load the saved config from the database for [diverId].
  Future<void> init(ViewConfigRepository repository, String diverId) async {
    _repository = repository;
    _diverId = diverId;
    final loaded = await repository.getTableConfig(diverId);
    if (!mounted) return;
    state = loaded;
  }

  /// Cancel any pending save timer on dispose.
  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Mutations
  // -------------------------------------------------------------------------

  /// Add or remove [field] from the column list.
  ///
  /// Pinned columns cannot be removed.
  void toggleColumn(DiveField field) {
    final existing = state.columns.where((c) => c.field == field).firstOrNull;
    if (existing != null) {
      if (existing.isPinned) return;
      state = state.copyWith(
        columns: state.columns.where((c) => c.field != field).toList(),
      );
    } else {
      state = state.copyWith(
        columns: [
          ...state.columns,
          domain.TableColumnConfig(field: field),
        ],
      );
    }
    _save();
  }

  /// Cycle sort for [field]: unsorted -> ascending -> descending -> unsorted.
  void setSortField(DiveField field) {
    if (state.sortField != field) {
      // New field: set ascending
      state = state.copyWith(sortField: field, sortAscending: true);
    } else if (state.sortAscending) {
      // Was ascending: switch to descending
      state = state.copyWith(sortAscending: false);
    } else {
      // Was descending: clear sort
      state = state.copyWith(clearSortField: true, sortAscending: true);
    }
    _save();
  }

  /// Resize [field] column, clamping to [[minWidth], 600].
  void resizeColumn(DiveField field, double width) {
    final clamped = width.clamp(field.minWidth, 600.0);
    state = state.copyWith(
      columns: state.columns
          .map((c) => c.field == field ? c.copyWith(width: clamped) : c)
          .toList(),
    );
    _save();
  }

  /// Move column at [oldIndex] to [newIndex].
  void reorderColumn(int oldIndex, int newIndex) {
    final cols = List<domain.TableColumnConfig>.from(state.columns);
    final item = cols.removeAt(oldIndex);
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    cols.insert(target.clamp(0, cols.length), item);
    state = state.copyWith(columns: cols);
    _save();
  }

  /// Toggle the pinned state for [field].
  void togglePin(DiveField field) {
    state = state.copyWith(
      columns: state.columns
          .map((c) => c.field == field ? c.copyWith(isPinned: !c.isPinned) : c)
          .toList(),
    );
    _save();
  }

  /// Replace the current config with the config encoded in [preset].
  void applyPreset(domain.FieldPreset preset) {
    state = domain.TableViewConfig.fromJson(preset.configJson);
    _save();
  }

  /// Replace the config directly (used for external sync or reset).
  void replaceConfig(domain.TableViewConfig config) {
    state = config;
    _save();
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  void _save() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      final repo = _repository;
      final diverId = _diverId;
      if (repo != null && diverId != null) {
        repo.saveTableConfig(diverId, state);
      }
    });
  }
}

/// Provider for [TableViewConfigNotifier].
///
/// Automatically loads the persisted config for the current diver and
/// reloads when the active diver changes.
final tableViewConfigProvider =
    StateNotifierProvider<TableViewConfigNotifier, domain.TableViewConfig>((
      ref,
    ) {
      final notifier = TableViewConfigNotifier();
      final diverId = ref.watch(currentDiverIdProvider);
      if (diverId != null) {
        final repo = ref.watch(viewConfigRepositoryProvider);
        notifier.init(repo, diverId);
      }
      return notifier;
    });

// ---------------------------------------------------------------------------
// CardViewConfigNotifier
// ---------------------------------------------------------------------------

/// StateNotifier that manages in-memory [domain.CardViewConfig] state and
/// debounces persistence to the database.
class CardViewConfigNotifier extends StateNotifier<domain.CardViewConfig> {
  ViewConfigRepository? _repository;
  String? _diverId;
  ListViewMode? _mode;
  Timer? _saveTimer;

  CardViewConfigNotifier() : super(domain.CardViewConfig.defaultCompact());

  /// Named constructor for tests that need a specific starting mode.
  CardViewConfigNotifier.withMode(ListViewMode mode)
    : _mode = mode,
      super(_defaultForMode(mode));

  /// Load the saved config from the database for [diverId] and [mode].
  Future<void> init(
    ViewConfigRepository repository,
    String diverId,
    ListViewMode mode,
  ) async {
    _repository = repository;
    _diverId = diverId;
    _mode = mode;
    final loaded = await repository.getCardConfig(diverId, mode);
    if (!mounted) return;
    state = loaded;
  }

  /// Cancel any pending save timer on dispose.
  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Mutations
  // -------------------------------------------------------------------------

  /// Update the field shown in [slotId].
  void updateSlot(String slotId, DiveField field) {
    state = state.copyWith(
      slots: state.slots
          .map((s) => s.slotId == slotId ? s.copyWith(field: field) : s)
          .toList(),
    );
    _save();
  }

  /// Replace the extra fields list entirely.
  void setExtraFields(List<DiveField> fields) {
    state = state.copyWith(extraFields: List.unmodifiable(fields));
    _save();
  }

  /// Append [field] to extra fields if it is not already present.
  void addExtraField(DiveField field) {
    if (state.extraFields.contains(field)) return;
    state = state.copyWith(extraFields: [...state.extraFields, field]);
    _save();
  }

  /// Remove [field] from extra fields.
  void removeExtraField(DiveField field) {
    state = state.copyWith(
      extraFields: state.extraFields.where((f) => f != field).toList(),
    );
    _save();
  }

  /// Move extra field at [oldIndex] to [newIndex].
  void reorderExtraFields(int oldIndex, int newIndex) {
    final fields = List<DiveField>.from(state.extraFields);
    final item = fields.removeAt(oldIndex);
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    fields.insert(target.clamp(0, fields.length), item);
    state = state.copyWith(extraFields: fields);
    _save();
  }

  /// Toggle whether tag chips are shown on the card.
  void setShowTags(bool value) {
    if (state.showTags == value) return;
    state = state.copyWith(showTags: value);
    _save();
  }

  /// Reset to the default config for the current mode.
  void resetToDefault() {
    state = _defaultForMode(_mode ?? ListViewMode.compact);
    _save();
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  static domain.CardViewConfig _defaultForMode(ListViewMode mode) {
    switch (mode) {
      case ListViewMode.compact:
        return domain.CardViewConfig.defaultCompact();
      case ListViewMode.dense:
        return domain.CardViewConfig.defaultDense();
      case ListViewMode.detailed:
      case ListViewMode.table:
        return domain.CardViewConfig.defaultDetailed();
    }
  }

  void _save() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      final repo = _repository;
      final diverId = _diverId;
      if (repo != null && diverId != null) {
        repo.saveCardConfig(diverId, state);
      }
    });
  }
}

/// Provider for compact card view config.
final compactCardConfigProvider =
    StateNotifierProvider<CardViewConfigNotifier, domain.CardViewConfig>((ref) {
      final notifier = CardViewConfigNotifier.withMode(ListViewMode.compact);
      final diverId = ref.watch(currentDiverIdProvider);
      if (diverId != null) {
        final repo = ref.watch(viewConfigRepositoryProvider);
        notifier.init(repo, diverId, ListViewMode.compact);
      }
      return notifier;
    });

/// Provider for dense card view config.
final denseCardConfigProvider =
    StateNotifierProvider<CardViewConfigNotifier, domain.CardViewConfig>((ref) {
      final notifier = CardViewConfigNotifier.withMode(ListViewMode.dense);
      final diverId = ref.watch(currentDiverIdProvider);
      if (diverId != null) {
        final repo = ref.watch(viewConfigRepositoryProvider);
        notifier.init(repo, diverId, ListViewMode.dense);
      }
      return notifier;
    });

/// Provider for detailed card view config.
final detailedCardConfigProvider =
    StateNotifierProvider<CardViewConfigNotifier, domain.CardViewConfig>((ref) {
      final notifier = CardViewConfigNotifier.withMode(ListViewMode.detailed);
      final diverId = ref.watch(currentDiverIdProvider);
      if (diverId != null) {
        final repo = ref.watch(viewConfigRepositoryProvider);
        notifier.init(repo, diverId, ListViewMode.detailed);
      }
      return notifier;
    });

// ---------------------------------------------------------------------------
// Table presets provider
// ---------------------------------------------------------------------------

/// Loads all field presets for a diver (built-in + user-saved).
final tablePresetsProvider =
    FutureProvider.family<List<domain.FieldPreset>, String>((
      ref,
      diverId,
    ) async {
      final repo = ref.watch(viewConfigRepositoryProvider);
      await repo.ensureBuiltInPresets(diverId);
      return repo.getPresetsForMode(diverId, ListViewMode.table);
    });
