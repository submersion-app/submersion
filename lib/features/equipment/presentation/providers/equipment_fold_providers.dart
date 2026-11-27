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
/// stay in memory, and they are dropped when the filter changes or clears.
/// Clearing brings the saved folds back untouched.
final equipmentFoldsProvider =
    NotifierProvider<EquipmentFoldsNotifier, List<String>>(
      EquipmentFoldsNotifier.new,
    );

class EquipmentFoldsNotifier extends Notifier<List<String>> {
  /// Whether folds are memory-only because a filter is on.
  bool _sessionOnly = false;

  @override
  List<String> build() {
    // The whole filter while one is on, so a change to a different filter
    // drops the folds made under the last one and every group shows open.
    _sessionOnly =
        ref.watch(
          effectiveEquipmentFilterProvider.select(
            (f) => f.hasActiveFilters ? f : null,
          ),
        ) !=
        null;
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

  /// Whether every assembly starts open (issue #5071): while a filter is
  /// on, so a matching part is never hidden inside a folded assembly. See
  /// `resolveCollapsedKeys` for what a stored assembly key means then.
  bool get assembliesStartOpen => _sessionOnly;

  /// Opens every group and every assembly in [assemblyIds].
  void expandAll({Iterable<String> assemblyIds = const []}) {
    final opened = assembliesStartOpen
        ? const <String>[]
        : [for (final id in assemblyIds) assemblyFoldKey(id)];
    _apply((_) => List.unmodifiable(opened));
  }

  /// Folds [outer], the outermost groups on screen (the places when the
  /// list groups by location, the types otherwise), keeping the inner folds,
  /// and folds every assembly in [assemblyIds].
  void collapseAll(
    List<String> outer, {
    Iterable<String> assemblyIds = const [],
  }) {
    final startOpen = assembliesStartOpen;
    _apply((keys) {
      var next = startOpen
          ? keys
          : List<String>.unmodifiable(keys.where((k) => !isAssemblyFoldKey(k)));
      for (final key in [
        ...outer,
        if (startOpen)
          for (final id in assemblyIds) assemblyFoldKey(id),
      ]) {
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
