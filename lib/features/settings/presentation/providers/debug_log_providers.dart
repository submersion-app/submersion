import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/log_environment.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Provider for the LogFileService singleton.
/// Must be overridden in ProviderScope with the initialized instance.
final logFileServiceProvider = Provider<LogFileService>((ref) {
  throw UnimplementedError('LogFileService must be initialized before use');
});

/// Provider that loads all log entries from the file.
/// Automatically re-reads when [LoggerService.logStream] emits, so the
/// debug log viewer updates in real time without a manual refresh.
final logEntriesProvider = FutureProvider<List<LogEntry>>((ref) async {
  final service = ref.watch(logFileServiceProvider);
  final entries = await service.readEntries();

  // After the initial read, listen for new log entries and trigger a
  // re-read.  Riverpod coalesces rapid invalidations into a single rebuild.
  final sub = LoggerService.logStream.listen((_) {
    ref.invalidateSelf();
  });
  ref.onDispose(sub.cancel);

  return entries;
});

/// Filter state for the log viewer.
class LogFilterState {
  final Set<LogCategory> activeCategories;
  final LogLevel minimumSeverity;
  final String searchQuery;

  const LogFilterState({
    this.activeCategories = const {
      LogCategory.app,
      LogCategory.bluetooth,
      LogCategory.serial,
      LogCategory.libdc,
      LogCategory.database,
    },
    this.minimumSeverity = LogLevel.debug,
    this.searchQuery = '',
  });

  LogFilterState copyWith({
    Set<LogCategory>? activeCategories,
    LogLevel? minimumSeverity,
    String? searchQuery,
  }) {
    return LogFilterState(
      activeCategories: activeCategories ?? this.activeCategories,
      minimumSeverity: minimumSeverity ?? this.minimumSeverity,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// Provider for log filter state.
final logFilterNotifierProvider =
    StateNotifierProvider<LogFilterNotifier, LogFilterState>((ref) {
      return LogFilterNotifier();
    });

class LogFilterNotifier extends StateNotifier<LogFilterState> {
  LogFilterNotifier() : super(const LogFilterState());

  void toggleCategory(LogCategory category) {
    final current = Set<LogCategory>.from(state.activeCategories);
    if (current.contains(category)) {
      // Don't allow deselecting all categories
      if (current.length > 1) {
        current.remove(category);
      }
    } else {
      current.add(category);
    }
    state = state.copyWith(activeCategories: current);
  }

  void setMinimumSeverity(LogLevel level) {
    state = state.copyWith(minimumSeverity: level);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void resetFilters() {
    state = const LogFilterState();
  }
}

/// Provider for the filtered list of log entries (reverse chronological).
final filteredLogEntriesProvider = Provider<AsyncValue<List<LogEntry>>>((ref) {
  final entriesAsync = ref.watch(logEntriesProvider);
  final filter = ref.watch(logFilterNotifierProvider);

  return entriesAsync.whenData((entries) {
    final filtered = entries.where((entry) {
      if (!filter.activeCategories.contains(entry.category)) return false;
      if (entry.level.index < filter.minimumSeverity.index) return false;
      if (filter.searchQuery.isNotEmpty &&
          !entry.message.toLowerCase().contains(
            filter.searchQuery.toLowerCase(),
          )) {
        return false;
      }
      return true;
    }).toList();

    // Reverse chronological order (newest first)
    return filtered.reversed.toList();
  });
});

/// Name the exported copy carries in the share sheet and the save dialog.
const _exportFileName = 'submersion-debug-logs.txt';

/// Resolve the header prepended to every export.
///
/// Callers may pass a captured [LogEnvironment]; otherwise it is read here.
/// Attaching the build and device to the logs is what turns a pasted excerpt
/// into something triageable (issue #1246).
Future<String> _exportHeader(LogEnvironment? environment) async {
  final resolved = environment ?? await LogEnvironment.capture();
  return resolved.toExportHeader();
}

/// The log file's bytes behind the export header.
///
/// Concatenated as BYTES rather than decoded to a string first: the log
/// carries whatever a device name or a native log message put in it, and
/// `readAsString` throws on a malformed UTF-8 sequence. Losing the whole
/// export to one bad byte is a worse outcome than passing it through.
Future<Uint8List> _exportBytes(File file, String header) async {
  return Uint8List.fromList([
    ...utf8.encode(header),
    ...await file.readAsBytes(),
  ]);
}

/// Share the full log file via system share sheet.
///
/// Shares a header-prefixed copy rather than the log file itself, so the
/// recipient sees which build and device produced the lines.
///
/// [sharePositionOrigin] anchors the iPad share popover; this function has no
/// [BuildContext] of its own, so the caller resolves it from the share button
/// (see `shareAnchorFrom`). Ignored on every other platform.
Future<void> shareLogFile(
  LogFileService service,
  AppLocalizations l10n, {
  LogEnvironment? environment,
  Rect? sharePositionOrigin,
}) async {
  final file = File(service.logFilePath);
  if (!file.existsSync()) return;

  final header = await _exportHeader(environment);

  // Written to the temp directory rather than shared in place: the log file
  // has to stay untouched (it is still being appended to), and the copy is
  // disposable once the share sheet has read it. Sharing a *copy* is also what
  // lets the export carry the header at all. Reusing one name bounds the temp
  // directory to a single file across repeated shares.
  final tempDir = await getTemporaryDirectory();
  final export = File('${tempDir.path}/$_exportFileName');
  await export.writeAsBytes(await _exportBytes(file, header));

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(export.path, mimeType: 'text/plain')],
      subject: l10n.settings_debugLog_shareSubject,
      sharePositionOrigin: sharePositionOrigin,
    ),
  );
}

/// Copy the filtered log entries to clipboard, behind the export header.
///
/// The header is unconditional, so even a one-line excerpt names the build it
/// came from. That is deliberately not special-cased for an empty list, but it
/// is also not reachable that way today: the Copy button in
/// [DebugLogViewerPage] guards on a non-empty list, so an empty filter result
/// copies nothing at all rather than a bare header.
Future<void> copyFilteredLogs(
  List<LogEntry> entries, {
  LogEnvironment? environment,
}) async {
  final header = await _exportHeader(environment);
  final text = entries.map((e) => e.toLogLine()).join('\n');
  await Clipboard.setData(ClipboardData(text: '$header$text'));
}

/// Save the full log file to a user-chosen location.
Future<String?> saveLogFile(
  LogFileService service,
  AppLocalizations l10n, {
  LogEnvironment? environment,
}) async {
  final file = File(service.logFilePath);
  if (!file.existsSync()) return null;

  final header = await _exportHeader(environment);
  final result = await FilePicker.saveFile(
    dialogTitle: l10n.settings_debugLog_saveDialogTitle,
    fileName: _exportFileName,
    type: FileType.custom,
    bytes: await _exportBytes(file, header),
    mimeType: 'text/plain',
  );

  if (result == null) return null;
  return savedFileLocation(result);
}
