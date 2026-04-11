import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/logger_service.dart';

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

/// Share the full log file via system share sheet.
Future<void> shareLogFile(LogFileService service) async {
  final path = service.logFilePath;
  final file = File(path);
  if (!file.existsSync()) return;

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(path, mimeType: 'text/plain')],
      subject: 'Submersion Debug Logs',
    ),
  );
}

/// Copy the filtered log entries to clipboard.
Future<void> copyFilteredLogs(List<LogEntry> entries) async {
  final text = entries.map((e) => e.toLogLine()).join('\n');
  await Clipboard.setData(ClipboardData(text: text));
}

/// Save the full log file to a user-chosen location.
Future<String?> saveLogFile(LogFileService service) async {
  final path = service.logFilePath;
  final file = File(path);
  if (!file.existsSync()) return null;

  final bytes = await file.readAsBytes();
  final result = await FilePicker.saveFile(
    dialogTitle: 'Save Debug Logs',
    fileName: 'submersion-debug-logs.txt',
    type: FileType.custom,
    allowedExtensions: ['txt', 'log'],
    bytes: bytes,
  );

  if (result == null) return null;

  // On some platforms, saveFile returns a path but doesn't write
  if (!Platform.isAndroid) {
    final outFile = File(result);
    await outFile.writeAsBytes(bytes);
  }

  return result;
}
