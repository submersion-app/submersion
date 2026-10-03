import 'dart:math' as math;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_cloud_event_map.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_tissue_parser.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';

/// A dive parsed from a Suunto export, plus the device identity fields
/// needed to resolve/create the owning [DiveComputer] record (kept separate
/// from [DownloadedDive], which has no computer-identity fields of its own).
class SuuntoParsedDive {
  const SuuntoParsedDive({
    required this.dive,
    this.deviceName,
    this.serialNumber,
    this.firmwareVersion,
    this.notes,
  });

  final DownloadedDive dive;

  /// Dive-level tissue state the computer reported in the SML header
  /// (`Header.Diving.StartTissue` / `EndTissue` / `Algorithm`), if any.
  /// Lives on [dive] so the shared import pipeline persists it.
  ComputerTissueSnapshot? get computerTissue => dive.computerTissue;

  /// Suunto's internal device codename (e.g. "Vaasa"), already mapped to a
  /// commercial product line name (e.g. "Suunto Nautic") for display.
  final String? deviceName;
  final String? serialNumber;
  final String? firmwareVersion;

  /// The notes the diver wrote in the Suunto app, from the workout listing
  /// rather than the dive export (issue #2410).
  final String? notes;

  SuuntoParsedDive copyWith({
    DownloadedDive? dive,
    String? deviceName,
    String? serialNumber,
    String? firmwareVersion,
    String? notes,
  }) => SuuntoParsedDive(
    dive: dive ?? this.dive,
    deviceName: deviceName ?? this.deviceName,
    serialNumber: serialNumber ?? this.serialNumber,
    firmwareVersion: firmwareVersion ?? this.firmwareVersion,
    notes: notes ?? this.notes,
  );
}

/// Converts a normalized Suunto dive export (see [SuuntoSmlNormalizer]) into
/// a [DownloadedDive], the same shape a BLE/USB dive computer download
/// produces -- so the rest of the import pipeline (tanks, gas switches,
/// duplicate detection, consolidation) is shared with [DiveComputerAdapter].
///
/// A Dart port of the header/sample parsing in Subsurface's
/// `core/import-suunto-json.cpp` (`parse_header`/`parse_samples`/
/// `parse_gases`), adapted to submersion's dive-computer-download model
/// instead of Subsurface's own `struct dive`.
class SuuntoDiveParser {
  const SuuntoDiveParser._();

