import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/species_id/data/services/memory_readout.dart';
import 'package:submersion/features/species_id/domain/entities/vision_memory.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

import 'fake_vision_engine.dart';

const _mib = 1048576;

const _full = VisionMemory(
  footprintBytes: 612 * _mib,
  footprintPeakBytes: 845 * _mib,
  availableBytes: 2412 * _mib,
  neuralCountedBytes: 0,
  neuralNotCountedBytes: 717 * _mib,
  neuralNotCountedPeakBytes: 717 * _mib,
);

void main() {
  group('describeMemory', () {
    test('describes a full reading', () {
      expect(
        describeMemory('pass 2 (0:20 to 0:30)', _full),
        'Memory after pass 2 (0:20 to 0:30): 2412 MB left, footprint 612 MB '
        '(peak 845 MB), 2179 MB left at the peak, Neural Engine 717 MB not '
        'counted (peak 717 MB), 0 MB counted',
      );
    });

    test('a reading with no limit leaves out what is left', () {
      const noLimit = VisionMemory(
        footprintBytes: 612 * _mib,
        footprintPeakBytes: 845 * _mib,
        neuralCountedBytes: 0,
        neuralNotCountedBytes: 717 * _mib,
        neuralNotCountedPeakBytes: 717 * _mib,
      );
      expect(
        describeMemory('load', noLimit),
        'Memory after load: footprint 612 MB (peak 845 MB), Neural Engine '
        '717 MB not counted (peak 717 MB), 0 MB counted',
      );
    });

    test('a reading with only the footprint', () {
      expect(
        describeMemory('load', const VisionMemory(footprintBytes: 612 * _mib)),
        'Memory after load: footprint 612 MB',
      );
    });
  });

  group('MemoryReadout.record', () {
    late FakeEngine engine;
    late List<LogEntry> seen;

    setUp(() {
      engine = FakeEngine()..memoryReading = _full;
      seen = <LogEntry>[];
      final sub = LoggerService.logStream.listen(seen.add);
      addTearDown(sub.cancel);
    });

    List<LogEntry> memoryLines() => [
      for (final e in seen)
        if (e.level == LogLevel.info && e.message.startsWith('Memory after')) e,
    ];

    test('record does nothing when info lines are not kept', () async {
      await MemoryReadout(engine: engine, enabled: () => false).record('photo');
      await Future<void>.delayed(Duration.zero);
      expect(engine.events, isNot(contains('memory')));
      expect(memoryLines(), isEmpty);
    });

    test('record logs one info line', () async {
      await MemoryReadout(engine: engine, enabled: () => true).record('photo');
      await Future<void>.delayed(Duration.zero);
      expect(memoryLines(), hasLength(1));
      expect(memoryLines().single.message, startsWith('Memory after photo:'));
    });

    test('record swallows a failed reading', () async {
      engine.memoryFailure = const VisionEngineException('unsupported');
      await MemoryReadout(engine: engine, enabled: () => true).record('photo');
      await Future<void>.delayed(Duration.zero);
      expect(engine.events, contains('memory'));
      expect(memoryLines(), isEmpty);
    });
  });
}
