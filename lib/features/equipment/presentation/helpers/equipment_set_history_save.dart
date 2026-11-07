import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/set_history_rewrite.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_history_dialog.dart';

/// Saves an edited [set] and replays its member changes on the dives that
/// carry it (issue #4283): planned dives always, logged ones when the diver
/// asks for that. [loaded] is the set as the editor opened it.
///
/// Asks before anything is written, so a cancel saves nothing; returns false
/// then. Asks only when the members differ from [loaded] and a logged dive
/// carries the set.
Future<bool> saveSetWithHistory(
  BuildContext context,
  WidgetRef ref, {
  required EquipmentSet set,
  required EquipmentSet loaded,
}) async {
  var choice = AssemblyHistoryChoice.futureOnly;
  if (!setEquals(set.equipmentIds.toSet(), loaded.equipmentIds.toSet())) {
    final asked = await askSetHistory(context, ref, setId: set.id);
    if (asked == null) return false;
    choice = asked;
  }
  final diff = await ref
      .read(equipmentSetListNotifierProvider.notifier)
      .updateSet(set);
  // What the repository actually wrote, not the editor's own diff: it drops
  // members whose gear is gone (issue #819).
  final rewrites = <SetHistoryRewrite>[
    for (final id in diff.added) SetItemAdded(id),
    for (final id in diff.removed) SetItemRemoved(id),
  ];
  if (rewrites.isNotEmpty) {
    await ref
        .read(diveRepositoryProvider)
        .rewriteSetOnDives(
          set.id,
          rewrites,
          alsoLogged: choice == AssemblyHistoryChoice.alsoPast,
        );
  }
  return true;
}
