import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/pages/device_detail_page.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DiveComputer _makeComputer({
  String id = 'comp-1',
  String name = 'My Perdix',
  String? manufacturer = 'Shearwater',
  String? model = 'Perdix 2',
  String? serialNumber = 'SN-12345',
  String? connectionType = 'ble',
  bool isFavorite = false,
  String notes = '',
  int diveCount = 42,
}) {
  final now = DateTime(2026, 1, 1);
  return DiveComputer(
    id: id,
    name: name,
    manufacturer: manufacturer,
    model: model,
    serialNumber: serialNumber,
    connectionType: connectionType,
    isFavorite: isFavorite,
    notes: notes,
    diveCount: diveCount,
    createdAt: now,
    updatedAt: now,
  );
}

const _emptyStats = DiveComputerStats(diveCount: 0);

DiveComputerStats _makeStats({
  int diveCount = 10,
  double? deepestDive = 40.5,
  int? longestDuration = 3600,
  double? avgDepth = 22.3,
  int? totalBottomTime = 36000,
  double? coldestTemp = 12.0,
  double? warmestTemp = 28.5,
  DateTime? firstDive,
  DateTime? lastDive,
}) {
  return DiveComputerStats(
    diveCount: diveCount,
    deepestDive: deepestDive,
    longestDuration: longestDuration,
    avgDepth: avgDepth,
    totalBottomTime: totalBottomTime,
    coldestTemp: coldestTemp,
    warmestTemp: warmestTemp,
    firstDive: firstDive ?? DateTime(2024, 1, 15),
    lastDive: lastDive ?? DateTime(2026, 3, 20),
  );
}

