import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/pages/device_detail_page.dart';
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

class _MockDiveComputerNotifier
    extends StateNotifier<AsyncValue<List<DiveComputer>>>
    implements DiveComputerNotifier {
  _MockDiveComputerNotifier() : super(const AsyncValue.data(<DiveComputer>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Build a routed test widget with the DeviceDetailPage.
Widget _buildTestWidget({
  required DiveComputer? computer,
  bool isLoading = false,
  Object? error,
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
      diveComputerNotifierProvider.overrideWith(
        (ref) => _MockDiveComputerNotifier(),
      ),
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
            diveComputerNotifierProvider.overrideWith(
              (ref) => _MockDiveComputerNotifier(),
            ),
            diveComputerByIdProvider(
              computerId,
            ).overrideWith((ref) => completer.future),
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
    });
  });

  group('DeviceDetailPage - error state', () {
    testWidgets('shows error message when provider errors', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(computer: null, error: 'Something went wrong'),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Something went wrong'), findsOneWidget);
    });
  });

  group('DeviceDetailPage - null computer', () {
    testWidgets('shows not found text when computer is null', (tester) async {
      await tester.pumpWidget(_buildTestWidget(computer: null));
      await tester.pumpAndSettle();

      expect(find.textContaining('not found'), findsOneWidget);
    });
  });

  group('DeviceDetailPage - content rendering', () {
    testWidgets('shows app bar with display name', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(computer: _makeComputer(name: 'My Perdix')),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Perdix'), findsWidgets);
    });

    testWidgets('shows full name in info card', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          computer: _makeComputer(
            manufacturer: 'Shearwater',
            model: 'Perdix 2',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shearwater Perdix 2'), findsOneWidget);
    });

    testWidgets('shows info rows', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(computer: _makeComputer(serialNumber: 'SN-12345')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Manufacturer'), findsOneWidget);
      expect(find.text('Model'), findsOneWidget);
      expect(find.text('Serial Number'), findsOneWidget);
      expect(find.text('Connection'), findsOneWidget);
    });

    testWidgets('shows notes card when notes exist', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          computer: _makeComputer(notes: 'Test notes about this computer'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Test notes about this computer'), findsOneWidget);
    });

    testWidgets('hides notes card when notes are empty', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(computer: _makeComputer(notes: '')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notes'), findsNothing);
    });

    testWidgets('shows dive count in stats', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(computer: _makeComputer(diveCount: 42)),
      );
      await tester.pumpAndSettle();

      expect(find.text('42'), findsOneWidget);
      expect(find.text('Dives Imported'), findsOneWidget);
    });
  });

  group('DeviceDetailPage - connection icon mapping', () {
    for (final entry in {
      'ble': Icons.bluetooth,
      'bluetooth': Icons.bluetooth,
      'bluetoothclassic': Icons.bluetooth,
      'usb': Icons.usb,
      'wifi': Icons.wifi,
      'infrared': Icons.sensors,
    }.entries) {
      testWidgets('shows correct icon for ${entry.key}', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(computer: _makeComputer(connectionType: entry.key)),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(entry.value), findsWidgets);
      });
    }

    testWidgets('shows default icon for unknown connection', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(computer: _makeComputer(connectionType: 'unknown')),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.watch), findsWidgets);
    });

    testWidgets('shows default icon for null connection', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(computer: _makeComputer(connectionType: null)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.watch), findsWidgets);
    });
  });

  group('DeviceDetailPage - favorite button', () {
    testWidgets('shows star_outline when not favorite', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(computer: _makeComputer(isFavorite: false)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_outline), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('shows filled star when favorite', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(computer: _makeComputer(isFavorite: true)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.star_outline), findsNothing);
    });
  });

  group('DeviceDetailPage - popup menu', () {
    testWidgets('shows edit and delete menu items', (tester) async {
      await tester.pumpWidget(_buildTestWidget(computer: _makeComputer()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });

    testWidgets('edit opens dialog with pre-filled fields', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          computer: _makeComputer(name: 'My Perdix', notes: 'some notes'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      expect(find.text('Edit Computer'), findsOneWidget);
      expect(find.text('My Perdix'), findsWidgets);
      expect(find.text('some notes'), findsWidgets);
    });

    testWidgets('cancel closes edit dialog', (tester) async {
      await tester.pumpWidget(_buildTestWidget(computer: _makeComputer()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Computer'), findsNothing);
    });

    testWidgets('delete opens confirmation dialog', (tester) async {
      await tester.pumpWidget(_buildTestWidget(computer: _makeComputer()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();

      expect(find.text('Delete Computer?'), findsOneWidget);
    });

    testWidgets('cancel closes delete dialog', (tester) async {
      await tester.pumpWidget(_buildTestWidget(computer: _makeComputer()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Computer?'), findsNothing);
    });
  });

  group('DeviceDetailPage - actions', () {
    testWidgets('download button navigates to download page', (tester) async {
      await tester.pumpWidget(_buildTestWidget(computer: _makeComputer()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Download Dives'), 200);
      await tester.tap(find.text('Download Dives'));
      await tester.pumpAndSettle();

      expect(find.text('DOWNLOAD_PAGE'), findsOneWidget);
    });

    testWidgets('view dives shows snackbar for null serial', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(computer: _makeComputer(serialNumber: null)),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('View Dives from This Computer'),
        200,
      );
      await tester.tap(find.text('View Dives from This Computer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('no serial number'), findsOneWidget);
    });

    testWidgets('view dives shows snackbar for empty serial', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(computer: _makeComputer(serialNumber: '')),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('View Dives from This Computer'),
        200,
      );
      await tester.tap(find.text('View Dives from This Computer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('no serial number'), findsOneWidget);
    });

    testWidgets('view dives navigates when serial exists', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(computer: _makeComputer(serialNumber: 'SN-12345')),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('View Dives from This Computer'),
        200,
      );
      await tester.tap(find.text('View Dives from This Computer'));
      await tester.pumpAndSettle();

      expect(find.text('DIVES_LIST_PAGE'), findsOneWidget);
    });
  });
}
