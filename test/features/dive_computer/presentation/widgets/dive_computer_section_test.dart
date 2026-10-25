import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_connections_card.dart';
import 'package:submersion/features/dive_computer/presentation/widgets/dive_computer_section.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The dive computer's controls live on its Equipment page (issue #3676).
void main() {
  DiveComputer computer({
    String id = 'comp-1',
    String? fingerprint = 'abcd',
    DateTime? lastDownload,
  }) => DiveComputer(
    id: id,
    name: 'Teric',
    manufacturer: 'Shearwater',
    model: 'Teric',
    serialNumber: '3A1F22',
    firmwareVersion: '84',
    equipmentId: 'gear-1',
    diveCount: 42,
    lastDiveFingerprint: fingerprint,
    lastDownload: lastDownload,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pump(
    WidgetTester tester,
    List<DiveComputer> computers, {
    List<DiveComputer> duplicates = const [],
  }) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/equipment/gear-1',
      routes: [
        GoRoute(
          path: '/equipment/:id',
          builder: (_, s) => Scaffold(
            body: SingleChildScrollView(
              child: DiveComputerSection(equipmentId: s.pathParameters['id']!),
            ),
          ),
        ),
        GoRoute(
          path: '/dive-computers/discover',
          builder: (_, s) => Scaffold(
            body: Text('DISCOVER ${s.uri.queryParameters['equipment']}'),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          computersForEquipmentProvider(
            'gear-1',
          ).overrideWith((ref) async => computers),
          for (final c in computers) ...[
            diveComputerByIdProvider(c.id).overrideWith((ref) async => c),
            possibleDuplicateComputersProvider(
              c.id,
            ).overrideWith((ref) async => duplicates),
          ],
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a registered computer item shows download, re-import, '
      'connections, clock sync and stats', (tester) async {
    await pump(tester, [computer()]);

    expect(find.text('Download Dives'), findsOneWidget);
    expect(find.text('Re-import all dives'), findsOneWidget);
    expect(find.byType(DiveComputerConnectionsCard), findsOneWidget);
    expect(find.text('Clock sync'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Firmware Version'), findsOneWidget);
    expect(find.text('84'), findsOneWidget);
  });

  testWidgets('an unregistered computer item shows only Connect and '
      'download', (tester) async {
    await pump(tester, const []);

    expect(find.text('Connect and download'), findsOneWidget);
    expect(find.text('Download Dives'), findsNothing);
  });

  testWidgets('Connect and download pushes discovery bound to this item', (
    tester,
  ) async {
    await pump(tester, const []);

    await tester.tap(find.text('Connect and download'));
    await tester.pumpAndSettle();

    expect(find.text('DISCOVER gear-1'), findsOneWidget);
  });

  testWidgets('a duplicate record shows the banner with Merge', (tester) async {
    await pump(tester, [computer()], duplicates: [computer(id: 'comp-2')]);

    expect(find.byKey(const ValueKey('duplicate_banner')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('duplicate_banner_merge')),
      findsOneWidget,
    );
  });

  testWidgets('acts on the most recently downloaded registration', (
    tester,
  ) async {
    final older = computer(id: 'old', lastDownload: DateTime(2025));
    final newer = computer(id: 'new', lastDownload: DateTime(2026, 6));
    await pump(tester, [newer, older]);

    expect(find.text('Download Dives'), findsOneWidget);
  });
}
