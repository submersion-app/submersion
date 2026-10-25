import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_controls.dart';
import 'package:submersion/features/dive_computer/presentation/pages/device_list_page.dart';
import 'package:submersion/features/dive_computer/presentation/providers/dive_computer_connection_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_connections_card.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_merge_sheet.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_merge_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/computer_items_override.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Issue #3106: the list icon, the merge sheet and the detail page read a
/// computer's connections.
DiveComputer _computer(String id, {String? connectionType}) => DiveComputer(
  id: id,
  diverId: 'diver-1',
  name: id,
  manufacturer: 'Shearwater',
  model: 'Perdix 2',
  serialNumber: 'A1B2C3D4',
  connectionType: connectionType,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

DiveComputerConnection _connection(
  String computerId,
  DiveComputerConnectionKind kind, {
  String? detail,
}) => DiveComputerConnection(
  id: '$computerId-${kind.name}',
  computerId: computerId,
  kind: kind,
  detail: detail,
  firstUsedAt: DateTime(2026),
  lastUsedAt: DateTime(2026, 2),
);

class _FakeMergeRepository implements DiveComputerMergeRepository {
  @override
  Future<int> countAffectedDives({
    required String survivorId,
    required List<String> duplicateIds,
  }) async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  final file = _computer('file');
  final ble = _computer('ble', connectionType: 'bluetooth');
  final connections = {
    'file': [
      _connection(
        'file',
        DiveComputerConnectionKind.file,
        detail: 'shearwaterDb',
      ),
    ],
    'ble': [_connection('ble', DiveComputerConnectionKind.ble)],
  };

  List<dynamic> overrides() => [
    computerItemsFromComputers,
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    allDiveComputersProvider.overrideWith((ref) async => [file, ble]),
    allDiveComputerConnectionsProvider.overrideWith((ref) async => connections),
    for (final c in [file, ble]) ...[
      diveComputerByIdProvider(c.id).overrideWith((ref) async => c),
      diveComputerConnectionsProvider(
        c.id,
      ).overrideWith((ref) async => connections[c.id]!),
    ],
    diveComputerMergeRepositoryProvider.overrideWithValue(
      _FakeMergeRepository(),
    ),
  ];

  testWidgets('the list shows a file-only computer with the file icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: overrides(),
        child: const DeviceListPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    expect(find.byIcon(Icons.bluetooth), findsOneWidget);
    expect(find.byIcon(Icons.watch), findsNothing);
  });

  testWidgets('the merge sheet names each record\'s connections', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: overrides(),
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const ValueKey('open'),
            onPressed: () => DiveComputerMergeSheet.show(context, [file, ble]),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Shearwater Cloud file'), findsOneWidget);
    expect(find.textContaining('Bluetooth LE'), findsOneWidget);
  });

  testWidgets('the detail page shows the Connections card instead of a '
      'single Connection row', (tester) async {
    final router = GoRouter(
      initialLocation: '/dive-computers/ble',
      routes: [
        GoRoute(
          path: '/dive-computers/:id',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(
              child: DiveComputerControls(
                computerId: state.pathParameters['id']!,
              ),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides().cast(),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DiveComputerConnectionsCard), findsOneWidget);
    expect(find.text('Connections'), findsOneWidget);
    expect(find.text('Connection'), findsNothing);
  });
}
