import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide EquipmentSet;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_set_list_content.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
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
  });
  tearDown(tearDownTestDatabase);

  testWidgets('shows the Default badge on the default set row', (tester) async {
    final repo = EquipmentSetRepository();
    await repo.createSet(
      EquipmentSet(
        id: 'a',
        diverId: 'd1',
        name: 'Cold Water',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await repo.setAsDefault('a', diverId: 'd1');

    final overrides = await getBaseOverrides();
    overrides.add(
      validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(body: EquipmentSetListContent(showAppBar: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cold Water'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Default'), findsOneWidget);
  });

  testWidgets(
    'the item count leads the description in the subtitle, with no count '
    'chip in trailing (#2717)',
    (tester) async {
      final db = DatabaseService.instance.database;
      final t = DateTime.now().millisecondsSinceEpoch;
      for (final id in ['e1', 'e2', 'e3']) {
        await db
            .into(db.equipment)
            .insert(
              EquipmentCompanion.insert(
                id: id,
                name: id,
                type: 'bcd',
                createdAt: t,
                updatedAt: t,
                diverId: const Value('d1'),
              ),
            );
      }
      final repo = EquipmentSetRepository();
      for (final set in [
        ('a', 'Cold Water', 'Drysuit setup', ['e1', 'e2', 'e3']),
        ('b', 'Travel', '', ['e1']),
        ('c', 'Empty', 'Not packed yet', <String>[]),
      ]) {
        await repo.createSet(
          EquipmentSet(
            id: set.$1,
            diverId: 'd1',
            name: set.$2,
            description: set.$3,
            equipmentIds: set.$4,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      final overrides = await getBaseOverrides();
      overrides.add(
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: Scaffold(body: EquipmentSetListContent(showAppBar: false)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 items · Drysuit setup'), findsOneWidget);
      expect(find.text('1 item'), findsOneWidget);
      expect(find.text('Not packed yet'), findsOneWidget);
      expect(find.byType(Chip), findsNothing);
    },
  );
}
