import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:dive_computer/framework/dive_computer_ffi_bindings_generated.dart';
import 'package:ffi/ffi.dart';

import '../../../../core/services/logger_service.dart';
import '../../domain/services/download_manager.dart';

class _LibdcParserService {}

final _log = LoggerService.forClass(_LibdcParserService);

/// Service for parsing dive data using libdivecomputer FFI.
///
/// This provides access to libdivecomputer's parser API for parsing
/// raw dive data bytes downloaded via custom protocols (like our BLE
/// implementation for Shearwater).
class LibdcParserService {
  static LibdcParserService? _instance;
  static DiveComputerFfiBindings? _bindings;
  static ffi.Pointer<ffi.Pointer<dc_context_t>>? _context;
  static final _descriptorCache = <String, ffi.Pointer<dc_descriptor_t>>{};

  LibdcParserService._();

  /// Get the singleton instance.
  static LibdcParserService get instance {
    _instance ??= LibdcParserService._();
    return _instance!;
  }

  /// Whether the service is initialized.
  bool get isInitialized => _bindings != null && _context != null;

  /// Initialize the libdivecomputer FFI bindings.
  ///
  /// Must be called before using any parsing methods.
  void initialize() {
    if (isInitialized) return;

    _log.info('Initializing libdivecomputer FFI bindings');

    String fileName;
    if (Platform.isWindows) {
      fileName = 'libdivecomputer-0.dll';
    } else if (Platform.isAndroid) {
      fileName = 'libdivecomputer.so';
    } else if (Platform.isMacOS || Platform.isIOS) {
      fileName = 'dive_computer.framework/dive_computer';
    } else {
      throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
    }

    final library = ffi.DynamicLibrary.open(fileName);
    _bindings = DiveComputerFfiBindings(library);

    // Create context
    _context = calloc<ffi.Pointer<dc_context_t>>();
    final result = _bindings!.dc_context_new(_context!);
    if (result != dc_status_t.DC_STATUS_SUCCESS) {
      throw Exception('Failed to create libdivecomputer context: $result');
    }

    _log.info('libdivecomputer FFI initialized');
  }

  /// Get the descriptor for a specific dive computer vendor/product.
  ffi.Pointer<dc_descriptor_t>? getDescriptor(String vendor, String product) {
    if (!isInitialized) {
      throw StateError('LibdcParserService not initialized');
    }

    final key = '$vendor $product';
    if (_descriptorCache.containsKey(key)) {
      return _descriptorCache[key];
    }

    // Iterate through all descriptors to find the matching one
    final iterator = calloc<ffi.Pointer<dc_iterator_t>>();
    final result = _bindings!.dc_descriptor_iterator(iterator);
    if (result != dc_status_t.DC_STATUS_SUCCESS) {
      _log.warning('Failed to create descriptor iterator: $result');
      return null;
    }

    final desc = calloc<ffi.Pointer<dc_descriptor_t>>();
    while (_bindings!.dc_iterator_next(iterator.value, desc.cast()) ==
        dc_status_t.DC_STATUS_SUCCESS) {
      final vendorPtr = _bindings!.dc_descriptor_get_vendor(desc.value);
      final productPtr = _bindings!.dc_descriptor_get_product(desc.value);

      final descVendor = vendorPtr.cast<Utf8>().toDartString();
      final descProduct = productPtr.cast<Utf8>().toDartString();

      if (descVendor.toLowerCase() == vendor.toLowerCase() &&
          descProduct.toLowerCase() == product.toLowerCase()) {
        _descriptorCache[key] = desc.value;
        _bindings!.dc_iterator_free(iterator.value);
        _log.info('Found descriptor for $vendor $product');
        return desc.value;
      }
    }

    _bindings!.dc_iterator_free(iterator.value);
    _log.warning('Descriptor not found for $vendor $product');
    return null;
  }

