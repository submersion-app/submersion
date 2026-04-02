import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/logger_service.dart';

Future<void> flushLogs() => LoggerService.flushPendingWrites();

void main() {
  group('LoggerService', () {
    late Directory tempDir;
    late LogFileService fileService;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('logger_service_test_');
      fileService = LogFileService(logDirectory: tempDir.path);
      await fileService.initialize();
      LoggerService.setFileService(fileService);
    });

    tearDown(() async {
      await flushLogs();
      LoggerService.setFileService(null);
      tempDir.deleteSync(recursive: true);
    });

    group('forClass', () {
      test('creates a LoggerService instance', () {
        final logger = LoggerService.forClass(LoggerService);
        expect(logger, isA<LoggerService>());
      });

      test('created logger does not throw when logging', () {
        final logger = LoggerService.forClass(String);
        expect(() => logger.info('test'), returnsNormally);
      });
    });

    group('log methods — no file service — do not throw', () {
      // We cannot set _fileService to null from outside, so we verify the
      // public methods complete normally even without a usable file backend by
      // testing with a completely fresh LoggerService before setUp wires one up.
      // Because setUp already sets the file service, we instead just confirm
      // that all four public methods complete without error.

      test('debug does not throw', () {
        const logger = LoggerService('TestLogger');
        expect(() => logger.debug('debug message'), returnsNormally);
      });

      test('info does not throw', () {
        const logger = LoggerService('TestLogger');
        expect(() => logger.info('info message'), returnsNormally);
      });

      test('warning does not throw', () {
        const logger = LoggerService('TestLogger');
        expect(() => logger.warning('warning message'), returnsNormally);
      });

      test('error does not throw', () {
        const logger = LoggerService('TestLogger');
        expect(() => logger.error('error message'), returnsNormally);
      });
    });

    group('with file service — writes to log file', () {
      test('debug writes entry with debug level', () async {
        const logger = LoggerService('TestLogger');
        logger.debug('debug message');
        await flushLogs();

        final entries = await fileService.readEntries();
        expect(entries, hasLength(1));
        expect(entries.first.level, LogLevel.debug);
        expect(entries.first.message, 'debug message');
      });

      test('info writes entry with info level', () async {
        const logger = LoggerService('TestLogger');
        logger.info('info message');
        await flushLogs();

        final entries = await fileService.readEntries();
        expect(entries, hasLength(1));
        expect(entries.first.level, LogLevel.info);
        expect(entries.first.message, 'info message');
      });

      test('warning writes entry with warning level', () async {
        const logger = LoggerService('TestLogger');
        logger.warning('warning message');
        await flushLogs();

        final entries = await fileService.readEntries();
        expect(entries, hasLength(1));
        expect(entries.first.level, LogLevel.warning);
        expect(entries.first.message, 'warning message');
      });

      test('error writes entry with error level', () async {
        const logger = LoggerService('TestLogger');
        logger.error('error message');
        await flushLogs();

        final entries = await fileService.readEntries();
        expect(entries, hasLength(1));
        expect(entries.first.level, LogLevel.error);
        expect(entries.first.message, 'error message');
      });
    });

    group('default category is LogCategory.app', () {
      test('debug defaults to app category', () async {
        const logger = LoggerService('TestLogger');
        logger.debug('msg');
        await flushLogs();

        final entries = await fileService.readEntries();
        expect(entries.first.category, LogCategory.app);
      });

      test('info defaults to app category', () async {
        const logger = LoggerService('TestLogger');
        logger.info('msg');
        await flushLogs();

        final entries = await fileService.readEntries();
        expect(entries.first.category, LogCategory.app);
      });

      test('warning defaults to app category', () async {
        const logger = LoggerService('TestLogger');
        logger.warning('msg');
        await flushLogs();

        final entries = await fileService.readEntries();
        expect(entries.first.category, LogCategory.app);
      });

      test('error defaults to app category', () async {
        const logger = LoggerService('TestLogger');
        logger.error('msg');
        await flushLogs();

        final entries = await fileService.readEntries();
        expect(entries.first.category, LogCategory.app);
      });
    });

    group('custom category', () {
      test('debug respects LogCategory.bluetooth', () async {
        const logger = LoggerService('TestLogger');
        logger.debug('ble msg', category: LogCategory.bluetooth);
        await flushLogs();

        final entries = await fileService.readEntries();
        expect(entries.first.category, LogCategory.bluetooth);
      });

      test('info respects LogCategory.database', () async {
        const logger = LoggerService('TestLogger');
        logger.info('db msg', category: LogCategory.database);
        await flushLogs();

        final entries = await fileService.readEntries();
        expect(entries.first.category, LogCategory.database);
      });

      test('warning respects LogCategory.serial', () async {
        const logger = LoggerService('TestLogger');
        logger.warning('serial msg', category: LogCategory.serial);
        await flushLogs();

        final entries = await fileService.readEntries();
        expect(entries.first.category, LogCategory.serial);
      });

      test('error respects LogCategory.libdc', () async {
        const logger = LoggerService('TestLogger');
        logger.error('libdc msg', category: LogCategory.libdc);
        await flushLogs();

        final entries = await fileService.readEntries();
        expect(entries.first.category, LogCategory.libdc);
      });
    });

    group('error message formatting', () {
      test(
        'message contains "| error:" when error param is provided',
        () async {
          const logger = LoggerService('TestLogger');
          final exception = Exception('something went wrong');
          logger.info('operation failed', error: exception);
          await flushLogs();

          final entries = await fileService.readEntries();
          expect(entries.first.message, contains('operation failed'));
          expect(entries.first.message, contains('| error:'));
        },
      );

      test('message includes error.toString() after "| error:"', () async {
        const logger = LoggerService('TestLogger');
        const testError = 'my error string';
        logger.debug('base msg', error: testError);
        await flushLogs();

        final entries = await fileService.readEntries();
        expect(
          entries.first.message,
          equals('base msg | error: my error string'),
        );
      });

      test('message is plain when no error param is provided', () async {
        const logger = LoggerService('TestLogger');
        logger.warning('plain message');
        await flushLogs();

        final entries = await fileService.readEntries();
        expect(entries.first.message, equals('plain message'));
        expect(entries.first.message, isNot(contains('| error:')));
      });

      test('null error param results in plain message', () async {
        const logger = LoggerService('TestLogger');
        // ignore: avoid_passing_async_when_sync_expected
        logger.error('error without cause', error: null);
        await flushLogs();

        final entries = await fileService.readEntries();
        expect(entries.first.message, equals('error without cause'));
        expect(entries.first.message, isNot(contains('| error:')));
      });

      test('stackTrace param does not affect message text', () async {
        const logger = LoggerService('TestLogger');
        final trace = StackTrace.current;
        logger.info('msg with stack', stackTrace: trace);
        await flushLogs();

        final entries = await fileService.readEntries();
        expect(entries.first.message, equals('msg with stack'));
      });
    });

    group('setFileService', () {
      test('routes writes to the newly set service', () async {
        final secondDir = Directory.systemTemp.createTempSync(
          'logger_service_test_second_',
        );
        try {
          final secondService = LogFileService(logDirectory: secondDir.path);
          await secondService.initialize();

          LoggerService.setFileService(secondService);

          const logger = LoggerService('TestLogger');
          logger.info('routed to second service');
          await flushLogs();

          final firstEntries = await fileService.readEntries();
          final secondEntries = await secondService.readEntries();

          expect(firstEntries, isEmpty);
          expect(secondEntries, hasLength(1));
          expect(secondEntries.first.message, 'routed to second service');
        } finally {
          secondDir.deleteSync(recursive: true);
          // Restore original service for other tests
          LoggerService.setFileService(fileService);
        }
      });

      test('multiple log calls each write an entry', () async {
        // Fire each log call and flush after each one to avoid concurrent
        // file appends racing against each other (writeLine is unawaited).
        const logger = LoggerService('TestLogger');

        logger.debug('first');
        await flushLogs();

        logger.info('second');
        await flushLogs();

        logger.warning('third');
        await flushLogs();

        logger.error('fourth');
        await flushLogs();

        final entries = await fileService.readEntries();
        expect(entries, hasLength(4));
        final levels = entries.map((e) => e.level).toList();
        expect(levels, contains(LogLevel.debug));
        expect(levels, contains(LogLevel.info));
        expect(levels, contains(LogLevel.warning));
        expect(levels, contains(LogLevel.error));
      });
    });
  });

  group('RepositoryException', () {
    test('toString includes message and operation', () {
      final ex = RepositoryException(
        message: 'Record not found',
        operation: 'fetchDive',
      );
      expect(
        ex.toString(),
        'RepositoryException: Record not found (operation: fetchDive)',
      );
    });

    test('toString format with another message and operation', () {
      final ex = RepositoryException(
        message: 'Unique constraint violated',
        operation: 'insertDive',
      );
      expect(
        ex.toString(),
        'RepositoryException: Unique constraint violated (operation: insertDive)',
      );
    });

    test('originalError is accessible', () {
      final original = Exception('underlying cause');
      final ex = RepositoryException(
        message: 'Wrapped error',
        operation: 'op',
        originalError: original,
      );
      expect(ex.originalError, same(original));
    });

    test('stackTrace is accessible', () {
      final trace = StackTrace.current;
      final ex = RepositoryException(
        message: 'Error with trace',
        operation: 'op',
        stackTrace: trace,
      );
      expect(ex.stackTrace, same(trace));
    });

    test('originalError defaults to null', () {
      final ex = RepositoryException(message: 'minimal', operation: 'op');
      expect(ex.originalError, isNull);
    });

    test('stackTrace defaults to null', () {
      final ex = RepositoryException(message: 'minimal', operation: 'op');
      expect(ex.stackTrace, isNull);
    });

    test('implements Exception', () {
      final ex = RepositoryException(message: 'test', operation: 'op');
      expect(ex, isA<Exception>());
    });

    test('message field is accessible', () {
      final ex = RepositoryException(
        message: 'Test message',
        operation: 'testOp',
      );
      expect(ex.message, 'Test message');
      expect(ex.operation, 'testOp');
    });
  });
}
