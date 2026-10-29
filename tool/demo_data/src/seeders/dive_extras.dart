import 'package:drift/drift.dart' show Value, Variable;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart'
    show DiveDataSourcesCompanion;
import 'package:submersion/core/tide/entities/tide_extremes.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/tides/data/repositories/tide_record_repository.dart';
import 'package:submersion/features/tides/domain/entities/tide_record.dart';

import '../shape/dive_shape.dart';
import '../story/destination_life.dart';
import '../story/story_plan.dart';
import 'dive_tank_plan.dart';
import 'seed_context.dart';

/// What a dive has besides its own row: buddies and roles, sightings,
/// profile events and gas switches, the computer reading it came from, and
/// the tide.
class DiveExtras {
  DiveExtras(this.ctx);

  final DemoSeedContext ctx;
  final _dives = DiveRepository();
  final _buddies = BuddyRepository();
  final _species = SpeciesRepository();
  final _tides = TideRecordRepository();

  Future<void> write(
    PlannedDive d,
    String id,
    DiveShape shape,
    List<PlannedTank> tanks,
    List<String> tankIds,
  ) async {
    final instructors = {
      for (final p in ctx.plan.people)
        if (p.role == PersonRole.instructor) p.id,
    };
    for (final person in d.buddyIds) {
      await _buddies.addBuddyToDiveWithRoles(id, ctx.buddyId(person), [
        if (instructors.contains(person) && d.courseId != null)
          'instructor'
        else
          'buddy',
      ]);
    }

    final life = destinationSpecies[d.destination.key]!;
    final seen = <String>{};
    for (var i = 0; i < ctx.random.nextInt(4); i++) {
      final name = ctx.pickOne(life);
      final speciesId = ctx.species[name];
      if (speciesId == null || !seen.add(name)) continue;
      await _species.addSighting(
        diveId: id,
        speciesId: speciesId,
        count: 1 + ctx.random.nextInt(4),
      );
    }

    final events = <ProfileEvent>[];
    final switches = <GasSwitch>[];
    final maxAt = shape.samples.indexWhere((s) => s.depth == shape.maxDepth);
    var e = 0;
    ProfileEvent event(
      int t,
      ProfileEventType type, {
      double? depth,
      String? tankId,
      String? description,
    }) => ProfileEvent(
      id: 'demo-event-$id-${e++}',
      diveId: id,
      timestamp: t,
      eventType: type,
      depth: depth,
      tankId: tankId,
      description: description,
      source: EventSource.imported,
      createdAt: d.start,
    );
    events.add(
      event(
        shape.samples[maxAt].t,
        ProfileEventType.maxDepth,
        depth: shape.maxDepth,
      ),
    );
    for (var i = 1; i < tanks.length; i++) {
      if (tanks[i].role == TankRole.bailout || d.diveMode == 'ccr') continue;
      final at = shape.samples
          .skip(maxAt)
          .where((s) => s.depth <= tanks[i].modMeters)
          .firstOrNull;
      if (at == null) continue;
      switches.add(
        GasSwitch(
          id: 'demo-switch-$id-$i',
          diveId: id,
          timestamp: at.t,
          tankId: tankIds[i],
          depth: at.depth,
          createdAt: d.start,
        ),
      );
      events.add(
        event(
          at.t,
          ProfileEventType.gasSwitch,
          depth: at.depth,
          tankId: tankIds[i],
        ),
      );
    }
    final stop = shape.samples
        .skip(maxAt)
        .where((s) => s.depth <= 6 && s.depth >= 3)
        .toList();
    if (stop.length > 6) {
      final deco = tanks.length > 1 || d.diveMode == 'ccr';
      events
        ..add(
          event(
            stop.first.t,
            deco
                ? ProfileEventType.decoStopStart
                : ProfileEventType.safetyStopStart,
            depth: stop.first.depth,
          ),
        )
        ..add(
          event(
            stop.last.t,
            deco
                ? ProfileEventType.decoStopEnd
                : ProfileEventType.safetyStopEnd,
            depth: stop.last.depth,
          ),
        );
    }
    if (d.number % 9 == 0) {
      events.add(
        event(
          shape.samples[maxAt ~/ 2].t,
          ProfileEventType.bookmark,
          description: 'Photo',
        ),
      );
    }
    if (d.diveMode == 'ccr' && maxAt > 4) {
      events.add(
        event(
          shape.samples[2].t,
          ProfileEventType.setpointChange,
          description: 'High setpoint 1.3',
        ),
      );
    }
    await _dives.insertProfileEvents(events);
    if (switches.isNotEmpty) await _dives.insertGasSwitches(switches);

    final computer =
        ctx.computers[d.diveMode == 'ccr' || d.tankCount > 1
            ? 'tech'
            : ctx.timeline.inUseOn('computer-ai', d.start)
            ? 'ai'
            : 'rec']!;
    await _dives.saveComputerReading(
      DiveDataSourcesCompanion.insert(
        id: 'demo-reading-$id',
        diveId: id,
        computerId: Value(computer),
        isPrimary: const Value(true),
        importedAt: d.start.add(const Duration(hours: 3)),
        createdAt: d.start.add(const Duration(hours: 3)),
      ),
    );
    await ctx.db.customUpdate(
      'UPDATE dives SET computer_id = ? WHERE id = ?',
      variables: [Variable.withString(computer), Variable.withString(id)],
    );

    if (!d.destination.freshwater && d.number % 3 == 0) {
      final rising = ctx.random.nextBool();
      await _tides.saveTideRecord(
        TideRecord(
          id: 'demo-tide-$id',
          diveId: id,
          heightMeters: ctx.between(0.2, 1.8),
          tideState: rising ? TideState.rising : TideState.falling,
          rateOfChange: ctx.between(0.05, 0.4) * (rising ? 1 : -1),
          highTideHeight: ctx.between(1.6, 2.2),
          highTideTime: d.start.add(
            Duration(minutes: 60 + ctx.random.nextInt(180)),
          ),
          lowTideHeight: ctx.between(0.1, 0.5),
          lowTideTime: d.start.subtract(
            Duration(minutes: 60 + ctx.random.nextInt(180)),
          ),
          createdAt: d.start,
        ),
      );
    }
  }