  /// List all supported dive computers.
  List<({String vendor, String product})> listSupportedComputers() {
    if (!isInitialized) {
      throw StateError('LibdcParserService not initialized');
    }

    final computers = <({String vendor, String product})>[];

    final iterator = calloc<ffi.Pointer<dc_iterator_t>>();
    final result = _bindings!.dc_descriptor_iterator(iterator);
    if (result != dc_status_t.DC_STATUS_SUCCESS) {
      return computers;
    }

    final desc = calloc<ffi.Pointer<dc_descriptor_t>>();
    while (_bindings!.dc_iterator_next(iterator.value, desc.cast()) ==
        dc_status_t.DC_STATUS_SUCCESS) {
      final vendorPtr = _bindings!.dc_descriptor_get_vendor(desc.value);
      final productPtr = _bindings!.dc_descriptor_get_product(desc.value);

      computers.add(
        (
          vendor: vendorPtr.cast<Utf8>().toDartString(),
          product: productPtr.cast<Utf8>().toDartString(),
        ),
      );

      _bindings!.dc_descriptor_free(desc.value);
    }

    _bindings!.dc_iterator_free(iterator.value);
    return computers;
  }

  /// Parse raw dive data bytes using libdivecomputer.
  ///
  /// [vendor] - The dive computer vendor (e.g., "Shearwater")
  /// [product] - The dive computer product (e.g., "Teric")
  /// [data] - The raw dive data bytes
  /// [manifestInfo] - Optional manifest info to supplement parsed data
  ///
  /// Returns a fully parsed [DownloadedDive] with profile samples.
  DownloadedDive? parseDiveData({
    required String vendor,
    required String product,
    required List<int> data,
    DiveManifestInfo? manifestInfo,
  }) {
    if (!isInitialized) {
      throw StateError('LibdcParserService not initialized');
    }

    if (data.isEmpty) {
      _log.warning('Cannot parse empty dive data');
      return null;
    }

    final descriptor = getDescriptor(vendor, product);
    if (descriptor == null) {
      _log.warning('No descriptor for $vendor $product');
      return null;
    }

    _log.info('Parsing ${data.length} bytes for $vendor $product');

    // Log key bytes for debugging (log version is at byte 127 for Shearwater)
    if (data.length > 128) {
      _log.info(
        'Data header bytes [127-131]: '
        '${data.sublist(127, (131).clamp(0, data.length)).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}',
      );
    }

    // Allocate native memory for the data
    final nativeData = calloc<ffi.UnsignedChar>(data.length);
    for (var i = 0; i < data.length; i++) {
      nativeData[i] = data[i];
    }

    final parser = calloc<ffi.Pointer<dc_parser_t>>();

    try {
      // Create parser using dc_parser_new2 (doesn't require device connection)
      final result = _bindings!.dc_parser_new2(
        parser,
        _context!.value,
        descriptor,
        nativeData,
        data.length,
      );

      if (result != dc_status_t.DC_STATUS_SUCCESS) {
        _log.warning('Failed to create parser: $result');
        return null;
      }

      _log.info('Parser created successfully, extracting dive data...');

      // Parse the dive data
      final dive = _parseDiveFromParser(parser.value, manifestInfo);

      // Cleanup
      _bindings!.dc_parser_destroy(parser.value);

      return dive;
    } catch (e, stack) {
      _log.error('Error parsing dive data: $e', e, stack);
      return null;
    } finally {
      calloc.free(nativeData);
      calloc.free(parser);
    }
  }

