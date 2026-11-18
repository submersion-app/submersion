import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/species_id/domain/entities/vision_memory.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

/// Logs the app's memory after a marine life identification stage, for the
/// iPhone memory test (see docs/developer/species-identification.md). It
/// asks the engine only while debug mode keeps info lines in the log file,
/// so with debug mode off it does nothing at all.
class MemoryReadout {
  MemoryReadout({required VisionEngine engine, bool Function()? enabled})
    : _engine = engine,
      _enabled = enabled ?? _infoLinesKept;

  final VisionEngine _engine;
  final bool Function() _enabled;
  final _log = LoggerService.forClass(MemoryReadout);

  static bool _infoLinesKept() =>
      LoggerService.minimumFileLevel.index <= LogLevel.info.index;

  /// Logs one line for [stage]. Never throws: a reading that fails is
  /// logged at debug level and dropped, so identification never sees it.
  Future<void> record(String stage) async {
    if (!_enabled()) return;
    try {
      _log.info(describeMemory(stage, await _engine.memory()));
    } on Object catch (e) {
      _log.debug('Could not read memory after $stage', error: e);
    }
  }
}

/// The log line for [reading] taken after [stage], in MiB. A figure the
/// platform does not report is left out, never shown as zero.
String describeMemory(String stage, VisionMemory reading) {
  String mb(int bytes) => '${(bytes / 1048576).round()} MB';
  final available = reading.availableBytes;
  final peak = reading.footprintPeakBytes;
  final notCounted = reading.neuralNotCountedBytes;
  final notCountedPeak = reading.neuralNotCountedPeakBytes;
  final counted = reading.neuralCountedBytes;
  final neural = <String>[
    if (notCounted != null)
      '${mb(notCounted)} not counted'
          '${notCountedPeak != null ? ' (peak ${mb(notCountedPeak)})' : ''}',
    if (counted != null) '${mb(counted)} counted',
  ];
  final parts = <String>[
    if (available != null) '${mb(available)} left',
    'footprint ${mb(reading.footprintBytes)}'
        '${peak != null ? ' (peak ${mb(peak)})' : ''}',
    if (available != null && peak != null)
      '${mb(available + reading.footprintBytes - peak)} left at the peak',
    if (neural.isNotEmpty) 'Neural Engine ${neural.join(', ')}',
  ];
  return 'Memory after $stage: ${parts.join(', ')}';
}
