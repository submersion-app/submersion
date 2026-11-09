import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/models/equipment_fold_keys.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/list_arrangement_writes.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The Equipment list's folded group keys (issue #4184), see
/// `equipment_fold_keys.dart`.
///
/// Normally the active diver's saved folds, and every change is saved. While
/// a filter is on, every group shows open: the state starts empty, changes
/// stay in memory, and they are dropped when the filter clears, which brings
/// the saved folds back untouched.
final equipmentFoldsProvider =
    NotifierProvider<EquipmentFoldsNotifier, List<String>>(
      EquipmentFoldsNotifier.new,
    );

class EquipmentFoldsNotifier extends Notifier<List<String>> {
  /// Whether folds are memory-only because a filter is on.
  bool _sessionOnly = false;

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
  void toggle(String key) {
    final fold = !state.contains(key);
    // Against the saved keys, so a key already as wanted is left alone.
    _apply(
      (keys) => fold != keys.contains(key) ? toggleFoldKey(keys, key) : keys,
    );
  }

  /// Opens every group.
  void expandAll() => _apply((_) => const []);

  /// Folds [outer], the outermost groups on screen (the places when the
  /// list groups by location, the types otherwise), keeping the inner folds.
  void collapseAll(List<String> outer) {
    _apply((keys) {
      var next = keys;
      for (final key in outer) {
        if (!next.contains(key)) next = toggleFoldKey(next, key);
      }
      return next;
    });
  }

  /// Applies [change] to the folds on screen now, and, unless a filter is
  /// on, to the saved folds once they have loaded: a change, not a result,
  /// so a tap during the load never replaces what loads.
  void _apply(List<String> Function(List<String> keys) change) {
    state = change(state);
    if (_sessionOnly) return;
    unawaited(
      ref
          .read(settingsProvider.notifier)
          .updateEquipmentCollapsedGroups(change),
    );
  }
}
