import 'dart:math';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';
import 'package:submersion/features/equipment/domain/services/gear_expander.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';

import '../shape/dive_shape.dart';
import '../story/destination_life.dart';
import '../story/story_plan.dart';
import 'dive_extras.dart';
import 'dive_kit.dart';
import 'dive_tank_plan.dart';
import 'fault_signals.dart';
import 'gear_cylinder_seeder.dart';
import 'gear_seeder.dart';
import 'seed_context.dart';
import 'water_column.dart';

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
    final centers = {for (final c in ctx.plan.centers) c.id: c};
    final index = ComponentsIndex.fromRows(
      await EquipmentComponentRepository().getAllComponents(),
    );
    final keyOf = {for (final e in ctx.equipment.entries) e.value: e.key};
    final faults = ctx.faults;

    for (final d in ctx.plan.dives) {
      final source = ctx.library.pick(
        kinds: d.wantedKinds,
        diveMode: d.diveMode,
        targetMaxDepth: d.targetMaxDepth,
        tripId: d.tripId,
      );
      ctx.pickedKinds[d.number] = source.kinds;
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
      final water = WaterColumn.forDive(
        d.destination,
        d.waterTempC,
        ctx.random,
      );
      final temps = water.trace(shape.samples, ctx.random);
      if (d.scooter) ctx.scooterProfiles[d.number] = shape.samples;
      final id = ctx.diveId(d.number);
      final kit = kitFor(d, ctx.timeline, photo: isPhotoDive(d, ctx.timeline));
      // Each cell's output per bar; the swapped-in cell 2 is new and strong.
      final gains = [
        50.0,
        ctx.timeline.inUseOn('o2-cell-2b', d.start) ? 53.0 : 47.0,
        49.0,
      ];
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
              regulatorEquipmentId: _regulatorFor(ctx, kit.gearKeys, tanks, i),
              extraRegulatorIds: [
                if (i == 0 && kit.gearKeys.contains('reg-left'))
                  ctx.equipment['reg-left']!,
              ],
              transmitterSerial: _transmitterFor(ctx, kit.gearKeys, d, i),
            ),
        ],
        profile: [
          for (final (i, s) in shape.samples.indexed)
            _point(
              s,
              temps[i],
              cellReadings(
                s.cells,
                s.t / max(1, shape.durationSec),
                drifting2: faults.cellDriftDives.contains(d.number),
                divergent3: faults.divergentCellDives.contains(d.number),
              ),
              gains,
            ),
        ],
        weights: [
          for (var i = 0; i < kit.weights.length; i++)
            DiveWeight(
              id: 'demo-weight-$id-$i',
              diveId: id,
              weightType: kit.weights[i].weightType,
              amountKg: kit.weights[i].amountKg,
              label: kit.weights[i].label,
            ),
        ],
        diveCenter: d.centerId == null
            ? null
            : DiveCenter(
                id: ctx.centerId(d.centerId!),
                name: centers[d.centerId]!.name,
                createdAt: d.start,
                updatedAt: d.start,
              ),
        tags: _tags(ctx, d, photo: isPhotoDive(d, ctx.timeline)),
        diveTypeIds: _types(d, trip),
        diverRoleIds: [d.courseId != null ? 'student' : 'buddy'],
        courseIds: [if (d.courseId != null) d.courseId!],
        customFields: [
          if (trip != null && trip.destination.liveaboard)
            DiveCustomField(
              id: 'demo-field-$id',
              key: 'Boat',
              value: trip.boatName ?? '',
              sortOrder: 0,
            ),
        ],
        waterTemp: temps.reduce(min),
        // Air follows the surface water through the seasons, not the cold
        // bottom water a stratified sea is quoted for; in the tropics it is
        // a little warmer than the sea.
        airTemp: (water.surfaceC + ctx.between(_seasonal(d) ? -3 : 0, 5))
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
        entryMethod: d.boat ? EntryMethod.backRoll : EntryMethod.shore,
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
      final setItems = demoSets[kit.setKey]?.$2 ?? const <String>[];
      await dives.replaceGearRows(
        id,
        GearExpander.expand(
          additions: [
            for (final k in kit.gearKeys)
              (
                equipmentId: ctx.equipment[k]!,
                viaSetId: setItems.contains(k)
                    ? ctx.equipmentSets[kit.setKey]
                    : null,
              ),
          ],
          index: index,
          existing: const [],
          isActive: (e) => ctx.timeline.inUseOn(keyOf[e]!, d.start),
        ),
      );
      await pressures.insertTankPressures(id, {
        for (var i = 0; i < tanks.length; i++)
          if (shape.tanks[i].pressures.isNotEmpty)
            tankIds[i]: [
              for (final (t, bar)
                  in i == 0 && faults.dropoutDives.contains(d.number)
                      ? withDropouts(
                          shape.tanks[i].pressures,
                          gapFraction: 0.15,
                          random: ctx.random,
                        )
                      : shape.tanks[i].pressures)
                (timestamp: t, pressure: bar),
            ],
      });
      await _fills(ctx, d, kit.gearKeys, tanks);
      await extras.write(d, id, shape, tanks, tankIds);
    }
    await extras.finish();
    // The registry links every tank a configured transmitter read to that
    // transmitter's cylinder, as it does after an import.
    final transmitters = TransmitterRepository();
    for (final t in await transmitters.getForDiver(DemoSeedContext.diverId)) {
      await transmitters.applyToExistingDives(t);
    }
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

  static double _avg(DiveShape s) {
    final under = [
      for (final x in s.samples)
        if (x.depth > 0.5) x.depth,
    ];
    if (under.isEmpty) return 0;
    return (under.reduce((a, b) => a + b) / under.length * 10).roundToDouble() /
        10;
  }

  static List<Tag> _tags(
    DemoSeedContext ctx,
    PlannedDive d, {
    required bool photo,
  }) {
    Tag tag(String name) => Tag(
      id: ctx.tags[name]!,
      name: name,
      createdAt: d.start,
      updatedAt: d.start,
    );
    return [
      if (d.courseId != null) tag('Training'),
      if (photo) tag('Photo'),
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
    if (d.boat) 'boat' else 'shore',
    if (trip != null && trip.destination.liveaboard) 'liveaboard',
  ];

  /// The regulator on tank [i]: the single's own, the doubles' right post on
  /// the back gas, a stage regulator on each stage, the bailout regulator.
  static String? _regulatorFor(
    DemoSeedContext ctx,
    List<String> kit,
    List<PlannedTank> tanks,
    int i,
  ) {
    final role = tanks[i].role;
    if (role == TankRole.diluent || role == TankRole.oxygenSupply) return null;
    final String? key;
    if (role == TankRole.bailout) {
      key = 'reg-stage-bailout';
    } else if (kit.contains('reg-right')) {
      key = i == 0 ? 'reg-right' : (i == 1 ? 'reg-stage-1' : 'reg-stage-2');
    } else {
      key = ['reg-cold', 'reg-warm'].where(kit.contains).firstOrNull;
    }
    return key != null && kit.contains(key) ? ctx.equipment[key] : null;
  }

  /// The serial of the transmitter on the back gas regulator, when it has
  /// one in use that day.
  static String? _transmitterFor(
    DemoSeedContext ctx,
    List<String> kit,
    PlannedDive d,
    int i,
  ) {
    if (i != 0) return null;
    for (final (reg, transmitter) in [
      ('reg-right', 'transmitter-right'),
      ('reg-cold', 'transmitter-cold'),
    ]) {
      if (kit.contains(reg) && ctx.timeline.inUseOn(transmitter, d.start)) {
        return transmitterSerials[transmitter];
      }
    }
    return null;
  }

  /// One profile sample, with the water's [temperature] as the computer read
  /// it, the cells as the loop read them and each cell's millivolts.
  static DiveProfilePoint _point(
    ShapeSample s,
    double temperature,
    List<double>? cells,
    List<double> gains,
  ) {
    double? cell(int i) => cells != null && cells.length > i ? cells[i] : null;
    int? mv(int i) => cell(i) == null ? null : cellMv(cell(i)!, gains[i]);
    return DiveProfilePoint(
      timestamp: s.t,
      depth: s.depth,
      temperature: temperature,
      heartRate: s.heartRate,
      ppO2: s.ppO2,
      setpoint: s.setpoint,
      o2Sensor1: cell(0),
      o2Sensor2: cell(1),
      o2Sensor3: cell(2),
      o2SensorMv1: mv(0),
      o2SensorMv2: mv(1),
      o2SensorMv3: mv(2),
    );
  }

  /// Whether [d]'s destination has seasons (a wide temperature range).
  static bool _seasonal(PlannedDive d) =>
      d.destination.waterTempC.$2 - d.destination.waterTempC.$1 >= 6;

  final _passports = <String, String>{};
  final _fillCount = <String, int>{};

  /// A fill on the day before every fourth home dive an owned cylinder was
  /// taken on, of the gas that dive breathed from it.
  Future<void> _fills(
    DemoSeedContext ctx,
    PlannedDive d,
    List<String> kit,
    List<PlannedTank> tanks,
  ) async {
    for (var i = 0; i < tanks.length; i++) {
      final key = _cylinderKey(kit, tanks[i].role, i);
      if (key == null) continue;
      final n = _fillCount[key] = (_fillCount[key] ?? 0) + 1;
      if (n % 4 != 1) continue;
      final passport = _passports[key] ??= await CylinderPassportRepository()
          .ensurePassportId(
            ctx.equipment[key]!,
            diverId: DemoSeedContext.diverId,
          );
      final at = ctx.timeline.homeDayOnOrBefore(
        d.start.subtract(const Duration(days: 1)),
      );
      await CylinderFillRepository().create(
        CylinderFill(
          id: 'demo-fill-$key-$n',
          passportId: passport,
          equipmentId: ctx.equipment[key],
          filledAt: at,
          o2Percent: tanks[i].o2,
          hePercent: tanks[i].he,
          pressureBar: tanks[i].startBar,
          stationName: 'Club fill station',
          source: FillSource.manual,
          createdAt: at,
          updatedAt: at,
        ),
      );
    }
  }

  /// The diver's own cylinder for tank [i], when the kit took one.
  static String? _cylinderKey(List<String> kit, TankRole role, int i) {
    final key = switch (role) {
      TankRole.diluent => 'ccr-dil',
      TankRole.oxygenSupply => 'ccr-o2',
      TankRole.bailout => 'stage-1',
      _ when kit.contains('twin') => ['twin', 'stage-1', 'stage-2'][min(i, 2)],
      _ => 'tank-12',
    };
    return kit.contains(key) ? key : null;
  }
}
