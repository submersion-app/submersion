import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:submersion/core/services/log_environment.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/log_redactor.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:url_launcher/url_launcher.dart';

const _logger = LoggerService('Diagnostics');

/// Most characters "Copy diagnostics" puts on the clipboard, header included.
///
/// GitHub rejects an issue body over 65,536 characters; this is as much of
/// the log as fits while leaving room for the diver's own description. The
/// budget is spent on the newest lines, so a report carries hundreds of
/// lines instead of a fixed short tail. Dart counts UTF-16 code units, and
/// the log is almost all ASCII, where every way of counting agrees.
const diagnosticsReportCharLimit = 60000;

/// Hands a folder to the platform's file manager; `launchUrl` in the app.
typedef FolderLauncher = Future<bool> Function(Uri uri);

/// True where a folder can be handed to a file manager. Mobile file managers
/// have no addressable folder to open (same rule as the startup backups
/// folder in `startup_page.dart`).
bool get canOpenLogFolder =>
    Platform.isMacOS || Platform.isWindows || Platform.isLinux;

/// Build the text "Copy diagnostics" puts on the clipboard: the build and
/// device header, whether verbose logging is on, then as many of the newest
/// log lines as fit within [maxChars] in total.
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
  int maxChars = diagnosticsReportCharLimit,
}) async {
  final resolved = environment ?? await LogEnvironment.capture();
  final header =
      '${resolved.toExportHeader()}'
      'verbose logging: ${verboseLogging ? 'on' : 'off'}\n';

  final lines = await _readLines(File(service.logFilePath));
  if (lines.isEmpty) return '$header(no log entries recorded)';
  return header + _newestThatFit(lines, maxChars - header.length);
}

Future<List<String>> _readLines(File file) async {
  if (!await file.exists()) return const [];
  final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
  return const LineSplitter()
      .convert(text)
      .where((line) => line.isNotEmpty)
      .toList();
}

/// The newest [lines], redacted, that fit in [budget] characters joined by
/// newlines.
///
/// Walks back from the end so only the lines kept are redacted, and measures
/// each after redaction since that is the text the clipboard receives. Every
/// redaction rule stops at a newline, so redacting line by line matches
/// redacting the joined text. A newest line longer than the whole budget is
/// cut to fit rather than leaving the report with no log at all.
String _newestThatFit(List<String> lines, int budget) {
  final kept = <String>[];
  var used = 0;
  for (var i = lines.length - 1; i >= 0; i--) {
    final line = redactSecrets(lines[i]);
    final cost = kept.isEmpty ? line.length : line.length + 1;
    if (used + cost > budget) {
      if (kept.isEmpty && budget > 0) kept.add(line.substring(0, budget));
      break;
    }
    kept.add(line);
    used += cost;
  }
  return kept.reversed.join('\n');
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