  DownloadedDive _parseDiveFromParser(
    ffi.Pointer<dc_parser_t> parser,
    DiveManifestInfo? manifestInfo,
  ) {
    // Get dive time
    final diveTimePtr = calloc<ffi.UnsignedInt>();
    var result = _bindings!.dc_parser_get_field(
      parser,
      dc_field_type_t.DC_FIELD_DIVETIME,
      0,
      diveTimePtr.cast(),
    );
    final diveTime = result == dc_status_t.DC_STATUS_SUCCESS
        ? diveTimePtr.value
        : manifestInfo?.durationSeconds ?? 0;
    calloc.free(diveTimePtr);

    // Get max depth
    final maxDepthPtr = calloc<ffi.Double>();
    result = _bindings!.dc_parser_get_field(
      parser,
      dc_field_type_t.DC_FIELD_MAXDEPTH,
      0,
      maxDepthPtr.cast(),
    );
    final maxDepth = result == dc_status_t.DC_STATUS_SUCCESS
        ? maxDepthPtr.value
        : manifestInfo?.maxDepth ?? 0.0;
    calloc.free(maxDepthPtr);

    // Get avg depth
    final avgDepthPtr = calloc<ffi.Double>();
    result = _bindings!.dc_parser_get_field(
      parser,
      dc_field_type_t.DC_FIELD_AVGDEPTH,
      0,
      avgDepthPtr.cast(),
    );
    final avgDepth =
        result == dc_status_t.DC_STATUS_SUCCESS ? avgDepthPtr.value : null;
    calloc.free(avgDepthPtr);

    // Get temperatures
    final tempMinPtr = calloc<ffi.Double>();
    result = _bindings!.dc_parser_get_field(
      parser,
      dc_field_type_t.DC_FIELD_TEMPERATURE_MINIMUM,
      0,
      tempMinPtr.cast(),
    );
    final tempMin =
        result == dc_status_t.DC_STATUS_SUCCESS ? tempMinPtr.value : null;
    calloc.free(tempMinPtr);

    final tempMaxPtr = calloc<ffi.Double>();
    result = _bindings!.dc_parser_get_field(
      parser,
      dc_field_type_t.DC_FIELD_TEMPERATURE_MAXIMUM,
      0,
      tempMaxPtr.cast(),
    );
    final tempMax =
        result == dc_status_t.DC_STATUS_SUCCESS ? tempMaxPtr.value : null;
    calloc.free(tempMaxPtr);

    // Get date/time
    final dateTimePtr = calloc<dc_datetime_t>();
    result = _bindings!.dc_parser_get_datetime(parser, dateTimePtr);
    DateTime startTime;
    if (result == dc_status_t.DC_STATUS_SUCCESS) {
      startTime = DateTime(
        dateTimePtr.ref.year,
        dateTimePtr.ref.month,
        dateTimePtr.ref.day,
        dateTimePtr.ref.hour,
        dateTimePtr.ref.minute,
        dateTimePtr.ref.second,
      );
    } else {
      startTime = manifestInfo?.dateTime ?? DateTime.now();
    }
    calloc.free(dateTimePtr);

    // Parse gas mixes
    var tanks = _parseGasMixes(parser);

    // Parse profile samples
    final samples = _parseSamples(parser);

    // Calculate start/end pressure from profile samples if not in tank data
    tanks = _enrichTankPressuresFromSamples(tanks, samples);

    _log.info(
      'Parsed dive: ${samples.length} samples, '
      'duration=${diveTime}s, maxDepth=${maxDepth}m, '
      '${tanks.length} tanks',
    );

    return DownloadedDive(
      diveNumber: manifestInfo?.diveNumber,
      startTime: startTime,
      durationSeconds: diveTime,
      maxDepth: maxDepth,
      avgDepth: avgDepth,
      minTemperature: tempMin,
      maxTemperature: tempMax,
      profile: samples,
      tanks: tanks,
      fingerprint: manifestInfo?.fingerprint,
    );
  }

  /// Enrich tank data with start/end pressures calculated from profile samples.
  ///
  /// If no tanks exist but we have pressure samples, create a default tank.
  /// If tanks exist but lack start/end pressure, calculate from samples.
  List<DownloadedTank> _enrichTankPressuresFromSamples(
    List<DownloadedTank> tanks,
    List<ProfileSample> samples,
  ) {
    // Get pressure samples
    final pressureSamples =
        samples.where((s) => s.pressure != null && s.pressure! > 0).toList();

    if (pressureSamples.isEmpty) {
      _log.info('No pressure samples to calculate tank pressures');
      return tanks;
    }

    // Calculate start and end pressure from samples
    final startPressure = pressureSamples.first.pressure;
    final endPressure = pressureSamples.last.pressure;

    _log.info(
      'Calculated from samples: startPressure=$startPressure bar, '
      'endPressure=$endPressure bar',
    );

    // If no tanks, create a default one with air
    if (tanks.isEmpty) {
      _log.info('Creating default tank with pressure from samples');
      return [
        DownloadedTank(
          index: 0,
          o2Percent: 21.0,
          hePercent: 0.0,
          startPressure: startPressure,
          endPressure: endPressure,
        ),
      ];
    }

    // Update first tank if it lacks pressure data
    final updatedTanks = <DownloadedTank>[];
    for (var i = 0; i < tanks.length; i++) {
      final tank = tanks[i];
      if (i == 0 && (tank.startPressure == null || tank.endPressure == null)) {
        updatedTanks.add(
          DownloadedTank(
            index: tank.index,
            o2Percent: tank.o2Percent,
            hePercent: tank.hePercent,
            startPressure: tank.startPressure ?? startPressure,
            endPressure: tank.endPressure ?? endPressure,
            volumeLiters: tank.volumeLiters,
          ),
        );
        _log.info(
          'Enriched tank ${tank.index} with sample pressures: '
          'start=${tank.startPressure ?? startPressure}, '
          'end=${tank.endPressure ?? endPressure}',
        );
      } else {
        updatedTanks.add(tank);
      }
    }

    return updatedTanks;
  }

