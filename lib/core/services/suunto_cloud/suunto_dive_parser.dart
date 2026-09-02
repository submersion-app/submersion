import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';

/// A dive parsed from a Suunto export, plus the device identity fields
/// needed to resolve/create the owning [DiveComputer] record (kept separate
/// from [DownloadedDive], which has no computer-identity fields of its own).
class SuuntoParsedDive {
  const SuuntoParsedDive({
    required this.dive,
    this.deviceName,
    this.serialNumber,
    this.firmwareVersion,
  });

  final DownloadedDive dive;

  /// Suunto's internal device codename (e.g. "Vaasa"), already mapped to a
  /// commercial product line name (e.g. "Suunto Nautic") for display.
  final String? deviceName;
  final String? serialNumber;
  final String? firmwareVersion;
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

    final headerStart = _parseIso8601(header['DateTime'] as String?);

    final firstPass = _FirstPass.scan(samples);
    final diveStartMs = firstPass.diveStartMs;
    final startTime = diveStartMs != null
        ? DateTime.fromMillisecondsSinceEpoch(diveStartMs, isUtc: true)
        : (headerStart ?? DateTime.now().toUtc());

    final profileResult = diveStartMs == null
        ? const _ProfileResult(samples: [], gasSwitchOrder: [], lastDepth: 0)
        : _buildProfile(
            samples,
            diveStartMs: diveStartMs,
            temperatureReadings: firstPass.temperatureReadings,
            gasOffset: gasOffset,
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

    final diving = header['Diving'] as Map<String, dynamic>?;
    final gfLow = (diving?['GfLow'] as num?)?.round();
    final gfHigh = (diving?['GfHigh'] as num?)?.round();

    final tanks = _buildTanks(diving, profileResult.gasSwitchOrder);

    final dive = DownloadedDive(
      startTime: startTime,
      durationSeconds: durationSeconds,
      maxDepth: maxDepth,
      avgDepth: avgDepth,
      minTemperature: minTemperature,
      maxTemperature: maxTemperature,
      entryLatitude: firstPass.latitude,
      entryLongitude: firstPass.longitude,
      profile: profileResult.samples,
      tanks: tanks,
      gasSwitches: profileResult.gasSwitches,
      gfLow: gfLow,
      gfHigh: gfHigh,
      decoAlgorithm: (gfLow != null && gfHigh != null) ? 'buhlmann' : null,
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

  static List<DownloadedTank> _buildTanks(
    Map<String, dynamic>? diving,
    List<int> gasSwitchOrder,
  ) {
    final gases = (diving?['Gases'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    if (gases.isEmpty) return const [];

    // A dive with only one recorded gas never emits a gas-switch event (there
    // is nothing to switch to/from), so gasSwitchOrder is empty for the
    // overwhelmingly common single-gas case. Assign it straight to cylinder 0
    // rather than dropping the gas mix entirely.
    final order = gases.length == 1 ? const [0] : gasSwitchOrder;

    final tanks = <DownloadedTank>[];
    for (var i = 0; i < gases.length && i < order.length; i++) {
      final gas = gases[i];
      tanks.add(
        DownloadedTank(
          index: order[i],
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

  static _ProfileResult _buildProfile(
    List<Map<String, dynamic>> samples, {
    required int diveStartMs,
    required List<_TempReading> temperatureReadings,
    required int gasOffset,
  }) {
    final profile = <ProfileSample>[];
    final gasSwitches = <GasSwitchEvent>[];
    final events = <DownloadedEvent>[];
    final gasSwitchOrder = <int>[];

    var lastElapsedSecs = -1;
    var lastDepth = 0.0;

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

        final pressures = _readCylinderPressures(sample, gasOffset);

        profile.add(
          ProfileSample(
            timeSeconds: elapsedSecs,
            depth: depthValue,
            temperature: temperature,
            pressure: pressures.isEmpty ? null : pressures.first.pressureBar,
            tankIndex: pressures.isEmpty ? null : pressures.first.tankIndex,
            ndl: ndl,
            ceiling: (ceiling ?? 0) > 0 ? ceiling : null,
            tts: tts,
          ),
        );

        // A dive computer with more than one live pressure transmitter
        // reports every tank's pressure at the same instant; submersion's
        // profile-sample model (mirroring how multi-transmitter downloads
        // from real dive computers are represented) carries one
        // pressure/tankIndex pair per row, so extra simultaneous readings
        // ride along as additional minimal rows at the same timestamp.
        for (final extra in pressures.skip(1)) {
          profile.add(
            ProfileSample(
              timeSeconds: elapsedSecs,
              depth: depthValue,
              pressure: extra.pressureBar,
              tankIndex: extra.tankIndex,
            ),
          );
        }
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
      );
    }

    return _ProfileResult(
      samples: profile,
      gasSwitchOrder: gasSwitchOrder,
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

  static void _collectEvents(
    Map<String, dynamic> sample,
    int gasOffset,
    int elapsedSecs,
    double currentDepth,
    List<GasSwitchEvent> gasSwitches,
    List<DownloadedEvent> events,
  ) {
    final diveEvents = sample['DiveEvents'] as Map<String, dynamic>?;
    if (diveEvents != null) {
      final gasSwitch = diveEvents['GasSwitch'] as Map<String, dynamic>?;
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
          DownloadedEvent(timeSeconds: elapsedSecs, type: 'gaschange'),
        );
      }

      final state = diveEvents['State'] as Map<String, dynamic>?;
      if (state?['Type'] == 'At Safety Stop') {
        events.add(
          DownloadedEvent(timeSeconds: elapsedSecs, type: 'safetystop'),
        );
      }
    }

    final eventsArray = sample['Events'] as List<dynamic>?;
    if (eventsArray != null) {
      for (final entry in eventsArray) {
        final eo = entry as Map<String, dynamic>;

        final gasSwitch = eo['GasSwitch'] as Map<String, dynamic>?;
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
            DownloadedEvent(timeSeconds: elapsedSecs, type: 'gaschange'),
          );
        }

        final notify = eo['Notify'] as Map<String, dynamic>?;
        if (notify?['Active'] == true && notify?['Type'] == 'Safety Stop') {
          events.add(
            DownloadedEvent(timeSeconds: elapsedSecs, type: 'safetystop'),
          );
        }

        final alarm = eo['Alarm'] as Map<String, dynamic>?;
        if (alarm?['Active'] == true && alarm?['Type'] == 'Ascent Speed') {
          events.add(DownloadedEvent(timeSeconds: elapsedSecs, type: 'ascent'));
        }
      }
    }
  }

  /// Reads every "Pressure"/"Pressure2"/"Pressure3"... transmitter reading
  /// off a sample's `Cylinders` entries, in submersion units (bar).
  static List<_PressureReading> _readCylinderPressures(
    Map<String, dynamic> sample,
    int gasOffset,
  ) {
    final cylinders = sample['Cylinders'] as List<dynamic>?;
    if (cylinders == null) return const [];

    final readings = <_PressureReading>[];
    for (final entry in cylinders) {
      final cyl = entry as Map<String, dynamic>;
      final gasNumber = (cyl['GasNumber'] as num?)?.toInt() ?? 0;
      var sensor = gasNumber - gasOffset;

      for (var t = 0; ; t++) {
        final key = t == 0 ? 'Pressure' : 'Pressure${t + 1}';
        if (!cyl.containsKey(key)) break;
        final value = cyl[key];
        if (value == null) {
          sensor++;
          continue;
        }
        final pressurePa = (value as num).toDouble();
        if (pressurePa > 0) {
          readings.add(_PressureReading(sensor, pressurePa / 100000));
        }
        sensor++;
      }
    }
    return readings;
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

  static double _kelvinToCelsius(double kelvin) => kelvin - 273.15;

  static double? _asDouble(dynamic value) => (value as num?)?.toDouble();

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

class _PressureReading {
  const _PressureReading(this.tankIndex, this.pressureBar);
  final int tankIndex;
  final double pressureBar;
}

/// First pass over the raw samples: collects temperature readings (matched
/// to depth samples by nearest timestamp later), the dive-active start time,
/// and an entry GPS fix, without building any profile rows yet.
class _FirstPass {
  const _FirstPass({
    required this.temperatureReadings,
    required this.diveStartMs,
    this.latitude,
    this.longitude,
  });

  final List<_TempReading> temperatureReadings;
  final int? diveStartMs;
  final double? latitude;
  final double? longitude;

  static _FirstPass scan(List<Map<String, dynamic>> samples) {
    final temperatureReadings = <_TempReading>[];
    int? diveStartMs;
    double? latitude;
    double? longitude;

    for (final sample in samples) {
      final temp = SuuntoDiveParser._asDouble(sample['Temperature']);
      if (temp != null && temp > 0) {
        final ms = SuuntoDiveParser._parseTimestampMs(sample);
        if (ms != null) temperatureReadings.add(_TempReading(ms, temp));
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
      latitude: latitude,
      longitude: longitude,
    );
  }
}

class _ProfileResult {
  const _ProfileResult({
    required this.samples,
    required this.gasSwitchOrder,
    this.gasSwitches = const [],
    this.events = const [],
    required this.lastDepth,
  });

  final List<ProfileSample> samples;
  final List<int> gasSwitchOrder;
  final List<GasSwitchEvent> gasSwitches;
  final List<DownloadedEvent> events;
  final double lastDepth;
}
