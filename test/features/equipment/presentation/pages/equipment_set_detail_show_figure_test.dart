import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/database/database.dart'
    hide EquipmentSet, EquipmentSetGeofence;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The set page's menu turns the diver figure on and off and saves the
/// choice, backed by a real database so the notifier and repository run.
void main() {
  late EquipmentSetRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = EquipmentSetRepository();
    final db = DatabaseService.instance.database;
    final t = DateTime.now().millisecondsSinceEpoch;
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
    await repo.createSet(
      EquipmentSet(
        id: 'a',
        diverId: 'd1',
        name: 'Reef set',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<Widget> page() async {
    final overrides = await getBaseOverrides();
    overrides.add(
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
    );
    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/detail',
          builder: (_, _) => const EquipmentSetDetailPage(setId: 'a'),
        ),
      ],
    );
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: router,
        // The finders match English menu labels, so pin the locale rather
        // than inherit the host's.
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }

  testWidgets('the menu turns the figure on and saves it', (tester) async {
    await tester.pumpWidget(await page());
    await tester.pumpAndSettle();

    await openMenu(tester);
    expect(find.text('Hide diver figure'), findsNothing);
    await tester.tap(find.text('Show diver figure'));
    await tester.pumpAndSettle();

    expect((await repo.getSetById('a'))!.showFigure, isTrue);
  });

  testWidgets('toggling the figure keeps the set\'s members', (tester) async {
    final mask = await EquipmentRepository().createEquipment(
      const EquipmentItem(
        id: '',
        diverId: 'd1',
        name: 'Hollis M1',
        type: EquipmentType.mask,
      ),
    );
    await repo.addItemToSet('a', mask.id);

    await tester.pumpWidget(await page());
    await tester.pumpAndSettle();
    await openMenu(tester);
    await tester.tap(find.text('Show diver figure'));
    await tester.pumpAndSettle();

    final saved = (await repo.getSetById('a'))!;
    expect(saved.showFigure, isTrue);
    expect(saved.equipmentIds, [mask.id]);
  });

  testWidgets('with the figure on, the menu offers to hide it', (tester) async {
    final set = (await repo.getSetById('a'))!;
    await repo.updateSet(set.copyWith(showFigure: true));

    await tester.pumpWidget(await page());
    await tester.pumpAndSettle();

    await openMenu(tester);
    expect(find.text('Show diver figure'), findsNothing);
    await tester.tap(find.text('Hide diver figure'));
    await tester.pumpAndSettle();

    expect((await repo.getSetById('a'))!.showFigure, isFalse);
  });
}
