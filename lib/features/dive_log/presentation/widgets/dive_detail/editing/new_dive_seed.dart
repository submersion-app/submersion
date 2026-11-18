import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/cylinder_configs/domain/services/main_supply.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/new_dive_request.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_log/presentation/helpers/seeded_dive_times.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_set_use.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_rules.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/services/equipment_set_selector.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/domain/services/default_tank_preset_resolver.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _log = LoggerService('NewDiveSeed');
const _uuid = Uuid();

/// The dive a new dive's sitting starts from (issue #4527, plan 8): a
/// record that exists only in memory, under an id of its own, holding the
/// defaults today's new-dive form starts with. It is the sitting's stored
/// record, so none of these is a change: an untouched new dive has nothing
/// to save, and leaving it asks nothing.
///
/// The entry is [now] to the minute, the way the header's time row stores a
/// time it picks; the number is the diver's next one, none for a planned
/// dive; the first cylinder is the default preset's; the default equipment
/// set (no location yet, so no geofenced one) is used as it is when nobody
/// asked, and a set that brings the main cylinder takes the starter's
/// place, as on the form. A default that cannot be read is left out, as
/// the form leaves it.
Future<Dive> newDiveSeed(
  ProviderRead read,
  NewDiveRequest request, {
  DateTime Function() now = DateTime.now,
  String Function()? newId,
}) async {
  final settings = read(settingsProvider);
  String? diverId;
  // Whether the diver is known: none at all is a diver too (a log with no
  // profiles), but a lookup that failed is not.
  var diverKnown = false;
  try {
    diverId = await read(validatedCurrentDiverIdProvider.future);
    diverKnown = true;
  } catch (error, stackTrace) {
    _log.warning(
      'Reading the diver failed',
      error: error,
      stackTrace: stackTrace,
    );
  }
  final entry = wholeMinute(now());
  final planned = request.isPlanned;
  final bare = Dive(
    id: newId?.call() ?? _uuid.v4(),
    diverId: diverId,
    dateTime: entry,
    entryTime: entry,
    isPlanned: planned,
    // Where the dive came from (a scan), as the new-dive form stores it.
    importSource: request.prefill?.importSource,
  );
  // None of these needs another's answer: they are read side by side.
  final numberRead = !planned && diverKnown
      ? _nextNumber(read, diverId)
      : Future<int?>.value();
  final presetRead = _defaultPreset(read, settings.defaultTankPreset, diverId);
  final setRead = _withDefaultSet(read, bare);
  final number = await numberRead;
  final starter = newSittingTank(
    tanks: const [],
    preset: await presetRead,
    defaultVolume: settings.defaultTankVolume,
    defaultStartPressure: settings.defaultStartPressure,
  );
  final withSet = await setRead;
  return withSet.copyWith(
    diveNumber: number,
    tanks: _withStarter(withSet.tanks, starter),
  );
}

/// The diver's next number. With the diver unknown none is guessed from
/// every diver's log: Save numbers the dive in its own diver's. Null when
/// it cannot be read: the diver can type it.
Future<int?> _nextNumber(ProviderRead read, String? diverId) async {
  try {
    return await read(
      diveRepositoryProvider,
    ).getNextDiveNumber(diverId: diverId);
  } catch (error, stackTrace) {
    _log.warning(
      'Suggesting a dive number failed',
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
}

/// The diver's default cylinder: one of their own of that name, else the
/// built-in, else none.
Future<TankPresetEntity?> _defaultPreset(
  ProviderRead read,
  String? name,
  String? diverId,
) async {
  if (name == null) return null;
  final builtIn = TankPresets.byName(name);
  final fallback = builtIn == null
      ? null
      : TankPresetEntity.fromBuiltIn(builtIn);
  try {
    final resolver = DefaultTankPresetResolver(
      repository: read(tankPresetRepositoryProvider),
    );
    return await resolver.resolve(name, diverId: diverId) ?? fallback;
  } catch (error, stackTrace) {
    _log.warning(
      'Reading the default cylinder failed',
      error: error,
      stackTrace: stackTrace,
    );
    return fallback;
  }
}

/// [dive] with the default equipment set used on it, as nobody asked.
Future<Dive> _withDefaultSet(ProviderRead read, Dive dive) async {
  final session = EditSession<Dive>(dive, isNew: true);
  try {
    final inputs = await read(equipmentSetSelectionInputsProvider.future);
    final best = EquipmentSetSelector.bestSetFor(
      divePoints: const [],
      sets: inputs.sets,
      geofences: inputs.geofences,
    );
    if (best == null) return dive;
    await useSetInSitting(
      session,
      best,
      best.items ?? const [],
      read: read,
      auto: true,
    );
    await session.settled();
    return session.working;
  } catch (error, stackTrace) {
    _log.warning(
      'Using the default equipment set failed',
      error: error,
      stackTrace: stackTrace,
    );
    return dive;
  } finally {
    session.dispose();
  }
}

/// The set's cylinders with [starter] first, unless the set brings the
/// main cylinder itself: the starter stands in for the diver's main gas.
List<DiveTank> _withStarter(List<DiveTank> fromSet, DiveTank starter) {
  if (fromSet.any((t) => mainSupplyRoles.contains(t.role))) return fromSet;
  final all = [starter, ...fromSet];
  return [
    for (var i = 0; i < all.length; i++)
      all[i].order == i ? all[i] : all[i].copyWith(order: i),
  ];
}
