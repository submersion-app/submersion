import 'dart:math';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../shape/dive_shape.dart';
import '../story/destination_life.dart';
import '../story/story_plan.dart';
import 'dive_extras.dart';
import 'dive_tank_plan.dart';
import 'seed_context.dart';

/// Every planned dive, written through the app's own repository: a real
/// dive's shape, reshaped onto this dive's tanks and place.
class DiveSeeder implements DemoSeeder {
  @override
  String get name => 'dives';

  @override
  Future<void> seed(DemoSeedContext ctx) async {
    final dives = DiveRepository();
    final pressures = TankPressureRepository();
    final extras = DiveExtras(ctx);
    final sites = {for (final s in ctx.plan.sites) s.id: s};
    final trips = {for (final t in ctx.plan.trips) t.id: t};

    for (final d in ctx.plan.dives) {
      final source = ctx.library.pick(
        kinds: d.wantedKinds,
        diveMode: d.diveMode,
        targetMaxDepth: d.targetMaxDepth,
        tripId: d.tripId,
      );
      final tanks = planTanks(d, source, ctx.random);
      final trimmed = DiveShape(
        id: source.id,
        kinds: source.kinds,
        diveMode: source.diveMode,
        sampleIntervalSec: source.sampleIntervalSec,
        samples: source.samples,
        tanks: _matchTanks(source.tanks, tanks),
        computerCount: source.computerCount,
      );
      final shape = ctx.reshaper.reshape(
        trimmed,
        targetMaxDepth: d.targetMaxDepth,
        startBar: [for (final t in tanks) t.startBar],
        volumesL: [for (final t in tanks) t.volumeL],
      );
      final shift = _temperatureShift(shape, d, ctx.random);
      final id = ctx.diveId(d.number);
      final tankIds = [
        for (var i = 0; i < tanks.length; i++) 'demo-tank-${d.number}-$i',
      ];
      ctx.diveTankIds[d.number] = tankIds;
      final site = sites[d.siteId]!;
      final trip = d.tripId == null ? null : trips[d.tripId];
      final runtime = Duration(seconds: shape.durationSec);
      final salt = !d.destination.freshwater;
      // Dive times are kept as the wall clock the dive computer showed,
      // stored as UTC; the plan's times are those wall-clock digits.
      final start = asWallClockUtc(d.start);

      final dive = Dive(
        id: id,
        diverId: DemoSeedContext.diverId,
        diveNumber: d.number,
        dateTime: start,
        entryTime: start,
        exitTime: start.add(runtime),
        runtime: runtime,
        maxDepth: shape.maxDepth,
        avgDepth: _avg(shape),
        site: DiveSite(id: ctx.siteId(site.id), name: site.name),
        tripId: d.tripId,
        tanks: [
          for (var i = 0; i < tanks.length; i++)
            DiveTank(
              id: tankIds[i],
              name: tanks[i].role == TankRole.backGas
                  ? 'Back gas'
                  : tanks[i].role.displayName,
              volume: tanks[i].volumeL,
              workingPressure: tanks[i].workingBar,
              startPressure: shape.tanks[i].startBar,
              endPressure: shape.tanks[i].endBar,
              gasMix: GasMix(o2: tanks[i].o2, he: tanks[i].he),
              role: tanks[i].role,
              material: tanks[i].material,
              presetName: tanks[i].presetName,
              order: i,
            ),
        ],
        profile: [
          for (final s in shape.samples)
            DiveProfilePoint(
              timestamp: s.t,
              depth: s.depth,
              temperature: s.temp == null ? null : s.temp! + shift,
              heartRate: s.heartRate,
              ppO2: s.ppO2,
              setpoint: s.setpoint,
              o2Sensor1: s.cells != null && s.cells!.isNotEmpty
                  ? s.cells![0]
                  : null,
              o2Sensor2: s.cells != null && s.cells!.length > 1
                  ? s.cells![1]
                  : null,
              o2Sensor3: s.cells != null && s.cells!.length > 2
                  ? s.cells![2]
                  : null,
            ),
        ],
        weights: _weights(d, id),
        tags: _tags(ctx, d),
        diveTypeIds: _types(d, trip),
        diverRoleIds: [d.courseId != null ? 'student' : 'buddy'],
        courseIds: [if (d.courseId != null) d.courseId!],
        customFields: [
          if (trip != null && trip.destination.liveaboard)
            DiveCustomField(
              id: 'demo-field-$id',
              key: 'Boat',
              value: 'MV Coral Spirit',
              sortOrder: 0,
            ),
        ],
        waterTemp: _minTemp(shape) == null ? null : _minTemp(shape)! + shift,
        airTemp: (d.destination.waterTempC.$2 + ctx.between(0, 6))
            .roundToDouble(),
        visibilityMeters:
            (d.destination.freshwater
                    ? ctx.between(3, 12)
                    : ctx.between(12, 35))
                .roundToDouble(),
        rating: 2 + ctx.random.nextInt(4),
        notes: diveNote(ctx, d),
        currentStrength: salt
            ? CurrentStrength.values[ctx.random.nextInt(3)]
            : CurrentStrength.none,
        currentDirection: salt
            ? CurrentDirection.values[ctx.random.nextInt(8)]
            : null,
        waterType: salt ? WaterType.salt : WaterType.fresh,
        entryMethod: d.destination.key == 'home'
            ? EntryMethod.shore
            : EntryMethod.backRoll,
        diveMode: d.diveMode == 'ccr' ? DiveMode.ccr : DiveMode.oc,
        setpointLow: d.diveMode == 'ccr' ? 0.7 : null,
        setpointHigh: d.diveMode == 'ccr' ? 1.3 : null,
        setpointDeco: d.diveMode == 'ccr' ? 1.4 : null,
        diluentGas: d.diveMode == 'ccr' ? const GasMix(o2: 21, he: 35) : null,
        scrubber: d.diveMode == 'ccr'
            ? const ScrubberInfo(type: 'Sofnolime 797', ratedMinutes: 180)
            : null,
        gradientFactorLow: 30 + (d.phase == StoryPhase.recreational ? 10 : 0),
        gradientFactorHigh: d.phase == StoryPhase.recreational ? 85 : 75,
        decoAlgorithm: 'buhlmann',
        isFavorite: d.number % 37 == 0,
        windSpeed: ctx.between(1, 9).roundToDouble(),
        cloudCover: CloudCover.values[ctx.random.nextInt(4)],
        precipitation: Precipitation.none,
        humidity: ctx.between(50, 85).roundToDouble(),
        weatherDescription: d.night ? 'Clear night' : 'Fair',
        weatherSource: WeatherSource.manual,
      );
      // Bottom time is derived from the profile, as the import pipeline does,
      // falling back to the runtime.
      await dives.createDive(
        dive.copyWith(
          bottomTime: dive.calculateBottomTimeFromProfile() ?? runtime,
        ),
      );
      await dives.replaceGearRows(id, [
        for (final e in await _gear(ctx, d))
          GearProvenance(
            equipmentId: e,
            viaSetId: ctx.equipmentSets[_setFor(d)],
          ),
      ]);
      await pressures.insertTankPressures(id, {
        for (var i = 0; i < tanks.length; i++)
          if (shape.tanks[i].pressures.isNotEmpty)
            tankIds[i]: [
              for (final (t, bar) in shape.tanks[i].pressures)
                (timestamp: t, pressure: bar),
            ],
      });
      await extras.write(d, id, shape, tanks, tankIds);
    }
    await extras.finish();
  }