  static SuuntoParsedDive parse({
    required Map<String, dynamic> header,
    required List<Map<String, dynamic>> samples,
  }) {
    final device = header['Device'] as Map<String, dynamic>?;
    final deviceInternalName = device?['Name'] as String?;
    final gasOffset = _gasOffsetFor(deviceInternalName, samples);

    final headerDateTime = header['DateTime'] as String?;
    final headerStart = _parseIso8601(headerDateTime);
    final headerOffset = headerDateTime == null
        ? null
        : _declaredOffset(headerDateTime);

    final firstPass = _FirstPass.scan(samples);
    final diveStartMs = firstPass.diveStartMs;
    final startTime = diveStartMs != null
        ? DateTime.fromMillisecondsSinceEpoch(diveStartMs, isUtc: true).add(
            _sampleClockCorrection(
              headerStart,
              headerOffset,
              firstPass.firstSampleMs,
            ),
          )
        : (headerStart ?? DateTime.now().toUtc());

    final diving = header['Diving'] as Map<String, dynamic>?;

    final profileResult = diveStartMs == null
        ? const _ProfileResult(
            samples: [],
            gasSwitchOrder: [],
            transmitters: _TransmitterLayout.none,
            lastDepth: 0,
          )
        : _buildProfile(
            samples,
            diveStartMs: diveStartMs,
            temperatureReadings: firstPass.temperatureReadings,
            gasOffset: gasOffset,
            gasCount: _gases(diving).length,
          );

    final depthObj = header['Depth'] as Map<String, dynamic>?;
    var maxDepth = _asDouble(depthObj?['Max']) ?? 0;
    if (maxDepth <= 0 && profileResult.samples.isNotEmpty) {
      maxDepth = profileResult.samples
          .map((s) => s.depth)
          .reduce((a, b) => a > b ? a : b);
    }
    final avgDepth =
        _asDouble(header['DepthAverage']) ?? _asDouble(depthObj?['Avg']);

    var durationSeconds =
        (_asDouble(header['DiveTime']) ?? _asDouble(header['Duration']) ?? 0)
            .round();
    if (durationSeconds <= 0 && profileResult.samples.isNotEmpty) {
      durationSeconds = profileResult.samples.last.timeSeconds;
    }

    final tempObj = header['Temperature'] as Map<String, dynamic>?;
    final tempMaxK = _asDouble(tempObj?['Max']);
    final tempMinK = _asDouble(tempObj?['Min']);
    double? minTemperature;
    double? maxTemperature;
    // Suunto stores max/min reversed: "Min" is the higher Kelvin value
    // (= warmer water), "Max" is the lower Kelvin value (= colder).
    if (tempMaxK != null && tempMinK != null && tempMaxK > 0 && tempMinK > 0) {
      minTemperature = _kelvinToCelsius(
        tempMaxK < tempMinK ? tempMaxK : tempMinK,
      );
      maxTemperature = _kelvinToCelsius(
        tempMaxK > tempMinK ? tempMaxK : tempMinK,
      );
    }

    final gfLow = (diving?['GfLow'] as num?)?.round();
    final gfHigh = (diving?['GfHigh'] as num?)?.round();
    final computerTissue = diving == null ? null : parseSuuntoTissue(diving);

    final tanks = _withSidemountPartners(
      _buildTanks(diving, {
        ...profileResult.gasSwitchOrder,
        ...profileResult.transmitters.gasesRead,
      }),
      profileResult.transmitters,
    );

    // Suunto takes a surface fix before the descent and another after the
    // ascent, and keeps the pair in the dive footer's DiveLocation block
    // (hoisted onto the header by [SuuntoSmlNormalizer]). A dive may hold
    // either fix alone. The samples' DiveRouteOrigin repeats the entry fix
    // and is the fallback for exports whose footer has no Start.
    final diveLocation = header['DiveLocation'] as Map<String, dynamic>?;
    final entryFix = _surfaceFix(diveLocation?['Start']);
    final exitFix = _surfaceFix(diveLocation?['Stop']);

    final dive = DownloadedDive(
      startTime: startTime,
      durationSeconds: durationSeconds,
      maxDepth: maxDepth,
      avgDepth: avgDepth,
      minTemperature: minTemperature,
      maxTemperature: maxTemperature,
      entryLatitude: entryFix?.latitude ?? firstPass.latitude,
      entryLongitude: entryFix?.longitude ?? firstPass.longitude,
      exitLatitude: exitFix?.latitude,
      exitLongitude: exitFix?.longitude,
      profile: profileResult.samples,
      tanks: tanks,
      gasSwitches: profileResult.gasSwitches,
      gfLow: gfLow,
      gfHigh: gfHigh,
      decoAlgorithm: _decoAlgorithm(
        diving?['Algorithm'],
        hasGradientFactors: gfLow != null && gfHigh != null,
      ),
      computerTissue: computerTissue,
      events: profileResult.events,
    );

    return SuuntoParsedDive(
      dive: dive,
      deviceName: _mapDeviceName(deviceInternalName),
      serialNumber: device?['SerialNumber'] as String?,
      firmwareVersion:
          (device?['Info'] as Map<String, dynamic>?)?['SW'] as String?,
    );
  }

  /// Suunto uses internal device codenames in the JSON; the commercial
  /// product names are shown in submersion.
  static String? _mapDeviceName(String? internalName) {
    if (internalName == null || internalName.isEmpty) return null;
    return _knownDeviceNames[internalName] ??
        // Falls back to "Suunto <codename>" for unknown devices. This covers
        // the EON Core and EON Steel automatically.
        'Suunto $internalName';
  }

  /// Suunto device codenames whose commercial name and gas numbering are
  /// known. Every entry here is a current-generation ("Seal") computer that
  /// numbers its gases from 0; the EON family numbers from 1, and so does
  /// anything else absent from this map unless its samples say otherwise
  /// (see [_gasOffsetFor]).
  static const Map<String, String> _knownDeviceNames = {
    'Vaasa': 'Suunto Nautic',
    'Ylivieska': 'Suunto Nautic S',
    'Porvoo': 'Suunto Ocean',
  };

  /// The value to subtract from a sample's `GasNumber` to get a zero-based
  /// cylinder index.
  ///
  /// Current-generation computers number gases from 0 and the EON family
  /// from 1, with nothing in the header stating which. A codename allowlist
  /// alone silently mis-assigns every gas on a device nobody has catalogued
  /// yet -- a Suunto Nautic S, for instance, reports `Ylivieska`, which no
  /// published list covers.
  ///
  /// So for an unrecognized codename the data gets a say, but only where it
  /// is conclusive: a sample reporting `GasNumber` 0 can only come from a
  /// zero-based device. A lowest observed number of 1 or more proves
  /// nothing (a one-based dive may simply never have touched its first
  /// cylinder), so those keep the EON default rather than guessing.
  static int _gasOffsetFor(
    String? internalName,
    List<Map<String, dynamic>> samples,
  ) {
    if (internalName != null && _knownDeviceNames.containsKey(internalName)) {
      return 0;
    }
    return _lowestGasNumber(samples) == 0 ? 0 : 1;
  }

