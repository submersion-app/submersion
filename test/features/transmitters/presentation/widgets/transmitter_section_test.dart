import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/features/transmitters/presentation/widgets/transmitter_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// A transmitter's setup lives on its Equipment page (issue #3676).
void main() {
  Transmitter key({
    String id = 'k1',
    bool configured = true,
    String? cylinder,
    double? volume,
  }) => Transmitter(
    id: id,
    transmitterSerial: '4A21F',
    label: 'Back gas tx',
    role: TankRole.stage,
    equipmentId: cylinder,
    volumeL: volume,
    isConfigured: configured,
    transmitterEquipmentId: 'tx-gear',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pump(WidgetTester tester, List<Transmitter> keys) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/equipment/tx-gear',
      routes: [
        GoRoute(
          path: '/equipment/:id',
          builder: (_, s) => Scaffold(
            body: SingleChildScrollView(
              child: TransmitterSection(equipmentId: s.pathParameters['id']!),
            ),
          ),
          routes: [
            GoRoute(
              path: 'transmitter',
              builder: (_, _) => const Scaffold(body: Text('ADD KEY')),
              routes: [
                GoRoute(
                  path: ':k',
                  builder: (_, s) =>
                      Scaffold(body: Text('EDIT ${s.pathParameters['k']}')),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          transmittersForEquipmentProvider(
            'tx-gear',
          ).overrideWith((ref) async => keys),
          equipmentItemProvider('cyl').overrideWith(
            (ref) async => const EquipmentItem(
              id: 'cyl',
              name: 'Blue AL80',
              type: EquipmentType.tank,
            ),
          ),
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

  testWidgets('an auto-created transmitter says no cylinder is set up', (
    tester,
  ) async {
    await pump(tester, [key(configured: false)]);

    expect(find.text('No cylinder set up'), findsOneWidget);
    expect(find.text('Transmitter 4A21F'), findsOneWidget);
  });

  testWidgets('a set-up transmitter names its cylinder and role', (
    tester,
  ) async {
    await pump(tester, [key(cylinder: 'cyl')]);

    expect(find.text('No cylinder set up'), findsNothing);
    expect(find.text('Blue AL80'), findsOneWidget);
    expect(find.textContaining('Stage'), findsOneWidget);
  });

  testWidgets('Set up opens the key in the setup editor', (tester) async {
    await pump(tester, [key(configured: false)]);

    await tester.tap(find.text('Set up'));
    await tester.pumpAndSettle();

    expect(find.text('EDIT k1'), findsOneWidget);
  });

  testWidgets('a hand-added transmitter with no key offers to add one', (
    tester,
  ) async {
    await pump(tester, const []);

    await tester.tap(find.text('Add serial or channel'));
    await tester.pumpAndSettle();

    expect(find.text('ADD KEY'), findsOneWidget);
  });
}
