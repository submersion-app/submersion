import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/models/equipment_fold_keys.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/list_arrangement_writes.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The outermost fold keys the Equipment list shows right now (issue #4184):
/// the places when it groups by location, the types otherwise. The list
/// publishes them after each build; Collapse all and the overflow menu read
/// them.
final equipmentOuterGroupKeysProvider = StateProvider<List<String>>(
  (ref) => const [],
);

/// The Equipment list's folded group keys (issue #4184), see
/// `equipment_fold_keys.dart`.
///
/// Normally the active diver's saved folds, and every change is saved. While
/// a filter is on, every group shows open: the state starts empty, changes
/// stay in memory ([EquipmentFoldsNotifier.isSessionOnly]), and they are
/// dropped when the filter clears, which brings the saved folds back
/// untouched.
final equipmentFoldsProvider =
    NotifierProvider<EquipmentFoldsNotifier, List<String>>(
      EquipmentFoldsNotifier.new,
    );

class EquipmentFoldsNotifier extends Notifier<List<String>> {
  bool _sessionOnly = false;

  /// Whether folds are memory-only because a filter is on.
  bool get isSessionOnly => _sessionOnly;

  @override
  List<String> build() {
    _sessionOnly = ref.watch(
      effectiveEquipmentFilterProvider.select((f) => f.hasActiveFilters),
    );
    if (_sessionOnly) return const [];
    return decodeFoldKeys(
      ref.watch(
        settingsProvider.select(
          (s) => s.listArrangements.equipmentCollapsedGroups,
        ),
      ),
    );
  }

  /// Folds [key] if it is open, opens it if it is folded.
  void toggle(String key) => _set(toggleFoldKey(state, key));

  /// Opens every group.
  void expandAll() => _set(const []);

  /// Folds every outermost group on screen, keeping the inner folds.
  void collapseAll() {
    var next = state;
    for (final key in ref.read(equipmentOuterGroupKeysProvider)) {
      if (!next.contains(key)) next = toggleFoldKey(next, key);
    }
    _set(next);
  }

  void _set(List<String> next) {
    state = next;
    if (_sessionOnly) return;
    unawaited(
      ref.read(settingsProvider.notifier).setEquipmentCollapsedGroups(next),
    );
  }
}