  static int? _lowestGasNumber(List<Map<String, dynamic>> samples) {
    int? lowest;
    void consider(num? gasNumber) {
      if (gasNumber == null) return;
      final value = gasNumber.toInt();
      if (lowest == null || value < lowest!) lowest = value;
    }

    for (final sample in samples) {
      for (final entry in (sample['Cylinders'] as List<dynamic>? ?? const [])) {
        consider((entry as Map<String, dynamic>)['GasNumber'] as num?);
      }

      final diveEvents = sample['DiveEvents'] as Map<String, dynamic>?;
      final gasSwitch = diveEvents?['GasSwitch'] as Map<String, dynamic>?;
      consider(gasSwitch?['GasNumber'] as num?);

      for (final entry in (sample['Events'] as List<dynamic>? ?? const [])) {
        final gs =
            (entry as Map<String, dynamic>)['GasSwitch']
                as Map<String, dynamic>?;
        consider(gs?['GasNumber'] as num?);
      }
    }
    return lowest;
  }

  /// One cylinder per header gas the dive used, at the gas's own index.
  ///
  /// A sample's `GasNumber` names a header gas, so gas `g` is cylinder `g`
  /// whatever order the diver breathed them in. [usedGases] holds every gas
  /// the dive switched to or read a transmitter on; a configured gas the
  /// dive never touched gets no cylinder, and nor does a used gas the header
  /// does not list.
  static List<DownloadedTank> _buildTanks(
    Map<String, dynamic>? diving,
    Set<int> usedGases,
  ) {
    final gases = _gases(diving);
    if (gases.isEmpty) return const [];

    // A dive with only one recorded gas never emits a gas-switch event (there
    // is nothing to switch to/from), and a dive without air integration reads
    // no transmitter either. Assign a lone gas straight to cylinder 0 rather
    // than dropping the gas mix entirely.
    final used = gases.length == 1 ? const {0} : usedGases;

    final tanks = <DownloadedTank>[];
    for (final gasIndex in used.toList()..sort()) {
      if (gasIndex >= gases.length) continue;
      final gas = gases[gasIndex];
      tanks.add(
        DownloadedTank(
          index: gasIndex,
          // Suunto fractions (0.0-1.0), submersion percent (0-100).
          o2Percent: (_asDouble(gas['Oxygen']) ?? 0) * 100,
          hePercent: (_asDouble(gas['Helium']) ?? 0) * 100,
          // Suunto m3, submersion liters.
          volumeLiters: (_asDouble(gas['TankSize']) ?? 0) > 0
              ? _asDouble(gas['TankSize'])! * 1000
              : null,
          // Suunto Pa, submersion bar.
          startPressure: (_asDouble(gas['StartPressure']) ?? 0) > 0
              ? _asDouble(gas['StartPressure'])! / 100000
              : null,
          endPressure: (_asDouble(gas['EndPressure']) ?? 0) > 0
              ? _asDouble(gas['EndPressure'])! / 100000
              : null,
        ),
      );
    }
    return tanks;
  }

