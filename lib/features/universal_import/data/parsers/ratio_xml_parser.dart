import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';

/// Parser for Ratio Computers dive computer XML files (iX3M, iDive, etc.).
///
/// The XML format uses `<diveSegment>` as the root element with:
/// - `<segmentHeader>` containing dive metadata (depths in centimeters,
///   temperatures in deci-Celsius, times in seconds)
/// - `<samples>` containing per-sample profile data (depths in decimeters,
///   temperatures in deci-Celsius, runtime in seconds)
///
/// Filename convention: `{model}_{serial}-dive_{number}-{date}_{time}.xml`
/// Example: `IX3M_2_PRO_012345-dive_16-19880819_165840.xml`
class RatioXmlParser implements ImportParser {
  const RatioXmlParser();

  /// Sentinel value for unlimited NDL in Ratio XML.
  static const _unlimitedNdl = 32767;

  /// Ratio epoch: 2008-01-01 00:00:00 UTC, expressed as Unix seconds.
  /// Ratio timestamps are seconds since this epoch, not since 1970.
  static const _ratioEpochUnixS = 1199145600;

  @override
  List<ImportFormat> get supportedFormats => [ImportFormat.ratioXml];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    final content = utf8.decode(fileBytes, allowMalformed: true);

    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(content);
    } on XmlException catch (e) {
      return ImportPayload(
        entities: const {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Invalid XML file: ${e.message}',
          ),
        ],
        metadata: const {'source': 'ratio_xml'},
      );
    }

    final root = doc.rootElement;
    if (root.name.local != 'diveSegment') {
      return const ImportPayload(
        entities: {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message:
                'Not a Ratio Computers XML file: '
                'expected <diveSegment> root element.',
          ),
        ],
        metadata: {'source': 'ratio_xml'},
      );
    }

    final header = root.getElement('segmentHeader');
    if (header == null) {
      return const ImportPayload(
        entities: {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Ratio XML file is missing <segmentHeader>.',
          ),
        ],
        metadata: {'source': 'ratio_xml'},
      );
    }

    final warnings = <ImportWarning>[];
    final diveData = <String, dynamic>{};

    // -- Header metadata --
    _parseHeader(header, diveData, warnings);

    // -- Filename metadata (model, serial, dive number) --
    _parseFilename(options?.fileName, diveData);

    // -- Sample profile data --
    final samplesElement = root.getElement('samples');
    if (samplesElement != null) {
      _parseSamples(samplesElement, diveData, warnings);
    } else {
      warnings.add(
        const ImportWarning(
          severity: ImportWarningSeverity.warning,
          message:
              'Ratio XML file has no <samples> section; '
              'dive profile will be empty.',
        ),
      );
    }

    if (diveData.isEmpty) {
      return ImportPayload(
        entities: const {},
        warnings: [
          const ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Could not extract any dive data from Ratio XML file.',
          ),
          ...warnings,
        ],
        metadata: const {'source': 'ratio_xml'},
      );
    }

    return ImportPayload(
      entities: {
        ImportEntityType.dives: [diveData],
      },
      warnings: warnings,
      metadata: {
        'source': 'ratio_xml',
        if (diveData['diveComputerModel'] != null)
          'computerModel': diveData['diveComputerModel'],
        if (diveData['diveComputerSerial'] != null)
          'computerSerial': diveData['diveComputerSerial'],
      },
    );
  }

  // ======================== Header Parsing ========================

  void _parseHeader(
    XmlElement header,
    Map<String, dynamic> diveData,
    List<ImportWarning> warnings,
  ) {
    // UTC start time (seconds since Ratio epoch 2008-01-01 00:00:00 UTC)
    final utcStartS = _intElement(header, 'UTCStartingTimeS');
    if (utcStartS != null) {
      diveData['dateTime'] = DateTime.fromMillisecondsSinceEpoch(
        (utcStartS + _ratioEpochUnixS) * 1000,
        isUtc: true,
      );
    }

    // Max depth: stored in centimeters -> convert to meters
    final depthMaxCm = _intElement(header, 'depthMax');
    if (depthMaxCm != null) {
      diveData['maxDepth'] = depthMaxCm / 100.0;
    }

    // Average depth: stored in centimeters -> convert to meters
    final avgDepthCm = _intElement(header, 'avgDepth');
    if (avgDepthCm != null) {
      diveData['avgDepth'] = avgDepthCm / 100.0;
    }

    // Dive mode: 0=OC, 1=SCR, 2=CCR, 3=Gauge
    final diveMode = _intElement(header, 'diveMode');
    if (diveMode != null) {
      diveData['diveMode'] = _diveModeString(diveMode);
    }

    // Water type: 1=fresh, 0=salt
    final water = _intElement(header, 'water');
    if (water != null) {
      diveData['waterType'] = water == 1 ? 'fresh' : 'salt';
    }

    // Surface interval (seconds before this dive)
    final surfaceTimeS = _intElement(header, 'lastSurfaceTimeS');
    if (surfaceTimeS != null && surfaceTimeS > 0) {
      diveData['surfaceInterval'] = Duration(seconds: surfaceTimeS);
    }

    // Surface pressure (stored as mbar * 10, e.g. 9971 = 997.1 mbar)
    // Converted to bar: 9971 / 10000.0 = 0.9971 bar
    final surfacePressure = _intElement(header, 'surfacePressureMbar');
    if (surfacePressure != null) {
      diveData['surfacePressure'] = surfacePressure / 10000.0;
    }
  }

  // ======================== Sample Parsing ========================

  void _parseSamples(
    XmlElement samplesElement,
    Map<String, dynamic> diveData,
    List<ImportWarning> warnings,
  ) {
    final sampleElements = samplesElement.findElements('sample').toList();
    if (sampleElements.isEmpty) return;

    final profile = <Map<String, dynamic>>[];
    final tankPressures = <int, List<_TankReading>>{};
    final tankMixes = <int, GasMix>{};
    final tankIdToIndex = <int, int>{};
    final gasSwitches = <Map<String, dynamic>>[];

    int? prevO2;
    int? prevHe;
    double? minTemp;
    int? lastRuntimeS;
    int? lastCns;
    int? lastOtu;
    int? firstGfLow;
    int? firstGfHigh;

    for (final sample in sampleElements) {
      final runtimeS = _intElement(sample, 'runtimeS');
      if (runtimeS == null) continue;

      lastRuntimeS = runtimeS;

      // Depth: decimeters -> meters
      final depthDm = _intElement(sample, 'depthDm');
      final depthM = depthDm != null ? depthDm / 10.0 : 0.0;

      // Temperature: deci-Celsius -> Celsius
      final tempDc = _intElement(sample, 'temperatureDc');
      final tempC = tempDc != null ? tempDc / 10.0 : null;
      if (tempC != null && (minTemp == null || tempC < minTemp)) {
        minTemp = tempC;
      }

      final point = <String, dynamic>{'timestamp': runtimeS, 'depth': depthM};

      if (tempC != null) point['temperature'] = tempC;

      // NDL/TTS
      final ndlOrTts = _intElement(sample, 'NDLOrTTS');
      if (ndlOrTts != null && ndlOrTts != _unlimitedNdl && ndlOrTts >= 0) {
        // When firstStopDepth > 0, the diver is in deco and this is TTS
        final firstStop = _intElement(sample, 'firstStopDepth') ?? 0;
        if (firstStop > 0) {
          point['tts'] = ndlOrTts;
        } else {
          point['ndl'] = ndlOrTts;
        }
      }

      // Deco ceiling: firstStopDepth in decimeters -> meters
      final ceilingDm = _intElement(sample, 'firstStopDepth');
      if (ceilingDm != null && ceilingDm > 0) {
        point['ceiling'] = ceilingDm / 10.0;
      }

      // CNS
      final cns = _intElement(sample, 'CNS');
      if (cns != null && cns > 0) {
        point['cns'] = cns.toDouble();
        lastCns = cns;
      }

      // OTU
      final otu = _intElement(sample, 'OTU');
      if (otu != null) lastOtu = otu;

      // Map tankId to a sequential 0-based tankIndex
      final tankId = _intElement(sample, 'tankId');
      int? currentTankIndex;
      if (tankId != null) {
        currentTankIndex = tankIdToIndex.putIfAbsent(
          tankId,
          () => tankIdToIndex.length,
        );
      }

      // Gas mix tracking
      final o2 = _intElement(sample, 'activeMixO2Percent');
      final he = _intElement(sample, 'activeMixHePercent');
      if (o2 != null) {
        // Track the gas mix for this tank
        if (tankId != null && !tankMixes.containsKey(tankId)) {
          tankMixes[tankId] = GasMix(
            o2: o2.toDouble(),
            he: (he ?? 0).toDouble(),
          );
        }

        if (o2 != prevO2 || he != prevHe) {
          if (prevO2 != null) {
            // Gas switch occurred
            final switchEvent = <String, dynamic>{
              'timestamp': runtimeS,
              'depth': depthM,
              'o2': o2, // kept for debugging/reference
              'he': he ?? 0,
            };
            if (currentTankIndex != null) {
              switchEvent['tankIndex'] = currentTankIndex;
            }
            gasSwitches.add(switchEvent);
          }
          prevO2 = o2;
          prevHe = he;
        }
      }

      // GF values (capture from first sample)
      if (firstGfLow == null) {
        firstGfLow = _intElement(sample, 'buhlGfLow');
        firstGfHigh = _intElement(sample, 'buhlGfHigh');
      }

      // Tank pressure tracking
      final tankPressure = _intElement(sample, 'tankPressure');
      if (tankPressure != null && tankId != null) {
        tankPressures
            .putIfAbsent(tankId, () => [])
            .add(_TankReading(runtimeS: runtimeS, pressureBar: tankPressure));

        point['allTankPressures'] = [
          <String, dynamic>{
            'tankIndex': currentTankIndex,
            'pressure': tankPressure.toDouble(),
          },
        ];
      }

      profile.add(point);
    }

    if (profile.isNotEmpty) {
      diveData['profile'] = profile;
    }

    // Duration from last sample runtime
    if (lastRuntimeS != null) {
      diveData['duration'] = Duration(seconds: lastRuntimeS);
      diveData['runtime'] = Duration(seconds: lastRuntimeS);
    }

    // Water temperature (minimum across profile)
    if (minTemp != null) {
      diveData['waterTemp'] = minTemp;
    }

    // CNS at end of dive
    if (lastCns != null && lastCns > 0) {
      diveData['cnsEnd'] = lastCns.toDouble();
    }

    // OTU at end of dive
    if (lastOtu != null && lastOtu > 0) {
      diveData['otu'] = lastOtu.toDouble();
    }

    // Gradient factors
    if (firstGfLow != null) {
      diveData['gradientFactorLow'] = firstGfLow;
    }
    if (firstGfHigh != null) {
      diveData['gradientFactorHigh'] = firstGfHigh;
    }

    // Deco algorithm from first sample
    if (sampleElements.isNotEmpty) {
      final algo = _intElement(sampleElements.first, 'activeAlgorithm');
      if (algo != null) {
        diveData['decoAlgorithm'] = algo == 1 ? 'VPM' : 'Buhlmann';
      }
    }

    // Build tank data
    if (tankIdToIndex.isNotEmpty) {
      _buildTanks(
        tankIdToIndex,
        tankMixes,
        tankPressures,
        diveData,
        prevO2,
        prevHe,
      );
    }

    // Gas switches
    if (gasSwitches.isNotEmpty) {
      diveData['gasSwitches'] = gasSwitches;
    }
  }

  void _buildTanks(
    Map<int, int> tankIdToIndex,
    Map<int, GasMix> tankMixes,
    Map<int, List<_TankReading>> tankPressures,
    Map<String, dynamic> diveData,
    int? lastO2,
    int? lastHe,
  ) {
    final tanks = <Map<String, dynamic>>[];
    var order = 0;

    // Ensure tanks are ordered by their sequential index
    final sortedTankIds = tankIdToIndex.keys.toList()
      ..sort((a, b) => tankIdToIndex[a]!.compareTo(tankIdToIndex[b]!));

    for (final tankId in sortedTankIds) {
      final tank = <String, dynamic>{'order': order};

      final readings = tankPressures[tankId];
      if (readings != null && readings.isNotEmpty) {
        tank['startPressure'] = readings.first.pressureBar.toDouble();
        tank['endPressure'] = readings.last.pressureBar.toDouble();
      }

      final mix = tankMixes[tankId];
      if (mix != null) {
        tank['gasMix'] = mix;
      } else if (tankIdToIndex.length == 1 && lastO2 != null) {
        // Fallback for single-tank dive if we missed the mix somehow
        tank['gasMix'] = GasMix(
          o2: lastO2.toDouble(),
          he: (lastHe ?? 0).toDouble(),
        );
      }

      tanks.add(tank);
      order++;
    }

    if (tanks.isNotEmpty) {
      diveData['tanks'] = tanks;
    }
  }

  // ======================== Filename Parsing ========================

  /// Parses the Ratio filename convention to extract computer model, serial,
  /// and dive number.
  ///
  /// Format: `{model}_{serial}-dive_{number}-{date}_{time}.xml`
  /// Example: `IX3M_2_PRO_012345-dive_16-19880819_165840.xml`
  void _parseFilename(String? fileName, Map<String, dynamic> diveData) {
    if (fileName == null) return;

    // Strip extension
    var stem = fileName;
    final dot = stem.lastIndexOf('.');
    if (dot > 0) stem = stem.substring(0, dot);

    // Split on '-dive_' to separate model+serial from dive number+date
    final diveMarker = stem.indexOf('-dive_');
    if (diveMarker < 0) return;

    final modelSerial = stem.substring(0, diveMarker);
    final afterDive = stem.substring(diveMarker + 6); // skip '-dive_'

    // Dive number is before the next '-'
    final dashAfterNumber = afterDive.indexOf('-');
    if (dashAfterNumber > 0) {
      final diveNumStr = afterDive.substring(0, dashAfterNumber);
      final diveNum = int.tryParse(diveNumStr);
      if (diveNum != null) {
        diveData['diveNumber'] = diveNum;
      }
    }

    // Model and serial: last segment before '-dive_' that is all digits
    // is the serial; everything before it (with underscores -> spaces) is
    // the model.
    final lastUnderscore = modelSerial.lastIndexOf('_');
    if (lastUnderscore > 0) {
      final possibleSerial = modelSerial.substring(lastUnderscore + 1);
      if (RegExp(r'^\d+$').hasMatch(possibleSerial)) {
        diveData['diveComputerSerial'] = possibleSerial;
        final model = modelSerial.substring(0, lastUnderscore);
        diveData['diveComputerModel'] = model.replaceAll('_', ' ');
      } else {
        // No clear serial; use entire string as model
        diveData['diveComputerModel'] = modelSerial.replaceAll('_', ' ');
      }
    }
  }

  // ======================== Helpers ========================

  /// Read the text content of a child element as an int, or null.
  static int? _intElement(XmlElement parent, String name) {
    final el = parent.getElement(name);
    if (el == null) return null;
    return int.tryParse(el.innerText.trim());
  }

  static String _diveModeString(int mode) => switch (mode) {
    0 => 'OC',
    1 => 'SCR',
    2 => 'CCR',
    3 => 'Gauge',
    _ => 'OC',
  };
}

/// Internal helper to track tank pressure readings across samples.
class _TankReading {
  final int runtimeS;
  final int pressureBar;

  const _TankReading({required this.runtimeS, required this.pressureBar});
}