  /// The source's tanks lined up with the planned ones: one per planned tank,
  /// reusing the source's trace for the matching index.
  static List<ShapeTank> _matchTanks(
    List<ShapeTank> source,
    List<PlannedTank> planned,
  ) => [
    for (var i = 0; i < planned.length; i++)
      i < source.length
          ? source[i]
          : ShapeTank(
              o2: planned[i].o2,
              he: planned[i].he,
              role: planned[i].role.name,
            ),
  ];

  static double? _minTemp(DiveShape s) {
    final temps = [
      for (final x in s.samples)
        if (x.temp != null) x.temp!,
    ];
    return temps.isEmpty ? null : temps.reduce(min);
  }

  /// Moves the shape's temperatures to the destination's water.
  static double _temperatureShift(DiveShape s, PlannedDive d, Random random) {
    final coldest = _minTemp(s);
    if (coldest == null) return 0;
    final (lo, hi) = d.destination.waterTempC;
    final target = lo + random.nextDouble() * (hi - lo);
    return ((target - coldest) * 10).roundToDouble() / 10;
  }

  static double _avg(DiveShape s) {
    final under = [
      for (final x in s.samples)
        if (x.depth > 0.5) x.depth,
    ];
    if (under.isEmpty) return 0;
    return (under.reduce((a, b) => a + b) / under.length * 10).roundToDouble() /
        10;
  }

  static List<DiveWeight> _weights(PlannedDive d, String id) {
    if (d.phase != StoryPhase.recreational) return const [];
    final home = d.destination.key == 'home';
    return [
      DiveWeight(
        id: 'demo-weight-$id',
        diveId: id,
        weightType: WeightType.belt,
        amountKg: home ? 6 : 4,
        label: 'Belt',
      ),
      if (home)
        DiveWeight(
          id: 'demo-weight-$id-trim',
          diveId: id,
          weightType: WeightType.trimWeights,
          amountKg: 2,
          label: 'Trim',
        ),
    ];
  }

  static List<Tag> _tags(DemoSeedContext ctx, PlannedDive d) {
    Tag tag(String name) => Tag(
      id: ctx.tags[name]!,
      name: name,
      createdAt: d.start,
      updatedAt: d.start,
    );
    return [
      if (d.courseId != null) tag('Training'),
      if (d.number % 11 == 0) tag('Photo'),
      if (d.number % 37 == 0) tag('Favourite'),
      if (destinationSiteTypes[d.destination.key]!.contains('wreck') &&
          d.number % 3 == 0)
        tag('Wreck'),
    ];
  }

  static List<String> _types(PlannedDive d, PlannedTrip? trip) => [
    if (d.phase == StoryPhase.recreational) 'recreational' else 'technical',
    if (d.targetMaxDepth >= 30) 'deep',
    if (d.courseId != null) 'training',
    if (d.night) 'night',
    if (d.destination.key == 'home') 'shore' else 'boat',
    if (trip != null && trip.destination.liveaboard) 'liveaboard',
  ];

  static String _setFor(PlannedDive d) => switch (d.phase) {
    StoryPhase.rebreather => 'ccr',
    StoryPhase.technicalOc when d.tankCount > 1 => 'tech',
    _ => d.destination.key == 'home' ? 'lake' : 'warm',
  };

  static Future<List<String>> _gear(DemoSeedContext ctx, PlannedDive d) async {
    final rows = await ctx.db
        .customSelect(
          "SELECT equipment_id FROM equipment_set_items WHERE set_id = '${ctx.equipmentSets[_setFor(d)]}'",
        )
        .get();
    return [for (final r in rows) r.read<String>('equipment_id')];
  }
}
