import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/log_environment.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/settings/presentation/providers/diagnostics_actions.dart';

/// Fixed environment so the header is byte-comparable across renders.
final _environment = LogEnvironment(
  appVersion: '1.7.6.123',
  platform: 'windows',
  osVersion: '"Windows 11 Pro" 10.0 (Build 26100)',
  locale: 'en_US',
  buildMode: 'release',
  capturedAt: DateTime(2026, 9, 12, 9, 30),
);

void main() {
  late Directory tempDir;
  late LogFileService service;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('diagnostics_test_');
    service = LogFileService(logDirectory: tempDir.path);
    await service.initialize();
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  void writeRaw(String content) =>
      File(service.logFilePath).writeAsStringSync(content);

  group('buildDiagnosticsReport', () {
    test('starts with the environment header and the logging mode', () async {
      writeRaw('[2026-09-12T09:00:00.000] [APP] [ERROR] boom\n');

      final report = await buildDiagnosticsReport(
        service,
        verboseLogging: false,
        environment: _environment,
      );

      expect(report, startsWith(_environment.toExportHeader()));
      expect(report, contains('verbose logging: off'));
      expect(report, endsWith('[2026-09-12T09:00:00.000] [APP] [ERROR] boom'));
    });

    test('reports verbose logging when debug mode is on', () async {
      final report = await buildDiagnosticsReport(
        service,
        verboseLogging: true,
        environment: _environment,
      );

      expect(report, contains('verbose logging: on'));
    });

    test('keeps only the newest lines', () async {
      writeRaw([for (var i = 0; i < 10; i++) 'line $i'].join('\n'));

      final report = await buildDiagnosticsReport(
        service,
        verboseLogging: false,
        environment: _environment,
        maxLines: 3,
      );

      expect(report, isNot(contains('line 6')));
      expect(report, endsWith('line 7\nline 8\nline 9'));
    });

    test('keeps continuation lines the log viewer cannot parse', () async {
      // A multi-line error message spills onto lines without the
      // [timestamp] [CAT] [LEVEL] prefix; readEntries drops those, but they
      // are often the useful part of the error.
      writeRaw(
        '[2026-09-12T09:00:00.000] [APP] [ERROR] Import failed | error: '
        'FormatException: bad row\nrow 42: "12/31/2026"\n',
      );

      final report = await buildDiagnosticsReport(
        service,
        verboseLogging: false,
        environment: _environment,
      );

      expect(report, contains('row 42: "12/31/2026"'));
    });

    test('says so when there is no log yet', () async {
      final report = await buildDiagnosticsReport(
        service,
        verboseLogging: false,
        environment: _environment,
      );

      expect(report, contains('(no log entries recorded)'));
    });

    test('survives malformed UTF-8 in the log file', () async {
      File(
        service.logFilePath,
      ).writeAsBytesSync([...'ok line\n'.codeUnits, 0xC3, 0x28, 0x0A]);

      final report = await buildDiagnosticsReport(
        service,
        verboseLogging: false,
        environment: _environment,
      );

      expect(report, contains('ok line'));
    });

    test('redacts secrets left in lines written by older builds', () async {
      writeRaw(
        '[2026-09-12T09:00:00.000] [APP] [DEBUG] '
        'callback https://x.test/?access_token=legacy-secret\n',
      );

      final report = await buildDiagnosticsReport(
        service,
        verboseLogging: false,
        environment: _environment,
      );

      expect(report, isNot(contains('legacy-secret')));
    });
  });

  test('canOpenLogFolder is offered on desktop hosts only', () {
    expect(
      canOpenLogFolder,
      Platform.isMacOS || Platform.isWindows || Platform.isLinux,
    );
    expect(canOpenLogFolder, isNot(Platform.isAndroid || Platform.isIOS));
  });

  group('openLogFolder', () {
    test('hands the log directory to the launcher', () async {
      final launched = <Uri>[];

      final ok = await openLogFolder(
        service,
        launcher: (uri) async {
          launched.add(uri);
          return true;
        },
      );

      expect(ok, isTrue);
      expect(launched, [Uri.directory(service.logDirectory)]);
    });

    test('reports a refused hand-off as a failure', () async {
      final ok = await openLogFolder(service, launcher: (_) async => false);

      expect(ok, isFalse);
    });

    test('reports a thrown hand-off as a failure', () async {
      final ok = await openLogFolder(
        service,
        launcher: (_) async => throw const FileSystemException('no handler'),
      );

      expect(ok, isFalse);
    });
  });
}
