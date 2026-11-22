import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/species_id/data/engines/onnx/device_memory.dart';

const _meminfo = '''
MemTotal:        5839928 kB
MemFree:          212344 kB
MemAvailable:    2109876 kB
Buffers:           10520 kB
''';

const _status = '''
Name:\tapp.submersion
VmPeak:\t 9876543 kB
VmHWM:\t  812340 kB
VmRSS:\t  604112 kB
Threads:\t62
''';

void main() {
  test('reads the total and available memory from /proc/meminfo', () {
    expect(parseMemTotal(_meminfo), 5839928 * 1024);
    expect(parseMemAvailable(_meminfo), 2109876 * 1024);
    expect(parseMemTotal('nothing here'), isNull);
  });

  test('reads the footprint and its peak from /proc/self/status', () {
    final reading = parseProcStatus(_status);
    expect(reading.rss, 604112 * 1024);
    expect(reading.hwm, 812340 * 1024);
    expect(parseProcStatus('').rss, isNull);
  });

  test('the floors sit between 6 GB and 8 GB devices', () {
    // A 6 GB device never reports more than 6 GiB; an 8 GB one a little
    // under 8 GiB.
    expect(pcMinimumMemoryBytes, 6979321856);
    expect(androidMinimumMemoryBytes, 6979321856);
    expect(pcMinimumMemoryBytes, greaterThan(6 * 1024 * 1024 * 1024));
    expect(pcMinimumMemoryBytes, lessThan(7.5 * 1024 * 1024 * 1024));
  });

  group('ProcDeviceMemory', () {
    ProcDeviceMemory memory({
      Future<({bool lowMemory, int availableBytes})> Function()? systemState,
    }) => ProcDeviceMemory(
      read: (path) async => switch (path) {
        '/proc/meminfo' => _meminfo,
        '/proc/self/status' => _status,
        _ => throw ArgumentError(path),
      },
      systemState: systemState,
    );

    test('gives the total from /proc/meminfo', () async {
      expect(await memory().totalBytes(), 5839928 * 1024);
    });

    test('reads the footprint, its peak and what is available', () async {
      final reading = await memory().reading();
      expect(reading.footprintBytes, 604112 * 1024);
      expect(reading.footprintPeakBytes, 812340 * 1024);
      expect(reading.availableBytes, 2109876 * 1024);
      // MemAvailable is the whole device's, not a per-app limit.
      expect(reading.availableIsDeviceWide, isTrue);
      expect(reading.lowMemory, isNull);
      expect(reading.neuralCountedBytes, isNull);
    });

    test('a /proc it may not read gives an empty reading, not an '
        'error', () async {
      final reading = await ProcDeviceMemory(
        read: (path) async => throw FileSystemException('denied', path),
      ).reading();
      expect(reading.footprintBytes, 0);
      expect(reading.footprintPeakBytes, isNull);
      expect(reading.availableBytes, isNull);
    });

    test('on Android the system state gives what is available and low '
        'memory', () async {
      final reading = await memory(
        systemState: () async => (lowMemory: true, availableBytes: 123),
      ).reading();
      expect(reading.availableBytes, 123);
      expect(reading.availableIsDeviceWide, isTrue);
      expect(reading.lowMemory, isTrue);
    });
  });
}
