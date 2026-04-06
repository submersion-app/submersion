import 'dart:async';
import 'dart:convert';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/view_config_repository.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_table_config.dart';

/// Generic StateNotifier that manages in-memory [EntityTableViewConfig] state
/// and debounces persistence to the database.
///
/// Each entity type creates its own provider using this notifier, parameterized
/// with its field enum type.
class EntityTableConfigNotifier<F extends EntityField>
    extends StateNotifier<EntityTableViewConfig<F>> {
  ViewConfigRepository? _repository;
  String? _diverId;
  String? _storageKey;
  final F Function(String) _fieldFromName;
  Timer? _saveTimer;

  EntityTableConfigNotifier({
    required EntityTableViewConfig<F> defaultConfig,
    required F Function(String) fieldFromName,
  }) : _fieldFromName = fieldFromName,
       super(defaultConfig);

  /// Load the saved config from the database for [diverId].
  Future<void> init(
    ViewConfigRepository repository,
    String diverId,
    String storageKey,
  ) async {
    _repository = repository;
    _diverId = diverId;
    _storageKey = storageKey;
    final json = await repository.getRawConfig(diverId, storageKey);
    if (json != null) {
      state = EntityTableViewConfig.fromJson<F>(
        jsonDecode(json) as Map<String, dynamic>,
        _fieldFromName,
      );
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Mutations
  // -------------------------------------------------------------------------

  /// Add or remove [field] from the column list. Pinned columns cannot be
  /// removed.
  void toggleColumn(F field) {
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
          EntityTableColumnConfig<F>(field: field),
        ],
      );
    }
    _save();
  }

  /// Cycle sort for [field]: unsorted -> ascending -> descending -> unsorted.
  void setSortField(F field) {
    if (state.sortField != field) {
      state = state.copyWith(sortField: field, sortAscending: true);
    } else if (state.sortAscending) {
      state = state.copyWith(sortAscending: false);
    } else {
      state = state.copyWith(clearSortField: true, sortAscending: true);
    }
    _save();
  }

  /// Resize [field] column, clamping to [minWidth, 600].
  void resizeColumn(F field, double width) {
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
    final cols = List<EntityTableColumnConfig<F>>.from(state.columns);
    final item = cols.removeAt(oldIndex);
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    cols.insert(target.clamp(0, cols.length), item);
    state = state.copyWith(columns: cols);
    _save();
  }

  /// Toggle the pinned state for [field].
  void togglePin(F field) {
    state = state.copyWith(
      columns: state.columns
          .map((c) => c.field == field ? c.copyWith(isPinned: !c.isPinned) : c)
          .toList(),
    );
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
      final key = _storageKey;
      if (repo != null && diverId != null && key != null) {
        repo.saveRawConfig(diverId, key, jsonEncode(state.toJson()));
      }
    });
  }
}