  /// The header's gas list, empty when it has none.
  static List<Map<String, dynamic>> _gases(Map<String, dynamic>? diving) =>
      (diving?['Gases'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();

  /// Adds a cylinder for every extra transmitter a gas carries.
  ///
  /// In sidemount mode a Nautic or Ocean logs both cylinders' transmitters
  /// under one gas, as `Pressure` and `Pressure2`. The header has one gas
  /// entry for the pair, so [_buildTanks] makes one cylinder, and without a
  /// second the other transmitter's readings have no tank to land on. The
  /// pair becomes Sidemount Left (`Pressure`) and Sidemount Right
  /// (`Pressure2`); nothing in the export says which side each is on, so
  /// this follows the transmitter slot and the diver can swap them.
  ///
  /// The added cylinder shares its gas's mix and size. The gas's start and
  /// end pressures were read by the first transmitter, so it gets neither;
  /// the importer derives them from its own pressure series. A gas with no
  /// cylinder of its own gains none here.
  ///
  /// The lowest extra slot a gas reports is its Sidemount Right, whichever
  /// slot that is, and marks the gas's own cylinder Sidemount Left. A
  /// sidemount pair is two cylinders, so any further transmitter on the
  /// same gas is a cylinder of that mix with no role.
  static List<DownloadedTank> _withSidemountPartners(
    List<DownloadedTank> tanks,
    _TransmitterLayout transmitters,
  ) {
    if (transmitters.extraSlots.isEmpty) return tanks;

    // extraSlots is ordered by gas, then slot, so a gas's first entry is
    // its lowest extra slot.
    final paired = <int>{};
    final partners = <DownloadedTank>[];
    for (final MapEntry(key: (gasIndex, _), value: index)
        in transmitters.extraSlots.entries) {
      final primary = tanks.where((t) => t.index == gasIndex).firstOrNull;
      if (primary == null) continue;
      final isRight = paired.add(gasIndex);
      partners.add(
        DownloadedTank(
          index: index,
          o2Percent: primary.o2Percent,
          hePercent: primary.hePercent,
          volumeLiters: primary.volumeLiters,
          role: isRight ? TankRole.sidemountRight.name : null,
        ),
      );
    }

    return [
      for (final tank in tanks)
        paired.contains(tank.index)
            ? tank.copyWith(role: TankRole.sidemountLeft.name)
            : tank,
      ...partners,
    ];
  }

  /// [readings] as a list indexed by tank index, null where a tank has none.
  static List<double?> _byTankIndex(List<_PressureReading> readings) {
    final highest = readings.map((r) => r.tankIndex).reduce(math.max);
    final byTank = List<double?>.filled(highest + 1, null);
    for (final reading in readings) {
      byTank[reading.tankIndex] = reading.pressureBar;
    }
    return List.unmodifiable(byTank);
  }

  static _ProfileResult _buildProfile(
    List<Map<String, dynamic>> samples, {
    required int diveStartMs,
    required List<_TempReading> temperatureReadings,
    required int gasOffset,
    required int gasCount,
  }) {
    // A row's transmitter readings can only be placed on tanks once the
    // whole dive is known (see [_TransmitterLayout]), so rows are held with
    // their raw readings and built after the loop. Only the rows kept here
    // feed the layout: a reading on a sample the profile skips creates no
    // tank.
    final rows = <_PendingRow>[];
    final gasSwitches = <GasSwitchEvent>[];
    final events = <DownloadedEvent>[];
    final gasSwitchOrder = <int>[];

    var lastElapsedSecs = -1;
    var lastDepth = 0.0;
    // Keys of dive-events currently in their active window, so a begin edge
    // that the watch holds across several samples is imported once.
    final activeEventKeys = <String>{};

    for (final sample in samples) {
      final sampleMs = _parseTimestampMs(sample);
      if (sampleMs == null) continue;

      // Truncates toward zero, matching the reference importer's int64
      // division for a (rare) sample that precedes the detected dive start.
      final elapsedSecs = (sampleMs - diveStartMs) ~/ 1000;

      final depthValue = _asDouble(sample['Depth']);
      if (depthValue != null &&
          elapsedSecs >= 0 &&
          elapsedSecs != lastElapsedSecs) {
        lastElapsedSecs = elapsedSecs;
        lastDepth = depthValue;

        final temperature = _findNearestTemperature(
          temperatureReadings,
          sampleMs,
        );
        final ceiling = _asDouble(sample['Ceiling']);
        final ndl = (sample['NoDecTime'] as num?)?.round();
        final tts = (sample['TimeToSurface'] as num?)?.round();

        rows.add(
          _PendingRow(
            timeSeconds: elapsedSecs,
            depth: depthValue,
            temperature: temperature,
            ndl: ndl,
            ceiling: (ceiling ?? 0) > 0 ? ceiling : null,
            tts: tts,
            readings: _transmitterReadings(sample, gasOffset).toList(),
          ),
        );
      }

      final clampedElapsed = elapsedSecs < 0 ? 0 : elapsedSecs;
      _collectGasSwitchOrder(sample, gasOffset, gasSwitchOrder);
      _collectEvents(
        sample,
        gasOffset,
        clampedElapsed,
        lastDepth,
        gasSwitches,
        events,
        activeEventKeys,
      );
    }

    final transmitters = _TransmitterLayout.of(
      [for (final row in rows) ...row.readings],
      gasCount: gasCount,
      gasSwitchOrder: gasSwitchOrder,
    );

    return _ProfileResult(
      samples: [
        for (final row in rows)
          row.toSample(_placeReadings(row.readings, transmitters)),
      ],
      gasSwitchOrder: gasSwitchOrder,
      transmitters: transmitters,
      gasSwitches: gasSwitches,
      events: events,
      lastDepth: lastDepth,
    );
  }

  static void _collectGasSwitchOrder(
    Map<String, dynamic> sample,
    int gasOffset,
    List<int> order,
  ) {
    void record(int? gasNumber) {
      if (gasNumber == null) return;
      final gasIndex = gasNumber - gasOffset;
      if (gasIndex < 0 || order.contains(gasIndex)) return;
      order.add(gasIndex);
    }

    final diveEvents = sample['DiveEvents'] as Map<String, dynamic>?;
    final gasSwitch = diveEvents?['GasSwitch'] as Map<String, dynamic>?;
    record((gasSwitch?['GasNumber'] as num?)?.toInt());

    final eventsArray = sample['Events'] as List<dynamic>?;
    if (eventsArray != null) {
      for (final entry in eventsArray) {
        final gs =
            (entry as Map<String, dynamic>)['GasSwitch']
                as Map<String, dynamic>?;
        record((gs?['GasNumber'] as num?)?.toInt());
      }
    }
  }

  /// The sub-group keys that carry a dive-event.
  static const List<String> _eventSubgroups = [
    'Alarm',
    'Warning',
    'Notify',
    'State',
    'Ooam',
  ];

  static void _collectEvents(
    Map<String, dynamic> sample,
    int gasOffset,
    int elapsedSecs,
    double currentDepth,
    List<GasSwitchEvent> gasSwitches,
    List<DownloadedEvent> events,
    Set<String> activeEventKeys,
  ) {
    // Two container shapes: older computers put one event under a `DiveEvents`
    // object, the "Seal" generation an `Events[]` array of them.
    final containers = <Map<String, dynamic>>[
      if (sample['DiveEvents'] is Map)
        sample['DiveEvents'] as Map<String, dynamic>,
      for (final e in (sample['Events'] as List<dynamic>? ?? const []))
        if (e is Map<String, dynamic>) e,
    ];

    // Which (subgroup, type) events are asserted on *this* sample.
    final nowActive = <String>{};

    for (final container in containers) {
      // Gas switch: also drives tank assignment, so it keeps its own path.
      // A switch is instantaneous -- emit it every time it appears.
      final gasSwitch = container['GasSwitch'] as Map<String, dynamic>?;
      final gasNumber = (gasSwitch?['GasNumber'] as num?)?.toInt();
      if (gasNumber != null) {
        gasSwitches.add(
          GasSwitchEvent(
            timeSeconds: elapsedSecs,
            depth: currentDepth,
            toTankIndex: gasNumber - gasOffset,
          ),
        );
        events.add(
          DownloadedEvent(
            timeSeconds: elapsedSecs,
            type: 'gaschange',
            value: (0x1A << 8) | 11,
          ),
        );
      }

      for (final subgroup in _eventSubgroups) {
        final block = container[subgroup] as Map<String, dynamic>?;
        if (block == null) continue;
        // Begin edge only. `Active` is present on the array shape (true on
        // begin, false on end); the object shape omits it (always a begin).
        if (block['Active'] == false) continue;
        nowActive.add('$subgroup/${block['Type']}');
      }
    }

    // Rising edge = active now, wasn't on the previous sample. A begin the
    // watch holds across several samples is imported once; a condition that
    // clears and re-triggers later is imported again.
    for (final key in nowActive.difference(activeEventKeys)) {
      final slash = key.indexOf('/');
      final mapped = suuntoCloudEvent(
        key.substring(0, slash),
        key.substring(slash + 1),
      );
      if (mapped == null) continue;
      events.add(
        DownloadedEvent(
          timeSeconds: elapsedSecs,
          type: mapped.downloadedType,
          value: mapped.nativeCode,
        ),
      );
    }

    activeEventKeys
      ..clear()
      ..addAll(nowActive);
  }

  /// One sample's [readings], in bar, placed on their tanks by
  /// [transmitters].
  ///
  /// A tank keeps the first reading it gets. Two `Cylinders` entries naming
  /// the same gas would otherwise both land on its index, and one would be
  /// lost silently further down, where [ProfileSample.tankPressures] holds
  /// one value per tank.
  static List<_PressureReading> _placeReadings(
    List<_TransmitterReading> readings,
    _TransmitterLayout transmitters,
  ) {
    final placed = <_PressureReading>[];
    final seen = <int>{};
    for (final (:gasIndex, :slot, :pressureBar) in readings) {
      final tankIndex = transmitters.tankIndexFor(gasIndex, slot);
      if (tankIndex == null || !seen.add(tankIndex)) continue;
      placed.add(_PressureReading(tankIndex, pressureBar));
    }
    return placed;
  }

  /// Reads every "Pressure"/"Pressure2"/"Pressure3"... transmitter reading
  /// off a sample's `Cylinders` entries, in submersion units (bar), with the
  /// zero-based gas it was logged under and its slot (0 for `Pressure`, 1
  /// for `Pressure2`, ...). A gas that maps below zero is skipped: no
  /// cylinder can hold it.
  static Iterable<_TransmitterReading> _transmitterReadings(
    Map<String, dynamic> sample,
    int gasOffset,
  ) sync* {
    final cylinders = sample['Cylinders'] as List<dynamic>?;
    if (cylinders == null) return;

    for (final entry in cylinders) {
      final cyl = entry as Map<String, dynamic>;
      final gasIndex = ((cyl['GasNumber'] as num?)?.toInt() ?? 0) - gasOffset;
      if (gasIndex < 0) continue;

      for (var slot = 0; ; slot++) {
        final key = slot == 0 ? 'Pressure' : 'Pressure${slot + 1}';
        if (!cyl.containsKey(key)) break;
        final pressurePa = _asDouble(cyl[key]);
        if (pressurePa != null && pressurePa > 0) {
          yield (
            gasIndex: gasIndex,
            slot: slot,
            pressureBar: pressurePa / 100000,
          );
        }
      }
    }
  }

  static double? _findNearestTemperature(
    List<_TempReading> readings,
    int sampleMs,
  ) {
    double? bestKelvin;
    var bestDiff = 1 << 62;
    for (final reading in readings) {
      final diff = (reading.timestampMs - sampleMs).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestKelvin = reading.kelvin;
      }
    }
    if (bestKelvin == null || bestDiff >= 15000) return null;
    return _kelvinToCelsius(bestKelvin);
  }

  /// The dive's deco model id from the header's `Algorithm` ("Suunto
  /// Fused2 RGBM", "Bühlmann 16 GF"), so the dive agrees with its tissue
  /// snapshot. RGBM and Bühlmann map to the app's ids; any other name is kept
  /// lowercased, as other importers do. Only a header without one falls back
  /// to the GF pair, which a Suunto writes whatever model it runs.
  static String? _decoAlgorithm(
    Object? algorithm, {
    required bool hasGradientFactors,
  }) {
    final name = algorithm is String ? algorithm.trim().toLowerCase() : '';
    if (name.isEmpty) return hasGradientFactors ? 'buhlmann' : null;
    if (name.contains('rgbm')) return 'rgbm';
    if (name.contains('buhlmann') || name.contains('bühlmann')) {
      return 'buhlmann';
    }
    return name;
  }

  static double _kelvinToCelsius(double kelvin) => kelvin - 273.15;

  /// Reads one `DiveLocation` fix (`Start` or `Stop`), whose coordinates are
  /// radians, into degrees.
  ///
  /// Returns null for a fix that is absent, incomplete, at null island, or
  /// whose converted coordinates fall off the globe -- the last of which
  /// catches a fix that was in degrees already, rather than importing it
  /// scaled by 180/pi as a plausible-looking position somewhere else.
  static _SurfaceFix? _surfaceFix(dynamic fix) {
    if (fix is! Map) return null;
    final latRadians = _asDouble(fix['Latitude']);
    final lonRadians = _asDouble(fix['Longitude']);
    if (latRadians == null || lonRadians == null) return null;
    if (latRadians == 0 && lonRadians == 0) return null;

    final latitude = _radiansToDegrees(latRadians);
    final longitude = _radiansToDegrees(lonRadians);
    if (latitude.abs() > 90 || longitude.abs() > 180) return null;

    return _SurfaceFix(latitude, longitude);
  }

  static double _radiansToDegrees(double radians) => radians * 180.0 / math.pi;

  static double? _asDouble(dynamic value) => (value as num?)?.toDouble();

  /// The smallest gap between the header and the first sample that can be a
  /// zone error rather than the header marking the log opening a little
  /// differently. No zone sits less than an hour from UTC.
  static const Duration _minZoneError = Duration(minutes: 45);

  /// The shift that puts the sample clock on the computer's own clock.
  ///
  /// The cloud's sml export stamps each sample envelope with a TimeISO8601
  /// of its own, and that clock can disagree with the computer's
  /// Header.DateTime by the dive's whole UTC offset: a Nautic dive logged at
  /// 13:44 CEST arrived with samples reading 15:44 (#2604). The header is the
  /// computer's clock, the one Suunto itself shows and the one Subsurface's
  /// `import-suunto-json.cpp` files the dive at, so it settles the zone; the
  /// samples still place the dive-active moment within the log.
  ///
  /// When the header declares its offset, the zone error can only be that
  /// offset in one direction or the other, so the correction is whichever
  /// of none, `+offset` and `-offset` leaves the smallest remainder. Any real
  /// gap between the header and the first sample survives as that remainder.
  /// A `Z` header declares a zero offset, so it never corrects. Only a header
  /// with no designator at all, and so no offset to go on, falls back to
  /// rounding the gap to whole quarter hours, the granularity of every real
  /// offset, once it reaches [_minZoneError].
  ///
  /// Zero when either clock is missing or they already agree, which leaves
  /// the app's JSON export, whose samples carry the header's clock, exactly
  /// as before.
  static Duration _sampleClockCorrection(
    DateTime? headerStart,
    Duration? headerOffset,
    int? firstSampleMs,
  ) {
    if (headerStart == null || firstSampleMs == null) return Duration.zero;
    final gap = Duration(
      milliseconds: headerStart.millisecondsSinceEpoch - firstSampleMs,
    );
    if (headerOffset != null) {
      var best = Duration.zero;
      for (final candidate in [headerOffset, -headerOffset]) {
        if ((gap - candidate).abs() < (gap - best).abs()) best = candidate;
      }
      return best;
    }
    if (gap.abs() < _minZoneError) return Duration.zero;
    const quarterHourMs = 15 * 60 * 1000;
    return Duration(
      milliseconds:
          (gap.inMilliseconds / quarterHourMs).round() * quarterHourMs,
    );
  }

  static int? _parseTimestampMs(Map<String, dynamic> sample) {
    final iso = sample['TimeISO8601'] as String?;
    final parsed = _parseIso8601(iso);
    return parsed?.millisecondsSinceEpoch;
  }

  /// Matches an ISO-8601 zone designator at the end of a timestamp: either a
  /// literal `Z` or a numeric `+HH:MM` / `-HHMM` offset. Applied only to the
  /// portion after the `T` so the date's own hyphens can never match.
  static final RegExp _zoneDesignator = RegExp(
    r'(?:(Z)|([+-])(\d{2}):?(\d{2}))$',
    caseSensitive: false,
  );

  /// The UTC offset [value] declares, or null when it declares none.
  static Duration? _declaredOffset(String value) {
    final timeStart = value.indexOf(RegExp('[Tt]'));
    if (timeStart < 0) return null;
    final match = _zoneDesignator.firstMatch(value.substring(timeStart));
    if (match == null) return null;
    if (match.group(1) != null) return Duration.zero;
    final sign = match.group(2) == '-' ? -1 : 1;
    return Duration(
      hours: sign * int.parse(match.group(3)!),
      minutes: sign * int.parse(match.group(4)!),
    );
  }

  /// Parses a Suunto timestamp into the diver's **local wall clock, flagged
  /// as UTC** -- submersion's storage convention for dive times (see
  /// `parsedDiveToDownloadedDive`, which stamps libdivecomputer's local
  /// date/time fields with `DateTime.utc`).
  ///
  /// Suunto writes the dive computer's local time together with its offset
  /// (`2026-08-20T15:27:23.140+02:00`), so the offset has to be re-applied
  /// rather than resolved away: resolving it to a true UTC instant files a
  /// diver in UTC+2 an hour-shifted dive (15:27 lands at 13:27), which is the
  /// long-standing "dives import hours off" complaint against Suunto JSON
  /// imports. Subsurface's `import-suunto-json.cpp`, which this parser is a
  /// port of, uses `parse_iso8601_local_ms()` for the same reason.
  ///
  /// A timestamp with no offset at all is taken at face value; without this
  /// its fields would be shifted by whatever zone the *importing machine*
  /// happens to sit in. A `Z` designator means Suunto recorded UTC and there
  /// is no local offset to recover, so the wall clock is the UTC time.
  ///
  /// Elapsed sample times are unaffected either way: they are differences
  /// between two timestamps that carry the same offset.
  static DateTime? _parseIso8601(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final parsed = DateTime.parse(value);
      final offset = _declaredOffset(value);
      if (offset == null) {
        return DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
          parsed.microsecond,
        );
      }
      return parsed.add(offset);
    } on FormatException {
      return null;
    }
  }
}