  /// Things that need every dive written first.
  Future<void> finish() async {
    final lastLake = ctx.plan.dives.lastWhere(
      (d) => d.destination.key == 'home',
    );
    await EquipmentObservationRepository().create(
      equipmentId: ctx.equipment['drysuit']!,
      diverId: DemoSeedContext.diverId,
      diveId: ctx.diveId(lastLake.number),
      observedAt: lastLake.start,
      status: ObservationStatus.issue,
      issueTags: const [ObservationTag.leak],
      note: 'Damp left wrist again; seal check booked.',
    );
  }
}

/// A short note in the diver's voice.
String diveNote(DemoSeedContext ctx, PlannedDive d) {
  final life = destinationSpecies[d.destination.key]!;
  final animal = ctx.pickOne(life);
  if (d.courseId != null) {
    final course = ctx.plan.courses.firstWhere((c) => c.id == d.courseId);
    return '${course.level.title} training dive. Skills went well; ${animal.toLowerCase()} on the way back.';
  }
  return switch (d.phase) {
    StoryPhase.recreational => ctx.pickOne([
      'Easy dive, good visibility. $animal near the end.',
      'Drifted along the reef with a mild current. Saw a $animal.',
      'Worked on trim and buoyancy. $animal under a ledge.',
      'Cold at depth, worth it for the $animal.',
    ]),
    StoryPhase.technicalOc => ctx.pickOne([
      'Run to plan; gas switch on time and a quiet deco.',
      'Deep on the wreck, short bottom time, long hang. $animal on the deco stop.',
      'Team dive; switches confirmed by both, clean ascent.',
    ]),
    StoryPhase.rebreather => ctx.pickOne([
      'Loop behaved, cells in agreement. Silent approach to a $animal.',
      'Practised bailout ascent drills, then a relaxed hang.',
      'Long run time on the loop; scrubber well within its time.',
    ]),
  };
}
