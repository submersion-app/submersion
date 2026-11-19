import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/database/database.dart'
    hide EquipmentSet, EquipmentSetGeofence;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The set page's tests' database: diver d1 with a drysuit (e1), a
/// regulator (e2) and fins (e3), named apart from their types; set s1 "Cold water" holding e1 and e2,
/// with geofence g1 and the figure off; set s2 "Warm" empty and the
/// diver's default.
Future<void> seedSetPage({bool showFigure = false}) async {
  await setUpTestDatabase();
  final db = DatabaseService.instance.database;
  final t = DateTime(2026).millisecondsSinceEpoch;
  await db
      .into(db.divers)
      .insert(
        DiversCompanion.insert(
          id: 'd1',
          name: 'd1',
          createdAt: t,
          updatedAt: t,
        ),
      );
  for (final (id, name, type) in [
    ('e1', 'Bare drysuit', 'drysuit'),
    ('e2', 'Apeks reg', 'regulator'),
    ('e3', 'Jet fins', 'fins'),
  ]) {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: name,
            type: type,
            createdAt: t,
            updatedAt: t,
            diverId: const Value('d1'),
          ),
        );
  }
  final sets = EquipmentSetRepository();
  await sets.createSet(
    EquipmentSet(
      id: 's1',
      diverId: 'd1',
      name: 'Cold water',
      equipmentIds: const ['e1', 'e2'],
      showFigure: showFigure,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );
  await sets.createSet(
    EquipmentSet(
      id: 's2',
      diverId: 'd1',
      name: 'Warm',
      showFigure: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );
  await sets.setAsDefault('s2');
  await sets.addGeofence(
    EquipmentSetGeofence(
      id: 'g1',
      setId: 's1',
      label: 'Home reef',
      latitude: 10,
      longitude: 20,
      radiusMeters: 200,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );
  // What setup wrote is not a sitting.
  await ChangeLogRepository().settleAll();
  await db.customStatement('DELETE FROM change_log_operations');
}

/// The History entries written since [seedSetPage], with their labels,
/// read outside the test's fake clock.
Future<List<String?>> setPageOperations(WidgetTester tester) async =>
    (await tester.runAsync(_operations))!;

Future<List<String?>> _operations() async {
  await ChangeLogRepository().settleAll();
  final rows = await DatabaseService.instance.database
      .customSelect('SELECT label FROM change_log_operations')
      .get();
  return [for (final row in rows) row.data['label'] as String?];
}

/// The set [id] as stored, with its geofences, read outside the test's
/// fake clock.
Future<EquipmentSet> storedSet(WidgetTester tester, [String id = 's1']) async =>
    (await tester.runAsync(
      () => EquipmentSetRepository().getSetById(id, includeGeofences: true),
    ))!;

/// Pumps the set page for [setId] with the phase 3 switch on (unless
/// [unlockEditing] is false), at phone width. A gear item's page is a
/// placeholder reading "item" and its id, and the gear list "gear list".
Future<void> pumpSetPage(
  WidgetTester tester, {
  String setId = 's1',
  bool unlockEditing = true,
  bool openUnlocked = false,
  Size size = const Size(600, 2400),
  VoidCallback? onSittingEnded,
  List<Override> extraOverrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  overrides
    ..add(validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'))
    ..addAll(extraOverrides);
  final router = GoRouter(
    initialLocation: '/equipment/sets/$setId',
    routes: [
      GoRoute(
        path: '/equipment',
        builder: (_, _) => const Scaffold(body: Text('gear list')),
        routes: [
          GoRoute(
            path: 'sets/:setId',
            builder: (_, state) => EquipmentSetDetailPage(
              setId: state.pathParameters['setId']!,
              unlockEditing: unlockEditing,
              openUnlocked: openUnlocked,
              onSittingEnded: onSittingEnded,
            ),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                Scaffold(body: Text('item ${state.pathParameters['id']}')),
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
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
