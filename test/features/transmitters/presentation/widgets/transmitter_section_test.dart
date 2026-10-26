import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/features/transmitters/presentation/widgets/transmitter_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Answers the apply preview with fixed counts and records each key applied;
/// [failApply] makes the write fail, as a closed database would.
class _FakeApplyRepository extends TransmitterRepository {
  _FakeApplyRepository({required this.preview, this.failApply = false});

  final ApplyToExistingResult preview;
  final bool failApply;
  final applied = <String>[];

  @override
  Future<ApplyToExistingResult> previewApplyToExistingDives(
    Transmitter t,
  ) async => preview;

  @override
  Future<ApplyToExistingResult> applyToExistingDives(Transmitter t) async {
    if (failApply) throw StateError('database closed');
    applied.add(t.id);
    return preview;
  }
}

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

  Future<void> pump(
    WidgetTester tester,
    List<Transmitter> keys, {
    TransmitterRepository? repository,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/equipment/tx-gear',
      routes: [
        GoRoute(
          path: '/equipment/cyl',
          builder: (_, _) => const Scaffold(body: Text('CYLINDER PAGE')),
        ),
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
          if (repository != null)
            transmitterRepositoryProvider.overrideWithValue(repository),
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

  testWidgets('tapping a key opens it in the setup editor', (tester) async {
    await pump(tester, [key(id: 'k7', cylinder: 'cyl')]);

    await tester.tap(find.text('Transmitter 4A21F'));
    await tester.pumpAndSettle();

    expect(find.text('EDIT k7'), findsOneWidget);
  });

  testWidgets('the cylinder row opens the cylinder', (tester) async {
    await pump(tester, [key(cylinder: 'cyl')]);

    await tester.tap(find.text('Blue AL80'));
    await tester.pumpAndSettle();

    expect(find.text('CYLINDER PAGE'), findsOneWidget);
  });

  group('Apply to existing dives', () {
    testWidgets('says so when no cylinder carries the transmitter', (
      tester,
    ) async {
      final repo = _FakeApplyRepository(
        preview: (tanksUpdated: 0, divesUpdated: 0, mixesKept: 0),
      );
      await pump(tester, [key(cylinder: 'cyl')], repository: repo);

      await tester.tap(find.text('Apply to existing dives'));
      await tester.pumpAndSettle();

      expect(find.text('No cylinders carry this transmitter'), findsOneWidget);
      expect(repo.applied, isEmpty);
    });

    testWidgets('applies every key once confirmed', (tester) async {
      final repo = _FakeApplyRepository(
        preview: (tanksUpdated: 2, divesUpdated: 2, mixesKept: 0),
      );
      await pump(tester, [
        key(id: 'k1', cylinder: 'cyl'),
        key(id: 'k2', cylinder: 'cyl'),
      ], repository: repo);

      await tester.tap(find.text('Apply to existing dives'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('4 cylinders on 4 dives carry this transmitter'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(repo.applied, ['k1', 'k2']);
      expect(find.text('Updated 4 cylinders on 4 dives'), findsOneWidget);
    });

    testWidgets('cancelling applies nothing', (tester) async {
      final repo = _FakeApplyRepository(
        preview: (tanksUpdated: 2, divesUpdated: 2, mixesKept: 0),
      );
      await pump(tester, [key(cylinder: 'cyl')], repository: repo);

      await tester.tap(find.text('Apply to existing dives'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repo.applied, isEmpty);
    });

    testWidgets('a failed apply says so', (tester) async {
      final repo = _FakeApplyRepository(
        preview: (tanksUpdated: 2, divesUpdated: 2, mixesKept: 0),
        failApply: true,
      );
      await pump(tester, [key(cylinder: 'cyl')], repository: repo);

      await tester.tap(find.text('Apply to existing dives'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
      await tester.pumpAndSettle();

      expect(find.textContaining('database closed'), findsOneWidget);
    });
  });
}
