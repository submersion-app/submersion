import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/domain/entities/dive_computer_connection.dart';
import 'package:submersion/features/dive_computer/presentation/providers/dive_computer_connection_providers.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_connections_card.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

final _computer = DiveComputer(
  id: 'dc',
  name: 'Ratio iX3M 2',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

DiveComputerConnection _connection(
  String id,
  DiveComputerConnectionKind kind, {
  String? detail,
  String? address,
}) => DiveComputerConnection(
  id: id,
  computerId: 'dc',
  kind: kind,
  detail: detail,
  firstUsedAt: DateTime(2026),
  lastUsedAt: DateTime.now().subtract(const Duration(days: 2)),
  address: address,
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    List<DiveComputerConnection> connections, {
    ThemeData? theme,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(
              child: DiveComputerConnectionsCard(computer: _computer),
            ),
          ),
        ),
        GoRoute(
          path: '/dive-computers/:id/download',
          builder: (context, state) => Scaffold(
            body: Text(
              'download ${state.pathParameters['id']} via '
              '${state.uri.queryParameters['connection']}',
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          diveComputerConnectionsProvider(
            'dc',
          ).overrideWith((ref) async => connections),
        ],
        child: MaterialApp.router(
          theme: theme,
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final ble = _connection(
    'ble',
    DiveComputerConnectionKind.ble,
    address: 'AA:BB',
  );
  final fit = _connection(
    'fit',
    DiveComputerConnectionKind.file,
    detail: 'fit',
  );

  testWidgets('lists each connection with when it was last used (#3106)', (
    tester,
  ) async {
    await pump(tester, [ble, fit]);

    expect(find.text('Connections'), findsOneWidget);
    expect(find.text('Bluetooth LE'), findsOneWidget);
    expect(find.text('Garmin FIT file'), findsOneWidget);
    expect(find.text('Last used 2 days ago'), findsNWidgets(2));
  });

  testWidgets('a connection this device can reach is tagged and offers a '
      'download; a file import offers neither', (tester) async {
    await pump(tester, [ble, fit]);

    expect(find.text('This device'), findsOneWidget);
    expect(find.byTooltip('Download via Bluetooth LE'), findsOneWidget);
    expect(find.byTooltip('Download via Garmin FIT file'), findsNothing);
  });

  testWidgets('Download via opens the download route for that connection', (
    tester,
  ) async {
    await pump(tester, [ble, fit]);

    await tester.tap(find.byTooltip('Download via Bluetooth LE'));
    await tester.pumpAndSettle();

    expect(find.text('download dc via ble'), findsOneWidget);
  });

  testWidgets('says so when nothing is recorded yet', (tester) async {
    await pump(tester, const []);

    expect(find.text('No downloads or imports recorded yet'), findsOneWidget);
  });

  testWidgets('renders in the dark theme', (tester) async {
    await pump(tester, [ble], theme: ThemeData.dark());
    expect(find.text('Bluetooth LE'), findsOneWidget);
  });
}
