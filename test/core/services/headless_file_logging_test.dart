// Issue #4572: the WorkManager isolate never attached the log file, so a
// scheduled backup's warnings and errors never reached the debug log.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/headless_file_logging.dart';
import 'package:submersion/core/services/logger_service.dart';

void main() {
  late Directory support;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('headless_logging_');
    addTearDown(() => support.delete(recursive: true));
    final originalFileLevel = LoggerService.minimumFileLevel;
    addTearDown(() {
      LoggerService.setFileService(null);
      LoggerService.setMinimumFileLevel(originalFileLevel);
    });
  });

  Future<SharedPreferences> prefs({bool debugMode = false}) async {
    SharedPreferences.setMockInitialValues({
      LoggerService.debugModePrefKey: debugMode,
    });
    return SharedPreferences.getInstance();
  }

  File logFile() => File(p.join(support.path, 'logs', 'submersion.log'));

  Future<String> logged() async {
    await LoggerService.flushPendingWrites();
    return logFile().existsSync() ? logFile().readAsString() : '';
  }

  test('warnings reach the same log file the app writes', () async {
    final attached = await attachHeadlessFileLogging(
      await prefs(),
      supportDirectory: () async => support.path,
    );
    const LoggerService('BackgroundService').warning('prune stalled');
    const LoggerService('BackgroundService').info('backup is due');

    expect(attached, isTrue);
    final text = await logged();
    expect(text, contains('prune stalled'));
    expect(
      text,
      isNot(contains('backup is due')),
      reason: 'without debug mode only warnings and errors are kept',
    );
  });

  test('debug mode keeps the info lines too', () async {
    await attachHeadlessFileLogging(
      await prefs(debugMode: true),
      supportDirectory: () async => support.path,
    );
    const LoggerService('BackgroundService').info('Pruning 3 old backups');

    expect(await logged(), contains('Pruning 3 old backups'));
  });

  test('a log directory it cannot reach does not fail the task', () async {
    final attached = await attachHeadlessFileLogging(
      await prefs(),
      supportDirectory: () async => throw const FileSystemException('no dir'),
    );

    expect(attached, isFalse);
  });

  group('flushingLogs', () {
    test('the lines a task logged are in the file when it returns', () async {
      await attachHeadlessFileLogging(
        await prefs(),
        supportDirectory: () async => support.path,
      );
      final task = flushingLogs((name, _) async {
        const LoggerService('BackgroundService').warning('ran $name');
        return true;
      });

      expect(await task('backup', null), isTrue);
      expect(logFile().readAsStringSync(), contains('ran backup'));
    });

    test('a task that throws still flushes, and the error reaches the '
        'caller', () async {
      await attachHeadlessFileLogging(
        await prefs(),
        supportDirectory: () async => support.path,
      );
      final task = flushingLogs((name, _) async {
        const LoggerService('BackgroundService').error('failing $name');
        throw StateError('boom');
      });

      await expectLater(task('backup', null), throwsStateError);
      expect(logFile().readAsStringSync(), contains('failing backup'));
    });
  });
}