  List<DownloadedTank> _parseGasMixes(ffi.Pointer<dc_parser_t> parser) {
    final tanks = <DownloadedTank>[];

    // Get gas mix count
    final countPtr = calloc<ffi.UnsignedInt>();
    var result = _bindings!.dc_parser_get_field(
      parser,
      dc_field_type_t.DC_FIELD_GASMIX_COUNT,
      0,
      countPtr.cast(),
    );

    if (result != dc_status_t.DC_STATUS_SUCCESS) {
      calloc.free(countPtr);
      _log.info('No gas mixes found in dive data');
      return tanks;
    }

    final count = countPtr.value;
    calloc.free(countPtr);
    _log.info('Found $count gas mixes');

    // Get each gas mix
    final gasmixPtr = calloc<dc_gasmix_t>();
    for (var i = 0; i < count; i++) {
      result = _bindings!.dc_parser_get_field(
        parser,
        dc_field_type_t.DC_FIELD_GASMIX,
        i,
        gasmixPtr.cast(),
      );

      if (result == dc_status_t.DC_STATUS_SUCCESS) {
        tanks.add(
          DownloadedTank(
            index: i,
            o2Percent: gasmixPtr.ref.oxygen * 100,
            hePercent: gasmixPtr.ref.helium * 100,
          ),
        );
        _log.info(
          'Gas mix $i: O2=${gasmixPtr.ref.oxygen * 100}%, '
          'He=${gasmixPtr.ref.helium * 100}%',
        );
      }
    }
    calloc.free(gasmixPtr);

    // Try to get tank pressures from DC_FIELD_TANK
    final tankCountPtr = calloc<ffi.UnsignedInt>();
    result = _bindings!.dc_parser_get_field(
      parser,
      dc_field_type_t.DC_FIELD_TANK_COUNT,
      0,
      tankCountPtr.cast(),
    );

    if (result == dc_status_t.DC_STATUS_SUCCESS) {
      final tankCount = tankCountPtr.value;
      _log.info('Found $tankCount tanks with pressure data');
      final tankPtr = calloc<dc_tank_t>();

      for (var i = 0; i < tankCount && i < tanks.length; i++) {
        result = _bindings!.dc_parser_get_field(
          parser,
          dc_field_type_t.DC_FIELD_TANK,
          i,
          tankPtr.cast(),
        );

        if (result == dc_status_t.DC_STATUS_SUCCESS) {
          // libdivecomputer returns pressure in bar, not Pa
          final beginPressure = tankPtr.ref.beginpressure;
          final endPressure = tankPtr.ref.endpressure;
          _log.info(
            'Tank $i: beginPressure=$beginPressure bar, '
            'endPressure=$endPressure bar',
          );

          // Update tank with pressure info
          tanks[i] = DownloadedTank(
            index: i,
            o2Percent: tanks[i].o2Percent,
            hePercent: tanks[i].hePercent,
            startPressure: beginPressure > 0 ? beginPressure : null,
            endPressure: endPressure > 0 ? endPressure : null,
          );
        }
      }
      calloc.free(tankPtr);
    } else {
      _log.info('No tank pressure data from parser');
    }
    calloc.free(tankCountPtr);

    return tanks;
  }