/// Build a routed test widget with the DeviceDetailPage.
Widget _buildTestWidget({
  required DiveComputer? computer,
  DiveComputerStats? stats,
  bool isLoading = false,
  Object? error,
  List<dynamic>? extraOverrides,
}) {
  final computerId = computer?.id ?? 'comp-1';

  final router = GoRouter(
    initialLocation: '/dive-computers/$computerId',
    routes: [
      GoRoute(
        path: '/dives',
        builder: (context, state) =>
            const Scaffold(body: Text('DIVES_LIST_PAGE')),
      ),
      GoRoute(
        path: '/dive-computers/:id',
        builder: (context, state) =>
            DeviceDetailPage(computerId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'download',
            builder: (context, state) =>
                const Scaffold(body: Text('DOWNLOAD_PAGE')),
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      if (isLoading)
        diveComputerByIdProvider(computerId).overrideWith(
          (ref) => Future<DiveComputer?>.delayed(
            const Duration(seconds: 60),
            () => computer,
          ),
        )
      else if (error != null)
        diveComputerByIdProvider(
          computerId,
        ).overrideWith((ref) => Future<DiveComputer?>.error(error))
      else
        diveComputerByIdProvider(
          computerId,
        ).overrideWith((ref) async => computer),
      computerStatsProvider(
        computerId,
      ).overrideWith((ref) async => stats ?? _emptyStats),
      ...?extraOverrides?.cast(),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  group('DeviceDetailPage - loading state', () {
    testWidgets('shows CircularProgressIndicator while loading', (
      tester,
    ) async {
      final completer = Completer<DiveComputer?>();
      const computerId = 'comp-1';

      final router = GoRouter(
        initialLocation: '/dive-computers/$computerId',
        routes: [
          GoRoute(
            path: '/dive-computers/:id',
            builder: (context, state) =>
                DeviceDetailPage(computerId: state.pathParameters['id']!),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            diveComputerByIdProvider(
              computerId,
            ).overrideWith((ref) => completer.future),
            computerStatsProvider(
              computerId,
            ).overrideWith((ref) async => _emptyStats),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future to avoid pending timer errors
      completer.complete(_makeComputer());
      await tester.pumpAndSettle();
    });
  });

  group('DeviceDetailPage - error state', () {
    testWidgets('shows error text when provider errors', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(computer: null, error: 'Something broke'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Something broke'), findsOneWidget);
    });
  });

  group('DeviceDetailPage - null computer (not found)', () {
    testWidgets('shows not-found text when computer is null', (tester) async {
      await tester.pumpWidget(_buildTestWidget(computer: null));
      await tester.pumpAndSettle();

      expect(find.text('Dive Computer'), findsOneWidget);
      expect(find.text('Device not found'), findsOneWidget);
    });
  });

  group('DeviceDetailPage - renders content', () {
    testWidgets('shows computer display name in AppBar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer();
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      // AppBar shows displayName (which is name when non-empty).
      // The name also appears in the info row, so we check the AppBar directly.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('My Perdix'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows full name in info card', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer();
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      // Full name = "Shearwater Perdix 2"
      expect(find.text('Shearwater Perdix 2'), findsOneWidget);
    });

    testWidgets('shows info rows for name, manufacturer, model, serial', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer(serialNumber: 'SN-99');
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('My Perdix'), findsWidgets);
      expect(find.text('Manufacturer'), findsOneWidget);
      expect(find.text('Shearwater'), findsOneWidget);
      expect(find.text('Model'), findsOneWidget);
      expect(find.text('Perdix 2'), findsOneWidget);
      expect(find.text('Serial Number'), findsOneWidget);
      expect(find.text('SN-99'), findsOneWidget);
    });

    testWidgets('omits serial number row when null', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer(serialNumber: null);
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      expect(find.text('Serial Number'), findsNothing);
    });

    testWidgets('shows notes card when notes are present', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer(notes: 'Lost strap');
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Lost strap'), findsOneWidget);
    });

    testWidgets('hides notes card when notes are empty', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer(notes: '');
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      expect(find.text('Notes'), findsNothing);
    });

    testWidgets('shows download and view dives buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer();
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      expect(find.text('Download Dives'), findsOneWidget);
      expect(find.text('View Dives from This Computer'), findsOneWidget);
    });
  });

  group('DeviceDetailPage - connection icon/name mapping', () {
    for (final entry in <String, (IconData, String)>{
      'ble': (Icons.bluetooth, 'Bluetooth LE'),
      'bluetooth': (Icons.bluetooth, 'Bluetooth'),
      'bluetoothclassic': (Icons.bluetooth, 'Bluetooth'),
      'usb': (Icons.usb, 'USB'),
      'wifi': (Icons.wifi, 'Wi-Fi'),
      'infrared': (Icons.sensors, 'Infrared'),
    }.entries) {
      testWidgets('connectionType "${entry.key}" shows correct icon and name', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(500, 3000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final computer = _makeComputer(connectionType: entry.key);
        await tester.pumpWidget(_buildTestWidget(computer: computer));
        await tester.pumpAndSettle();

        // The connection name should appear in the Connection info row
        expect(find.text(entry.value.$2), findsOneWidget);
        // The icon should appear in the top icon container
        expect(find.byIcon(entry.value.$1), findsWidgets);
      });
    }

    testWidgets('null connectionType shows default watch icon and Unknown', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer(connectionType: null);
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      expect(find.text('Unknown'), findsOneWidget);
      expect(find.byIcon(Icons.watch), findsWidgets);
    });

    testWidgets(
      'unrecognized connectionType shows default watch icon and Unknown',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(500, 3000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final computer = _makeComputer(connectionType: 'quantum');
        await tester.pumpWidget(_buildTestWidget(computer: computer));
        await tester.pumpAndSettle();

        expect(find.text('Unknown'), findsOneWidget);
        expect(find.byIcon(Icons.watch), findsWidgets);
      },
    );
  });

  group('DeviceDetailPage - favorite button', () {
    testWidgets('shows star_outline button when not favorite', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer(isFavorite: false);
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_outline), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('shows filled star when favorite', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer(isFavorite: true);
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.star_outline), findsNothing);
    });
  });

  group('DeviceDetailPage - popup menu', () {
    testWidgets('edit and delete menu items are present', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer();
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('tapping Edit opens edit dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer();
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      // Open popup menu then tap Edit
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      // Edit dialog should show with name and notes fields
      expect(find.text('Edit Computer'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      // Name field should be pre-filled
      expect(find.widgetWithText(TextField, 'My Perdix'), findsOneWidget);
    });

    testWidgets('tapping Cancel in edit dialog closes it', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer();
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.text('Edit Computer'), findsNothing);
    });

    testWidgets('tapping Delete opens delete confirmation dialog', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer();
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Computer?'), findsOneWidget);
      expect(
        find.textContaining('Are you sure you want to remove'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      // Delete button in dialog
      expect(find.widgetWithText(FilledButton, 'Delete'), findsOneWidget);
    });

    testWidgets('Cancel in delete dialog closes it', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer();
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Computer?'), findsNothing);
    });
  });

  group('DeviceDetailPage - statistics', () {
    testWidgets('shows dive count and last download in stats card', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer(diveCount: 42);
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      expect(find.text('Statistics'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Dives Imported'), findsOneWidget);
      expect(find.text('Last Download'), findsOneWidget);
    });

    testWidgets('shows detailed stats when hasStats is true', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer();
      final stats = _makeStats();
      await tester.pumpWidget(
        _buildTestWidget(computer: computer, stats: stats),
      );
      await tester.pumpAndSettle();

      // Deepest dive
      expect(find.text('40.5m'), findsOneWidget);
      expect(find.text('Deepest'), findsOneWidget);

      // Longest (3600 seconds = 1h 0m)
      expect(find.text('1h 0m'), findsOneWidget);
      expect(find.text('Longest'), findsOneWidget);

      // Avg depth
      expect(find.text('22.3m'), findsOneWidget);
      expect(find.text('Avg Depth'), findsOneWidget);

      // Total time
      expect(find.text('Total Time'), findsOneWidget);

      // Temperature
      expect(find.text('Coldest'), findsOneWidget);
      expect(find.text('Warmest'), findsOneWidget);

      // Date range
      expect(find.text('First Dive'), findsOneWidget);
      expect(find.text('Last Dive'), findsOneWidget);
    });

    testWidgets('hides detailed stats section when hasStats is false', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer();
      await tester.pumpWidget(
        _buildTestWidget(computer: computer, stats: _emptyStats),
      );
      await tester.pumpAndSettle();

      // Basic stats still shown
      expect(find.text('Statistics'), findsOneWidget);

      // But detailed stats hidden
      expect(find.text('Deepest'), findsNothing);
      expect(find.text('Longest'), findsNothing);
      expect(find.text('First Dive'), findsNothing);
    });

    testWidgets('shows -- for null depth/duration stats', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer();
      final stats = DiveComputerStats(
        diveCount: 5,
        deepestDive: null,
        longestDuration: null,
        avgDepth: null,
        totalBottomTime: null,
        coldestTemp: null,
        warmestTemp: null,
        firstDive: DateTime(2025, 1, 1),
        lastDive: DateTime(2025, 6, 1),
      );
      await tester.pumpWidget(
        _buildTestWidget(computer: computer, stats: stats),
      );
      await tester.pumpAndSettle();

      // Should show '--' for null values
      expect(find.text('--'), findsWidgets);
    });

    testWidgets('hides temperature row when both temps null', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer();
      final stats = _makeStats(coldestTemp: null, warmestTemp: null);
      await tester.pumpWidget(
        _buildTestWidget(computer: computer, stats: stats),
      );
      await tester.pumpAndSettle();

      expect(find.text('Coldest'), findsNothing);
      expect(find.text('Warmest'), findsNothing);
    });

    testWidgets('formats duration without hours as Xm', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer();
      // 2700 seconds = 45 minutes (no hours)
      final stats = _makeStats(longestDuration: 2700);
      await tester.pumpWidget(
        _buildTestWidget(computer: computer, stats: stats),
      );
      await tester.pumpAndSettle();

      expect(find.text('45m'), findsOneWidget);
    });
  });

  group('DeviceDetailPage - View Dives action', () {
    testWidgets('shows snackbar when serial number is null', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer(serialNumber: null);
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View Dives from This Computer'));
      await tester.pumpAndSettle();

      expect(
        find.text('Cannot filter: no serial number for this computer.'),
        findsOneWidget,
      );
    });

    testWidgets('shows snackbar when serial number is empty', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer(serialNumber: '');
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View Dives from This Computer'));
      await tester.pumpAndSettle();

      expect(
        find.text('Cannot filter: no serial number for this computer.'),
        findsOneWidget,
      );
    });
  });

  group('DeviceDetailPage - Download Dives action', () {
    testWidgets('navigates to download page on tap', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final computer = _makeComputer();
      await tester.pumpWidget(_buildTestWidget(computer: computer));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Download Dives'));
      await tester.pumpAndSettle();

      expect(find.text('DOWNLOAD_PAGE'), findsOneWidget);
    });
  });
}
