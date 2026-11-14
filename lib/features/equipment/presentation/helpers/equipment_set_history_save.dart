import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/services/set_history_diff.dart';
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
  // The gear a set applies is its own plus that of the sets it includes,
  // and the dives of a set that includes this one carry its gear too
  // (issue #4525), so the question and the replay go by effective gear.
  List<EquipmentSet> allSets;
  try {
    allSets = await ref.read(equipmentSetsProvider.future);
  } catch (_) {
    allSets = [loaded];
  }
  if (!context.mounted) return null;
  var choice = AssemblyHistoryChoice.futureOnly;
  final planned = setHistoryRewrites(
    before: loaded,
    after: set,
    allSets: allSets,
  );
  if (planned.isNotEmpty) {
    final asked = await askSetHistory(
      context,
      ref,
      setId: set.id,
      alsoSetIds: [
        for (final change in planned)
          if (change.setId != set.id) change.setId,
      ],
    );
    if (asked == null || !context.mounted) return null;
    choice = asked;
  }
  final dives = ref.read(diveRepositoryProvider);
  final diff = await ref
      .read(equipmentSetListNotifierProvider.notifier)
      .updateSet(set);
  // The save drops ids whose gear has gone, so the replay goes by what it
  // actually wrote.
  final saved = set.copyWith(
    equipmentIds: [
      ...loaded.equipmentIds.where((id) => !diff.removed.contains(id)),
      ...diff.added,
    ],
  );
  final changes = setHistoryRewrites(
    before: loaded,
    after: saved,
    allSets: allSets,
  );
  final alsoLogged = choice == AssemblyHistoryChoice.alsoPast;
  return () async {
    for (final change in changes) {
      await dives.rewriteSetOnDives(
        change.setId,
        change.rewrites,
        alsoLogged: alsoLogged,
      );
      if (!alsoLogged) await dives.unlinkSetFromLoggedDives(change.setId);
    }
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