  // Static storage for sample callback
  static final _sampleData = <_SamplePoint>[];
  static int _currentSampleTime = 0;
  static int _pressureSampleCount = 0;

  List<ProfileSample> _parseSamples(ffi.Pointer<dc_parser_t> parser) {
    _sampleData.clear();
    _currentSampleTime = 0;
    _pressureSampleCount = 0;

    // Use dc_parser_samples_foreach to iterate samples
    final result = _bindings!.dc_parser_samples_foreach(
      parser,
      ffi.Pointer.fromFunction(_sampleCallback),
      ffi.nullptr,
    );

    if (result != dc_status_t.DC_STATUS_SUCCESS) {
      _log.warning('Failed to parse samples: $result');
      return [];
    }

    // Log sample statistics
    final samplesWithPressure =
        _sampleData.where((s) => s.pressure != null).length;
    _log.info(
      'Parsed ${_sampleData.length} samples, '
      '$_pressureSampleCount pressure callbacks received, '
      '$samplesWithPressure samples have pressure data',
    );

    // Convert to ProfileSample list
    return _sampleData
        .map(
          (s) => ProfileSample(
            timeSeconds: s.time,
            depth: s.depth,
            temperature: s.temperature,
            pressure: s.pressure,
          ),
        )
        .toList();
  }

  static void _sampleCallback(
    int type,
    ffi.Pointer<dc_sample_value_t> value,
    ffi.Pointer<ffi.Void> userdata,
  ) {
    switch (type) {
      case dc_sample_type_t.DC_SAMPLE_TIME:
        // Time is in seconds from libdivecomputer
        final time = value.cast<ffi.UnsignedInt>().value;
        _currentSampleTime = time;
        _sampleData.add(_SamplePoint(_currentSampleTime));
        break;

      case dc_sample_type_t.DC_SAMPLE_DEPTH:
        final depth = value.cast<ffi.Double>().value;
        if (_sampleData.isNotEmpty) {
          _sampleData.last.depth = depth;
        }
        break;

      case dc_sample_type_t.DC_SAMPLE_TEMPERATURE:
        final temp = value.cast<ffi.Double>().value;
        if (_sampleData.isNotEmpty) {
          _sampleData.last.temperature = temp;
        }
        break;

      case dc_sample_type_t.DC_SAMPLE_PRESSURE:
        // Pressure struct: tank index (uint) and value (double) in bar
        _pressureSampleCount++;
        final pressurePtr = value.cast<_PressureSample>();
        final pressure = pressurePtr.ref.value;
        // Store pressure for any valid tank (first one we see for each sample)
        // libdivecomputer returns pressure in bar
        if (_sampleData.isNotEmpty && pressure > 0) {
          // Only store if we don't already have pressure for this sample
          _sampleData.last.pressure ??= pressure;
        }
        break;
    }
  }

  /// Cleanup resources.
  void dispose() {
    if (_context != null) {
      _bindings!.dc_context_free(_context!.value);
      calloc.free(_context!);
      _context = null;
    }

    for (final desc in _descriptorCache.values) {
      _bindings!.dc_descriptor_free(desc);
    }
    _descriptorCache.clear();

    _bindings = null;
    _instance = null;

    _log.info('libdivecomputer FFI disposed');
  }
}

/// Internal sample point during parsing.
class _SamplePoint {
  final int time;
  double depth = 0.0;
  double? temperature;
  double? pressure;

  _SamplePoint(this.time);
}

/// Pressure sample struct layout matching libdivecomputer.
final class _PressureSample extends ffi.Struct {
  @ffi.UnsignedInt()
  external int tank;

  @ffi.Double()
  external double value;
}

/// Manifest information to supplement parsed data.
class DiveManifestInfo {
  final int? diveNumber;
  final DateTime dateTime;
  final int durationSeconds;
  final double maxDepth;
  final String? fingerprint;

  const DiveManifestInfo({
    this.diveNumber,
    required this.dateTime,
    required this.durationSeconds,
    required this.maxDepth,
    this.fingerprint,
  });
}
