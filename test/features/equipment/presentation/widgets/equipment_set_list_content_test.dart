import 'package:flutter/material.dart';
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
          home: Scaffold(body: EquipmentSetListContent(showAppBar: false)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cold Water'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Default'), findsOneWidget);
  });
}