class _TempReading {
  const _TempReading(this.timestampMs, this.kelvin);
  final int timestampMs;
  final double kelvin;
}

/// Which tank index each transmitter reading belongs to.
///
/// A gas's first transmitter (`Pressure`) reads its own cylinder, whose
/// index is the gas's. Any further transmitter on the same gas (`Pressure2`,
/// a sidemount partner) is a cylinder no gas numbers, so it gets an index
/// above every gas the dive uses. Numbering straight on from the gas would
/// put gas 0's `Pressure2` on gas 1's cylinder, which collides the moment a
/// sidemount diver's stage bottle has a transmitter of its own.
///
/// Worked out from the whole dive's profile rows so a transmitter keeps one
/// index throughout, whatever order its readings first appear in.
class _TransmitterLayout {
  const _TransmitterLayout(this.extraSlots, this.gasesRead);

  /// A dive with no profile, and so no readings.
  static const none = _TransmitterLayout({}, {});

  /// Tank index of every extra transmitter, keyed by (gas index, slot), in
  /// gas then slot order.
  final Map<(int, int), int> extraSlots;

  /// Every gas some transmitter read, in any slot.
  final Set<int> gasesRead;

  /// The layout of [readings], the transmitter readings on the profile's
  /// rows. [gasCount] and [gasSwitchOrder] add the gases that hold no
  /// transmitter, which an extra index must also stay clear of.
  factory _TransmitterLayout.of(
    List<_TransmitterReading> readings, {
    required int gasCount,
    required List<int> gasSwitchOrder,
  }) {
    final gasesRead = {for (final r in readings) r.gasIndex};
    final highestGas = [
      gasCount - 1,
      ...gasesRead,
      ...gasSwitchOrder,
    ].reduce(math.max);

    final ordered =
        {
          for (final r in readings)
            if (r.slot > 0) (r.gasIndex, r.slot),
        }.toList()..sort((a, b) {
          final byGas = a.$1.compareTo(b.$1);
          return byGas != 0 ? byGas : a.$2.compareTo(b.$2);
        });
    return _TransmitterLayout({
      for (var i = 0; i < ordered.length; i++) ordered[i]: highestGas + 1 + i,
    }, gasesRead);
  }

