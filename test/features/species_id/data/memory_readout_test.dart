import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/species_id/data/services/memory_readout.dart';
import 'package:submersion/features/species_id/domain/entities/vision_memory.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

import '../../../helpers/temp_dir.dart';
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
        'Memory after pass 2 (0:20 to 0:30): 2412 MiB left, footprint 612 MiB '
        '(peak 845 MiB), 2179 MiB left at the peak, Neural Engine 717 MiB not '
        'counted (peak 717 MiB), 0 MiB counted',
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
        'Memory after load: footprint 612 MiB (peak 845 MiB), Neural Engine '
        '717 MiB not counted (peak 717 MiB), 0 MiB counted',
      );
    });

    test('a reading with nothing left gives no figure at the peak', () {
      // At or over the limit the limit itself is unknown, so the room left
      // at the peak cannot be worked out.
      const overLimit = VisionMemory(
        footprintBytes: 3000 * _mib,
        footprintPeakBytes: 3100 * _mib,
        availableBytes: 0,
      );
      expect(
        describeMemory('photo', overLimit),
        'Memory after photo: 0 MiB left, footprint 3000 MiB (peak 3100 MiB)',
      );
    });

    test('a reading with only the footprint', () {
      expect(
        describeMemory('load', const VisionMemory(footprintBytes: 612 * _mib)),
        'Memory after load: footprint 612 MiB',
      );
    });
  });

  group('MemoryReadout', () {
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

    test('recordLater builds no stage name while readings are off', () async {
      var built = 0;
      MemoryReadout(engine: engine, enabled: () => false).recordLater(() {
        built++;
        return 'photo';
      });
      await Future<void>.delayed(Duration.zero);
      expect(built, 0);
      expect(engine.events, isNot(contains('memory')));
    });

    test('recordLater asks at once and logs without being awaited', () async {
      final gate = engine.memoryGate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      MemoryReadout(
        engine: engine,
        enabled: () => true,
      ).recordLater(() => 'photo');
      expect(engine.events, ['memory']);
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(memoryLines().single.message, startsWith('Memory after photo:'));
    });

    group('with the real gate', () {
      late Directory dir;

      setUp(() {
        final levelBefore = LoggerService.minimumFileLevel;
        dir = Directory.systemTemp.createTempSync('memory_readout_test_');
        addTearDown(() async {
          await LoggerService.flushPendingWrites();
          LoggerService.setFileService(null);
          LoggerService.setMinimumFileLevel(levelBefore);
          await deleteTempDir(dir);
        });
      });

      test('record reads only while debug mode keeps info lines', () async {
        final file = LogFileService(logDirectory: dir.path);
        await file.initialize();
        LoggerService.configureFileLogging(file, verbose: false);
        await MemoryReadout(engine: engine).record('photo');
        expect(engine.events, isNot(contains('memory')));
        LoggerService.configureFileLogging(file, verbose: true);
        await MemoryReadout(engine: engine).record('photo');
        expect(engine.events, contains('memory'));
      });

      test('record reads nothing while no log file is attached', () async {
        // The level is debug until a file is attached; with no file the
        // lines would go nowhere.
        LoggerService.setFileService(null);
        LoggerService.setMinimumFileLevel(LogLevel.debug);
        await MemoryReadout(engine: engine).record('photo');
        expect(engine.events, isNot(contains('memory')));
      });
    });
  });
}
