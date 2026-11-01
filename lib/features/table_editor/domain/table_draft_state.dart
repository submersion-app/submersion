import 'package:flutter/foundation.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/table_editor/domain/table_draft.dart';

/// Every draft on one tab of the table editor, plus which cell is open and
/// which is selected (#3422). Immutable: the notifier copies the maps.
@immutable
class TableDraftState {
  /// entityId -> fieldName -> draft.
  final Map<String, Map<String, TableDraft>> byEntity;
  final CellPosition? editing;
  final CellPosition? selected;

  const TableDraftState({
    this.byEntity = const {},
    this.editing,
    this.selected,
  });

  int get count => byEntity.values.fold(0, (n, m) => n + m.length);
  int get flaggedCount => all.where((d) => !d.isSaveable).length;
  bool get isEmpty => count == 0;
  List<TableDraft> get all => [for (final m in byEntity.values) ...m.values];
  List<TableDraft> get saveable => all.where((d) => d.isSaveable).toList();

  TableDraft? at(String entityId, String fieldName) =>
      byEntity[entityId]?[fieldName];

  List<TableDraft> forEntity(String entityId) =>
      byEntity[entityId]?.values.toList() ?? const [];

  TableDraftState copyWith({
    Map<String, Map<String, TableDraft>>? byEntity,
    CellPosition? editing,
    bool clearEditing = false,
    CellPosition? selected,
    bool clearSelected = false,
  }) => TableDraftState(
    byEntity: byEntity ?? this.byEntity,
    editing: clearEditing ? null : (editing ?? this.editing),
    selected: clearSelected ? null : (selected ?? this.selected),
  );
}

class TableDraftsNotifier extends StateNotifier<TableDraftState> {
  TableDraftsNotifier() : super(const TableDraftState());

  /// Stores [draft], or drops the cell's draft when the value is what is
  /// stored already and nothing is flagged.
  void put(TableDraft draft) {
    if (draft.isSaveable && draft.isUnchanged) {
      remove(draft.entityId, draft.fieldName);
      return;
    }
    _update(draft.entityId, (fields) => {...fields, draft.fieldName: draft});
  }

  void putAll(Iterable<TableDraft> drafts) {
    for (final d in drafts) {
      put(d);
    }
  }

  void remove(String entityId, String fieldName) {
    final fields = state.byEntity[entityId];
    if (fields == null || !fields.containsKey(fieldName)) return;
    final rest = {...fields}..remove(fieldName);
    final byEntity = {...state.byEntity};
    if (rest.isEmpty) {
      byEntity.remove(entityId);
    } else {
      byEntity[entityId] = rest;
    }
    state = state.copyWith(byEntity: byEntity);
  }

  void clear() => state = const TableDraftState();

  void flag(String entityId, String fieldName, TableDraftFlag flag) {
    final d = state.at(entityId, fieldName);
    if (d == null) return;
    _update(
      entityId,
      (fields) => {...fields, fieldName: d.copyWith(flag: flag)},
    );
  }

  /// After a stale skip: keeps the value, takes [newOriginal] as what is now
  /// stored and clears the flag, so the draft can be saved against it.
  void rebase(String entityId, String fieldName, Object? newOriginal) {
    final d = state.at(entityId, fieldName);
    if (d == null) return;
    _update(
      entityId,
      (fields) => {
        ...fields,
        fieldName: d.copyWith(
          original: newOriginal,
          clearOriginal: newOriginal == null,
          clearFlag: true,
        ),
      },
    );
  }

  void setEditing(CellPosition? cell) =>
      state = state.copyWith(editing: cell, clearEditing: cell == null);

  /// Whether [cell] is the open cell right now, for a commit that must not
  /// close an editor the sheet has already moved elsewhere.
  bool editingIs(CellPosition cell) => state.editing == cell;

  /// The draft now at [cell], for a deferred commit to compare with what it
  /// was built from.
  TableDraft? draftAt(CellPosition cell) =>
      state.at(cell.entityId, cell.fieldName);

  void setSelected(CellPosition? cell) =>
      state = state.copyWith(selected: cell, clearSelected: cell == null);

  void _update(
    String entityId,
    Map<String, TableDraft> Function(Map<String, TableDraft> fields) change,
  ) {
    final fields = change(state.byEntity[entityId] ?? const {});
    state = state.copyWith(byEntity: {...state.byEntity, entityId: fields});
  }
}