  int? tankIndexFor(int gasIndex, int slot) =>
      slot == 0 ? gasIndex : extraSlots[(gasIndex, slot)];
}

/// One transmitter reading off a sample's `Cylinders` entry: the zero-based
/// gas it was logged under, its slot (0 for `Pressure`, 1 for `Pressure2`,
/// ...) and the pressure in bar.
typedef _TransmitterReading = ({int gasIndex, int slot, double pressureBar});

/// A profile row whose pressures wait on the dive's [_TransmitterLayout].
class _PendingRow {
  const _PendingRow({
    required this.timeSeconds,
    required this.depth,
    required this.temperature,
    required this.ndl,
    required this.ceiling,
    required this.tts,
    required this.readings,
  });

  final int timeSeconds;
  final double depth;
  final double? temperature;
  final int? ndl;
  final double? ceiling;
  final int? tts;
  final List<_TransmitterReading> readings;

  /// The row carrying [pressures]: every transmitter's reading at this
  /// instant on the one row (issue #1223), since a row per extra reading
  /// would repeat the sample's timestamp in the stored profile. The single
  /// pair holds the last reading, as [ProfileSample.tankPressures] documents.
  ProfileSample toSample(List<_PressureReading> pressures) => ProfileSample(
    timeSeconds: timeSeconds,
    depth: depth,
    temperature: temperature,
    pressure: pressures.isEmpty ? null : pressures.last.pressureBar,
    tankIndex: pressures.isEmpty ? null : pressures.last.tankIndex,
    tankPressures: pressures.length > 1
        ? SuuntoDiveParser._byTankIndex(pressures)
        : null,
    ndl: ndl,
    ceiling: ceiling,
    tts: tts,
  );
}

