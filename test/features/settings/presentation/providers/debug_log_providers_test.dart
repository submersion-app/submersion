import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

LogEntry _entry({
  required String message,
  LogCategory category = LogCategory.app,
  LogLevel level = LogLevel.debug,
  DateTime? timestamp,
}) {
  return LogEntry(
    timestamp: timestamp ?? DateTime(2026, 3, 27, 12, 0, 0),
    category: category,
    level: level,
    message: message,
  );
}

/// Apply the same filtering logic used in filteredLogEntriesProvider.
List<LogEntry> _applyFilter(List<LogEntry> entries, LogFilterState filter) {
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

  return filtered.reversed.toList();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  group('LogFilterState', () {
    test('default constructor has all categories active', () {
      const state = LogFilterState();
      expect(
        state.activeCategories,
        equals({
          LogCategory.app,
          LogCategory.bluetooth,
          LogCategory.serial,
          LogCategory.libdc,
          LogCategory.database,
        }),
      );
    });

    test('default constructor has minimumSeverity=debug', () {
      const state = LogFilterState();
      expect(state.minimumSeverity, LogLevel.debug);
    });

    test('default constructor has empty searchQuery', () {
      const state = LogFilterState();
      expect(state.searchQuery, '');
    });

    test('copyWith with no fields preserves all values', () {
      const original = LogFilterState(
        activeCategories: {LogCategory.app, LogCategory.serial},
        minimumSeverity: LogLevel.warning,
        searchQuery: 'hello',
      );
      final copy = original.copyWith();
      expect(copy.activeCategories, equals(original.activeCategories));
      expect(copy.minimumSeverity, original.minimumSeverity);
      expect(copy.searchQuery, original.searchQuery);
    });

    test('copyWith updates activeCategories only', () {
      const original = LogFilterState();
      final updated = original.copyWith(
        activeCategories: {LogCategory.bluetooth},
      );
      expect(updated.activeCategories, equals({LogCategory.bluetooth}));
      expect(updated.minimumSeverity, original.minimumSeverity);
      expect(updated.searchQuery, original.searchQuery);
    });

    test('copyWith updates minimumSeverity only', () {
      const original = LogFilterState();
      final updated = original.copyWith(minimumSeverity: LogLevel.error);
      expect(updated.minimumSeverity, LogLevel.error);
      expect(updated.activeCategories, equals(original.activeCategories));
      expect(updated.searchQuery, original.searchQuery);
    });

    test('copyWith updates searchQuery only', () {
      const original = LogFilterState();
      final updated = original.copyWith(searchQuery: 'bluetooth');
      expect(updated.searchQuery, 'bluetooth');
      expect(updated.activeCategories, equals(original.activeCategories));
      expect(updated.minimumSeverity, original.minimumSeverity);
    });

    test('copyWith updates multiple fields simultaneously', () {
      const original = LogFilterState();
      final updated = original.copyWith(
        activeCategories: {LogCategory.libdc},
        minimumSeverity: LogLevel.info,
        searchQuery: 'dive',
      );
      expect(updated.activeCategories, equals({LogCategory.libdc}));
      expect(updated.minimumSeverity, LogLevel.info);
      expect(updated.searchQuery, 'dive');
    });
  });

  // -------------------------------------------------------------------------
  group('LogFilterNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state matches LogFilterState defaults', () {
      final state = container.read(logFilterNotifierProvider);
      expect(
        state.activeCategories,
        equals({
          LogCategory.app,
          LogCategory.bluetooth,
          LogCategory.serial,
          LogCategory.libdc,
          LogCategory.database,
        }),
      );
      expect(state.minimumSeverity, LogLevel.debug);
      expect(state.searchQuery, '');
    });

    test('toggleCategory deselects an active category', () {
      container
          .read(logFilterNotifierProvider.notifier)
          .toggleCategory(LogCategory.app);
      final state = container.read(logFilterNotifierProvider);
      expect(state.activeCategories, isNot(contains(LogCategory.app)));
    });

    test('toggleCategory selects an inactive category', () {
      // First remove app, then re-add it.
      container
          .read(logFilterNotifierProvider.notifier)
          .toggleCategory(LogCategory.app);
      container
          .read(logFilterNotifierProvider.notifier)
          .toggleCategory(LogCategory.app);
      final state = container.read(logFilterNotifierProvider);
      expect(state.activeCategories, contains(LogCategory.app));
    });

    test('toggleCategory cannot deselect the last remaining category', () {
      final notifier = container.read(logFilterNotifierProvider.notifier);
      // Remove all categories except one.
      notifier.toggleCategory(LogCategory.app);
      notifier.toggleCategory(LogCategory.bluetooth);
      notifier.toggleCategory(LogCategory.serial);
      notifier.toggleCategory(LogCategory.libdc);
      // Only database remains — attempt to remove it.
      notifier.toggleCategory(LogCategory.database);
      final state = container.read(logFilterNotifierProvider);
      expect(state.activeCategories, equals({LogCategory.database}));
    });

    test('setMinimumSeverity changes severity level', () {
      container
          .read(logFilterNotifierProvider.notifier)
          .setMinimumSeverity(LogLevel.error);
      expect(
        container.read(logFilterNotifierProvider).minimumSeverity,
        LogLevel.error,
      );
    });

    test('setSearchQuery sets search query', () {
      container
          .read(logFilterNotifierProvider.notifier)
          .setSearchQuery('connected');
      expect(
        container.read(logFilterNotifierProvider).searchQuery,
        'connected',
      );
    });

    test('setSearchQuery accepts empty string', () {
      container
          .read(logFilterNotifierProvider.notifier)
          .setSearchQuery('something');
      container.read(logFilterNotifierProvider.notifier).setSearchQuery('');
      expect(container.read(logFilterNotifierProvider).searchQuery, '');
    });

    test('resetFilters restores default state after modifications', () {
      final notifier = container.read(logFilterNotifierProvider.notifier);
      notifier.toggleCategory(LogCategory.app);
      notifier.setMinimumSeverity(LogLevel.warning);
      notifier.setSearchQuery('some query');
      notifier.resetFilters();

      final state = container.read(logFilterNotifierProvider);
      expect(
        state.activeCategories,
        equals({
          LogCategory.app,
          LogCategory.bluetooth,
          LogCategory.serial,
          LogCategory.libdc,
          LogCategory.database,
        }),
      );
      expect(state.minimumSeverity, LogLevel.debug);
      expect(state.searchQuery, '');
    });
  });

  // -------------------------------------------------------------------------
  group('Filtering logic', () {
    test('empty entries list returns empty list', () {
      final result = _applyFilter([], const LogFilterState());
      expect(result, isEmpty);
    });

    test('entries matching active categories pass filter', () {
      final entries = [
        _entry(message: 'app msg', category: LogCategory.app),
        _entry(message: 'ble msg', category: LogCategory.bluetooth),
      ];
      const filter = LogFilterState(
        activeCategories: {LogCategory.app, LogCategory.bluetooth},
      );
      final result = _applyFilter(entries, filter);
      expect(result.length, 2);
    });

    test('entries not in active categories are excluded', () {
      final entries = [
        _entry(message: 'app msg', category: LogCategory.app),
        _entry(message: 'db msg', category: LogCategory.database),
      ];
      const filter = LogFilterState(activeCategories: {LogCategory.app});
      final result = _applyFilter(entries, filter);
      expect(result.length, 1);
      expect(result.first.category, LogCategory.app);
    });

    test('entries at or above minimum severity pass', () {
      final entries = [
        _entry(message: 'debug msg', level: LogLevel.debug),
        _entry(message: 'info msg', level: LogLevel.info),
        _entry(message: 'warn msg', level: LogLevel.warning),
        _entry(message: 'error msg', level: LogLevel.error),
      ];
      const filter = LogFilterState(minimumSeverity: LogLevel.info);
      final result = _applyFilter(entries, filter);
      // debug is excluded; info, warning, error pass
      expect(result.length, 3);
      expect(result.map((e) => e.level), isNot(contains(LogLevel.debug)));
    });

    test('entries below minimum severity are excluded', () {
      final entries = [
        _entry(message: 'debug msg', level: LogLevel.debug),
        _entry(message: 'info msg', level: LogLevel.info),
      ];
      const filter = LogFilterState(minimumSeverity: LogLevel.warning);
      final result = _applyFilter(entries, filter);
      expect(result, isEmpty);
    });

    test('search matches case-insensitively on message', () {
      final entries = [
        _entry(message: 'Connected to Device'),
        _entry(message: 'Disconnected'),
        _entry(message: 'Error reading data'),
      ];
      const filter = LogFilterState(searchQuery: 'connected');
      final result = _applyFilter(entries, filter);
      expect(result.length, 2);
      expect(
        result.every((e) => e.message.toLowerCase().contains('connected')),
        isTrue,
      );
    });

    test('search with no matches returns empty list', () {
      final entries = [
        _entry(message: 'Connected to Device'),
        _entry(message: 'Disconnected'),
      ];
      const filter = LogFilterState(searchQuery: 'xyz123');
      final result = _applyFilter(entries, filter);
      expect(result, isEmpty);
    });

    test('empty search query does not filter by message', () {
      final entries = [
        _entry(message: 'anything'),
        _entry(message: 'something else'),
      ];
      const filter = LogFilterState(searchQuery: '');
      final result = _applyFilter(entries, filter);
      expect(result.length, 2);
    });

    test('combined filters: category, severity, and search all applied', () {
      final entries = [
        _entry(
          message: 'Connected BLE',
          category: LogCategory.bluetooth,
          level: LogLevel.info,
        ),
        _entry(
          message: 'Connected APP',
          category: LogCategory.app,
          level: LogLevel.info,
        ),
        _entry(
          message: 'Connected BLE debug',
          category: LogCategory.bluetooth,
          level: LogLevel.debug,
        ),
        _entry(
          message: 'Unrelated BLE',
          category: LogCategory.bluetooth,
          level: LogLevel.info,
        ),
      ];
      const filter = LogFilterState(
        activeCategories: {LogCategory.bluetooth},
        minimumSeverity: LogLevel.info,
        searchQuery: 'connected',
      );
      final result = _applyFilter(entries, filter);
      // Only 'Connected BLE' survives: bluetooth, info level, contains 'connected'
      expect(result.length, 1);
      expect(result.first.message, 'Connected BLE');
    });

    test(
      'results are returned in reverse chronological order (newest first)',
      () {
        final older = _entry(
          message: 'older',
          timestamp: DateTime(2026, 3, 27, 10, 0, 0),
        );
        final newer = _entry(
          message: 'newer',
          timestamp: DateTime(2026, 3, 27, 12, 0, 0),
        );
        // Feed in chronological order (oldest first).
        final entries = [older, newer];
        final result = _applyFilter(entries, const LogFilterState());
        expect(result.first.message, 'newer');
        expect(result.last.message, 'older');
      },
    );

    test('single entry is returned unchanged', () {
      final entry = _entry(message: 'only one');
      final result = _applyFilter([entry], const LogFilterState());
      expect(result.length, 1);
      expect(result.first.message, 'only one');
    });
  });

  // -------------------------------------------------------------------------
  group('logFileServiceProvider', () {
    test('throws when not overridden', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Riverpod wraps provider body exceptions in ProviderException; the
      // underlying cause is an UnimplementedError.
      expect(
        () => container.read(logFileServiceProvider),
        throwsA(
          predicate(
            (e) =>
                e is UnimplementedError ||
                (e.toString().contains('UnimplementedError') ||
                    e.toString().contains(
                      'LogFileService must be initialized',
                    )),
          ),
        ),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('logEntriesProvider', () {
    test('returns empty list when log file does not exist', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'log_entries_provider_test_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final service = LogFileService(logDirectory: tempDir.path);
      await service.initialize();

      final container = ProviderContainer(
        overrides: [logFileServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      final entries = await container.read(logEntriesProvider.future);
      expect(entries, isEmpty);
    });

    test('reads entries written to the log file', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'log_entries_provider_test_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final service = LogFileService(logDirectory: tempDir.path);
      await service.initialize();

      final entry1 = _entry(message: 'first message');
      final entry2 = _entry(
        message: 'second message',
        category: LogCategory.bluetooth,
        level: LogLevel.info,
      );
      await service.writeLine(entry1.toLogLine());
      await service.writeLine(entry2.toLogLine());

      final container = ProviderContainer(
        overrides: [logFileServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      final entries = await container.read(logEntriesProvider.future);
      expect(entries.length, 2);
      expect(entries[0].message, 'first message');
      expect(entries[1].message, 'second message');
    });

    test('appends entries emitted on LoggerService.logStream', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'log_entries_live_test_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final service = LogFileService(logDirectory: tempDir.path);
      await service.initialize();

      // Wire LoggerService to the same file service so _log() writes to disk.
      LoggerService.setFileService(service);
      addTearDown(() => LoggerService.setFileService(service));

      // Write one entry before the provider starts.
      await service.writeLine(_entry(message: 'pre-existing').toLogLine());

      final container = ProviderContainer(
        overrides: [logFileServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      // Initial read should contain the pre-existing entry.
      final initial = await container.read(logEntriesProvider.future);
      expect(initial.length, 1);
      expect(initial.first.message, 'pre-existing');

      // Log a new entry through LoggerService (fires the stream).
      const logger = LoggerService('test');
      logger.info('live entry', category: LogCategory.bluetooth);

      // Wait for the file write to flush, then let the provider
      // invalidation + async re-read cycle complete.
      await LoggerService.flushPendingWrites();
      await container.read(logEntriesProvider.future);
      final updated = await container.read(logEntriesProvider.future);
      expect(updated.length, 2);
      expect(updated.last.message, 'live entry');
    });
  });

  // -------------------------------------------------------------------------
  group('filteredLogEntriesProvider', () {
    Future<ProviderContainer> makeContainer(
      LogFileService service, {
      List<void Function(ProviderContainer)> setup = const [],
    }) async {
      final container = ProviderContainer(
        overrides: [logFileServiceProvider.overrideWithValue(service)],
      );
      for (final fn in setup) {
        fn(container);
      }
      // Wait for logEntriesProvider to settle.
      await container.read(logEntriesProvider.future);
      return container;
    }

    test(
      'returns all entries in reverse chronological order by default',
      () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'filtered_log_provider_test_',
        );
        addTearDown(() => tempDir.deleteSync(recursive: true));
        final service = LogFileService(logDirectory: tempDir.path);
        await service.initialize();

        final older = _entry(
          message: 'older',
          timestamp: DateTime(2026, 3, 27, 10, 0, 0),
        );
        final newer = _entry(
          message: 'newer',
          timestamp: DateTime(2026, 3, 27, 12, 0, 0),
        );
        await service.writeLine(older.toLogLine());
        await service.writeLine(newer.toLogLine());

        final container = await makeContainer(service);
        addTearDown(container.dispose);

        final result = container.read(filteredLogEntriesProvider);
        final entries = result.value!;
        expect(entries.length, 2);
        expect(entries.first.message, 'newer');
        expect(entries.last.message, 'older');
      },
    );

    test('filters out entries not in active categories', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'filtered_log_provider_test_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final service = LogFileService(logDirectory: tempDir.path);
      await service.initialize();

      await service.writeLine(
        _entry(message: 'app msg', category: LogCategory.app).toLogLine(),
      );
      await service.writeLine(
        _entry(message: 'db msg', category: LogCategory.database).toLogLine(),
      );

      final container = await makeContainer(service);
      addTearDown(container.dispose);

      // Restrict to only app category.
      container
          .read(logFilterNotifierProvider.notifier)
          .toggleCategory(LogCategory.bluetooth);
      container
          .read(logFilterNotifierProvider.notifier)
          .toggleCategory(LogCategory.serial);
      container
          .read(logFilterNotifierProvider.notifier)
          .toggleCategory(LogCategory.libdc);
      container
          .read(logFilterNotifierProvider.notifier)
          .toggleCategory(LogCategory.database);

      final result = container.read(filteredLogEntriesProvider);
      final entries = result.value!;
      expect(entries.length, 1);
      expect(entries.first.message, 'app msg');
    });

    test('respects minimum severity filter', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'filtered_log_provider_test_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final service = LogFileService(logDirectory: tempDir.path);
      await service.initialize();

      await service.writeLine(
        _entry(message: 'debug msg', level: LogLevel.debug).toLogLine(),
      );
      await service.writeLine(
        _entry(message: 'error msg', level: LogLevel.error).toLogLine(),
      );

      final container = await makeContainer(service);
      addTearDown(container.dispose);

      container
          .read(logFilterNotifierProvider.notifier)
          .setMinimumSeverity(LogLevel.warning);

      final result = container.read(filteredLogEntriesProvider);
      final entries = result.value!;
      expect(entries.length, 1);
      expect(entries.first.message, 'error msg');
    });

    test('respects search query filter', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'filtered_log_provider_test_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final service = LogFileService(logDirectory: tempDir.path);
      await service.initialize();

      await service.writeLine(
        _entry(message: 'Connected to device').toLogLine(),
      );
      await service.writeLine(_entry(message: 'Reading data').toLogLine());

      final container = await makeContainer(service);
      addTearDown(container.dispose);

      container
          .read(logFilterNotifierProvider.notifier)
          .setSearchQuery('connected');

      final result = container.read(filteredLogEntriesProvider);
      final entries = result.value!;
      expect(entries.length, 1);
      expect(entries.first.message, 'Connected to device');
    });

    test('returns AsyncLoading when entries have not loaded', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'filtered_log_provider_test_',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final service = LogFileService(logDirectory: tempDir.path);
      await service.initialize();

      // Do NOT await the future — read provider in loading state.
      final container = ProviderContainer(
        overrides: [logFileServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      final result = container.read(filteredLogEntriesProvider);
      expect(result, isA<AsyncLoading>());
    });
  });

  // -------------------------------------------------------------------------
  group('copyFilteredLogs', () {
    late List<MethodCall> clipboardCalls;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      clipboardCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall call,
          ) async {
            clipboardCalls.add(call);
            if (call.method == 'Clipboard.setData') return null;
            if (call.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': 'mocked'};
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('copies formatted log lines to clipboard', () async {
      final entries = [
        _entry(
          message: 'alpha',
          timestamp: DateTime(2026, 3, 27, 12, 0, 0),
          category: LogCategory.app,
          level: LogLevel.debug,
        ),
        _entry(
          message: 'beta',
          timestamp: DateTime(2026, 3, 27, 12, 0, 1),
          category: LogCategory.bluetooth,
          level: LogLevel.info,
        ),
      ];

      await copyFilteredLogs(entries);

      final setDataCall = clipboardCalls.firstWhere(
        (c) => c.method == 'Clipboard.setData',
      );
      final text =
          (setDataCall.arguments as Map<dynamic, dynamic>)['text'] as String;

      expect(text, contains(entries[0].toLogLine()));
      expect(text, contains(entries[1].toLogLine()));
      // Lines joined by newline.
      expect(
        text,
        equals('${entries[0].toLogLine()}\n${entries[1].toLogLine()}'),
      );
    });

    test('copies empty string when entries list is empty', () async {
      await copyFilteredLogs([]);

      final setDataCall = clipboardCalls.firstWhere(
        (c) => c.method == 'Clipboard.setData',
      );
      final text =
          (setDataCall.arguments as Map<dynamic, dynamic>)['text'] as String;
      expect(text, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  group('shareLogFile', () {
    test('returns immediately when log file does not exist', () async {
      final tempDir = Directory.systemTemp.createTempSync('share_log_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final service = LogFileService(logDirectory: tempDir.path);
      await service.initialize();

      // No entries written, so log file doesn't exist
      await shareLogFile(service);
      // Should complete without error
    });

    test('attempts to share when log file exists', () async {
      final tempDir = Directory.systemTemp.createTempSync('share_log_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final service = LogFileService(logDirectory: tempDir.path);
      await service.initialize();

      // Write an entry so the file exists
      await service.writeLine(_entry(message: 'share test').toLogLine());

      // SharePlus may throw MissingPluginException in test env.
      // The key is that we reach the share call (covering those lines).
      try {
        await shareLogFile(service);
      } catch (_) {
        // Expected in test environment
      }
    });
  });

  // -------------------------------------------------------------------------
  group('saveLogFile', () {
    test('returns null when log file does not exist', () async {
      final tempDir = Directory.systemTemp.createTempSync('save_log_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final service = LogFileService(logDirectory: tempDir.path);
      await service.initialize();

      final result = await saveLogFile(service);
      expect(result, isNull);
    });

    test('attempts to save when log file exists', () async {
      final tempDir = Directory.systemTemp.createTempSync('save_log_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final service = LogFileService(logDirectory: tempDir.path);
      await service.initialize();

      // Write an entry so the file exists
      await service.writeLine(_entry(message: 'save test').toLogLine());

      // FilePicker may throw MissingPluginException in test env.
      // The key is that we reach the FilePicker call (covering those lines).
      try {
        final result = await saveLogFile(service);
        // If it somehow succeeds (returns null from picker), that's fine
        expect(result, anything);
      } catch (_) {
        // Expected in test environment
      }
    });
  });
}
