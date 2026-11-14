import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/set_history_rewrite.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_history_dialog.dart';

/// Saves an edited [set] and returns the step that replays its member
/// changes on the dives that carry it (issue #4283): planned dives always,
/// logged ones when the diver asks for that. Logged dives the diver keeps
/// as they were stop naming the set instead (issue #4500). [loaded] is the
/// set as the editor opened it.
///
/// Asks before anything is written, so a cancel saves nothing; returns null
/// then. Asks only when the members differ from [loaded] and a logged dive
/// carries the set. The caller hands the returned step to [saveThenReplay]
/// with the rest of its save.
Future<Future<void> Function()?> saveSetWithHistory(
  BuildContext context,
  WidgetRef ref,
  EquipmentSet set,
  EquipmentSet loaded,
) async {
  var choice = AssemblyHistoryChoice.futureOnly;
  if (!setEquals(set.equipmentIds.toSet(), loaded.equipmentIds.toSet())) {
    final asked = await askSetHistory(context, ref, setId: set.id);
    // The page may have gone while the question was open; nothing is
    // written yet, so stopping here leaves everything as it was.
    if (asked == null || !context.mounted) return null;
    choice = asked;
  }
  final dives = ref.read(diveRepositoryProvider);
  final diff = await ref
      .read(equipmentSetListNotifierProvider.notifier)
      .updateSet(set);
  // What the repository actually wrote, not the editor's own diff: it drops
  // members whose gear is gone (issue #819).
  final rewrites = <SetHistoryRewrite>[
    for (final id in diff.added) SetItemAdded(id),
    for (final id in diff.removed) SetItemRemoved(id),
  ];
  final alsoLogged = choice == AssemblyHistoryChoice.alsoPast;
  return () async {
    if (rewrites.isEmpty) return;
    await dives.rewriteSetOnDives(set.id, rewrites, alsoLogged: alsoLogged);
    // A logged dive kept as it was no longer matches the set, so it stops
    // naming it and keeps the gear as its own (issue #4500).
    if (!alsoLogged) await dives.unlinkSetFromLoggedDives(set.id);
  };
}

/// Runs [save], the writes that follow the set's own (its default flag and
/// geofences), then [replay] whatever [save] did: the members are already
/// written, so the planned dives must follow them. [save] goes first so a
/// replay that fails cannot cost the diver those edits.
///
/// [save]'s error is the one thrown, as it came first; a replay that fails
/// too is logged rather than hiding it.
Future<void> saveThenReplay(
  Future<void> Function() save,
  Future<void> Function()? replay,
) async {
  try {
    await save();
  } catch (_) {
    try {
      await replay?.call();
    } catch (e, st) {
      LoggerService.forClass(
        EquipmentSet,
      ).error('Set replay on its dives failed', error: e, stackTrace: st);
    }
    rethrow;
  }
  await replay?.call();
}