class _PressureReading {
  const _PressureReading(this.tankIndex, this.pressureBar);
  final int tankIndex;
  final double pressureBar;
}

/// One surface GPS fix, in degrees.
class _SurfaceFix {
  const _SurfaceFix(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

/// First pass over the raw samples: collects temperature readings (matched
/// to depth samples by nearest timestamp later), the dive-active start time,
/// the earliest sample time, and an entry GPS fix, without building any
/// profile rows yet.
class _FirstPass {
  const _FirstPass({
    required this.temperatureReadings,
    required this.diveStartMs,
    required this.firstSampleMs,
    this.latitude,
    this.longitude,
  });

  final List<_TempReading> temperatureReadings;
  final int? diveStartMs;

  /// The earliest sample timestamp: where the sample clock opens the log,
  /// compared against the header's own clock.
  final int? firstSampleMs;
  final double? latitude;
  final double? longitude;

  static _FirstPass scan(List<Map<String, dynamic>> samples) {
    final temperatureReadings = <_TempReading>[];
    int? diveStartMs;
    int? firstSampleMs;
    double? latitude;
    double? longitude;

    for (final sample in samples) {
      final sampleMs = SuuntoDiveParser._parseTimestampMs(sample);
      if (sampleMs != null &&
          (firstSampleMs == null || sampleMs < firstSampleMs)) {
        firstSampleMs = sampleMs;
      }

      final temp = SuuntoDiveParser._asDouble(sample['Temperature']);
      if (temp != null && temp > 0 && sampleMs != null) {
        temperatureReadings.add(_TempReading(sampleMs, temp));
      }

      if (diveStartMs == null) {
        // Nautic signals dive start via DiveEvents.DiveStatus.
        final diveEvents = sample['DiveEvents'] as Map<String, dynamic>?;
        if (diveEvents?['DiveStatus'] == true) {
          diveStartMs = SuuntoDiveParser._parseTimestampMs(sample);
        }

        // EON signals dive start via Events[].State "Dive Active".
        if (diveStartMs == null) {
          final eventsArray = sample['Events'] as List<dynamic>?;
          if (eventsArray != null) {
            for (final entry in eventsArray) {
              final state =
                  (entry as Map<String, dynamic>)['State']
                      as Map<String, dynamic>?;
              if (state?['Active'] == true && state?['Type'] == 'Dive Active') {
                diveStartMs = SuuntoDiveParser._parseTimestampMs(sample);
                break;
              }
            }
          }
        }
      }

      if (latitude == null) {
        final origin = sample['DiveRouteOrigin'] as Map<String, dynamic>?;
        final lat = SuuntoDiveParser._asDouble(origin?['Latitude']);
        final lon = SuuntoDiveParser._asDouble(origin?['Longitude']);
        if (lat != null && lon != null && (lat != 0 || lon != 0)) {
          latitude = lat;
          longitude = lon;
        }
      }
    }

    return _FirstPass(
      temperatureReadings: temperatureReadings,
      diveStartMs: diveStartMs,
      firstSampleMs: firstSampleMs,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

class _ProfileResult {
  const _ProfileResult({
    required this.samples,
    required this.gasSwitchOrder,
    required this.transmitters,
    this.gasSwitches = const [],
    this.events = const [],
    required this.lastDepth,
  });

  final List<ProfileSample> samples;
  final List<int> gasSwitchOrder;
  final _TransmitterLayout transmitters;
  final List<GasSwitchEvent> gasSwitches;
  final List<DownloadedEvent> events;
  final double lastDepth;
}
