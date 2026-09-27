import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_resolver.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/utils/scan_cylinder_tag.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  const id = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  const tag = 'https://submersion.app/c#f=1&p=$id&v=10';
  late AppDatabase db;
  Object? passportExtra;

  setUp(() async {
    db = await setUpTestDatabase();
    passportExtra = null;
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'eq-1',
            name: 'Faber 12',
            type: 'tank',
            createdAt: t,
            updatedAt: t,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    required String text,
    List<dynamic> extraOverrides = const [],
  }) async {
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => openScannedTag(context, ref, text),
                child: const Text('go'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/equipment/tag',
          builder: (context, state) => const Text('foreign page'),
        ),
        GoRoute(
          path: '/equipment/:id/passport',
          builder: (context, state) {
            passportExtra = state.extra;
            return Text('passport ${state.pathParameters['id']}');
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...overrides, ...extraOverrides].cast(),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.text('go')));
    await tester.tap(find.text('go'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    return l10n;
  }

  testWidgets('an own tag opens that cylinder with the scanned tag', (
    tester,
  ) async {
    await tester.runAsync(
      () => CylinderPassportRepository().assignPassportId(
        equipmentId: 'eq-1',
        passportId: id,
      ),
    );
    await pump(tester, text: tag);
    expect(find.text('passport eq-1'), findsOneWidget);
    expect(passportExtra, isA<CylinderPassportPayload>());
    expect((passportExtra! as CylinderPassportPayload).volumeL, 10);
  });

  testWidgets('a cylinder shared with the diver resolves as their own', (
    tester,
  ) async {
    // Diver A owns the cylinder and shares it with diver B, who scans it.
    await tester.runAsync(() async {
      final t = DateTime.now().millisecondsSinceEpoch;
      for (final d in ['d-a', 'd-b']) {
        await db
            .into(db.divers)
            .insert(
              DiversCompanion.insert(
                id: d,
                name: d,
                createdAt: t,
                updatedAt: t,
              ),
            );
      }
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: 'eq-a',
              name: 'Faber 12',
              type: 'tank',
              createdAt: t,
              updatedAt: t,
              diverId: const Value('d-a'),
            ),
          );
      await CylinderPassportRepository().assignPassportId(
        equipmentId: 'eq-a',
        passportId: id,
        diverId: 'd-a',
      );
      await EquipmentShareRepository().shareMany(
        equipmentIds: ['eq-a'],
        diverIds: ['d-b'],
        actingDiverId: 'd-a',
      );
    });
    late WidgetRef scanner;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await getBaseOverrides(),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd-b'),
        ].cast(),
        child: Consumer(
          builder: (context, ref, _) {
            scanner = ref;
            return const SizedBox();
          },
        ),
      ),
    );
    final resolution = await tester.runAsync(
      () => resolveScannedTag(scanner, tag),
    );
    expect(
      resolution,
      isA<OwnCylinder>().having((r) => r.equipmentId, 'equipmentId', 'eq-a'),
    );
  });

  testWidgets('a tag nobody holds opens the foreign passport', (tester) async {
    await pump(tester, text: tag);
    expect(find.text('foreign page'), findsOneWidget);
  });

  testWidgets('text that is not a tag says so and stays put', (tester) async {
    final l10n = await pump(tester, text: 'hello');
    expect(find.text(l10n.passport_tag_linkInvalid), findsOneWidget);
    expect(find.text('go'), findsOneWidget);
  });

  testWidgets('a failing lookup reports it', (tester) async {
    final l10n = await pump(
      tester,
      text: tag,
      extraOverrides: [
        cylinderPassportRepositoryProvider.overrideWithValue(_BrokenRepo()),
      ],
    );
    expect(find.text(l10n.passport_scan_openFailed), findsOneWidget);
  });

  testWidgets('leaving the page before the lookup ends opens nothing', (
    tester,
  ) async {
    // The lookup waits on this gate, so the page can be left first.
    final gate = Completer<void>();
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/scan',
          builder: (context, state) => Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => openScannedTag(context, ref, tag),
                child: const Text('go'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/equipment/:id/passport',
          builder: (context, state) =>
              Text('passport ${state.pathParameters['id']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          cylinderPassportRepositoryProvider.overrideWithValue(
            _GatedRepo(gate.future),
          ),
        ].cast(),
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    router.push('/scan');
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.text('go')));

    await tester.tap(find.text('go'));
    await tester.pump();
    // The diver backs out while the tag is still being looked up.
    router.pop();
    await tester.pumpAndSettle();
    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.textContaining('passport '), findsNothing);
    expect(find.text(l10n.passport_scan_openFailed), findsNothing);
  });
}

class _BrokenRepo extends CylinderPassportRepository {
  @override
  Future<String?> findEquipmentIdByPassportId(
    String passportId, {
    String? diverId,
  }) async => throw StateError('database is locked');
}

/// Holds a cylinder the diver owns, found only once [gate] opens.
class _GatedRepo extends CylinderPassportRepository {
  _GatedRepo(this.gate);

  final Future<void> gate;

  @override
  Future<String?> findEquipmentIdByPassportId(
    String passportId, {
    String? diverId,
  }) async {
    await gate;
    return 'eq-1';
  }
}
