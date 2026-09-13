import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:submersion/core/services/log_environment.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/log_redactor.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:url_launcher/url_launcher.dart';

const _logger = LoggerService('Diagnostics');

/// How many of the newest log lines "Copy diagnostics" carries.
///
/// Enough to cover the failure a report is about and what led up to it,
/// while keeping the text small enough to paste into a GitHub issue body.
const diagnosticsLogLineLimit = 200;

/// Hands a folder to the platform's file manager; `launchUrl` in the app.
typedef FolderLauncher = Future<bool> Function(Uri uri);

/// True where a folder can be handed to a file manager. Mobile file managers
/// have no addressable folder to open (same rule as the startup backups
/// folder in `startup_page.dart`).
bool get canOpenLogFolder =>
    Platform.isMacOS || Platform.isWindows || Platform.isLinux;

/// Build the text "Copy diagnostics" puts on the clipboard: the build and
/// device header, whether verbose logging is on, then the newest
/// [maxLines] lines of the log file.
///
/// Reads the raw file rather than parsed entries: a multi-line error spills
/// onto continuation lines the log viewer's parser drops, and those are
/// often the useful part. Decoded leniently so one malformed byte cannot
/// cost the whole report, and redacted again because lines written by older
/// builds predate the logger's own redaction.
Future<String> buildDiagnosticsReport(
  LogFileService service, {
  required bool verboseLogging,
  LogEnvironment? environment,
  int maxLines = diagnosticsLogLineLimit,
}) async {
  final resolved = environment ?? await LogEnvironment.capture();
  final buffer = StringBuffer()
    ..write(resolved.toExportHeader())
    ..writeln('verbose logging: ${verboseLogging ? 'on' : 'off'}');

  final lines = await _tailLines(File(service.logFilePath), maxLines);
  if (lines.isEmpty) {
    buffer.write('(no log entries recorded)');
  } else {
    buffer.write(redactSecrets(lines.join('\n')));
  }
  return buffer.toString();
}

Future<List<String>> _tailLines(File file, int maxLines) async {
  if (!file.existsSync()) return const [];
  final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
  final lines = const LineSplitter()
      .convert(text)
      .where((line) => line.isNotEmpty)
      .toList();
  return lines.length <= maxLines
      ? lines
      : lines.sublist(lines.length - maxLines);
}

/// Copy [buildDiagnosticsReport] to the clipboard.
Future<void> copyDiagnostics(
  LogFileService service, {
  required bool verboseLogging,
  LogEnvironment? environment,
}) async {
  final report = await buildDiagnosticsReport(
    service,
    verboseLogging: verboseLogging,
    environment: environment,
  );
  await Clipboard.setData(ClipboardData(text: report));
}

/// Open the folder holding the log file in the platform's file manager.
///
/// Returns false when the hand-off fails, so the caller can show the path
/// instead. `launchUrl` refuses by RETURNING false as often as by throwing
/// (no registered handler for a file:// directory), so both count.
Future<bool> openLogFolder(
  LogFileService service, {
  FolderLauncher? launcher,
}) async {
  final launch = launcher ?? launchUrl;
  try {
    final launched = await launch(Uri.directory(service.logDirectory));
    if (!launched) {
      _logger.warning('Could not open log folder: launcher returned false');
    }
    return launched;
  } catch (e) {
    _logger.warning('Could not open log folder', error: e);
    return false;
  }
}
