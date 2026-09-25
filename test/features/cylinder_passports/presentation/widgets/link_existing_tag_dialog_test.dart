import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/link_existing_tag_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  const pid = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
  late AppDatabase db;

  Future<void> seedTank(String id, String name) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: name,
            type: 'tank',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('d1'),
          ),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
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
    await seedTank('eq-1', 'Faber 12');
    await seedTank('eq-2', 'Old Faber');
  });
  tearDown(tearDownTestDatabase);

  Future<AppLocalizations> pumpAndOpen(
    WidgetTester tester, {
    CylinderPassportRepository? repository,
  }) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          if (repository != null)
            cylinderPassportRepositoryProvider.overrideWithValue(repository),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLinkExistingTagDialog(
              context,
              equipmentId: 'eq-1',
              diverId: 'd1',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(AlertDialog)));
  }

  Future<void> submit(
    WidgetTester tester,
    AppLocalizations l10n,
    String text,
  ) async {
    await tester.enterText(find.byKey(const Key('linkTag_input')), text);
    await tester.tap(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.text(l10n.passport_tag_linkExisting),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('text that is not a tag is refused', (tester) async {
    final l10n = await pumpAndOpen(tester);
    await submit(tester, l10n, 'https://example.com/x');
    expect(find.text(l10n.passport_tag_linkInvalid), findsOneWidget);
    expect(await CylinderPassportRepository().getPassportId('eq-1'), isNull);
  });

  testWidgets('a tag held by another cylinder is refused by name', (
    tester,
  ) async {
    await tester.runAsync(
      () => CylinderPassportRepository().assignPassportId(
        equipmentId: 'eq-2',
        passportId: pid,
        diverId: 'd1',
      ),
    );
    final l10n = await pumpAndOpen(tester);
    await submit(tester, l10n, 'https://submersion.app/c#f=1&p=$pid');
    expect(find.text(l10n.passport_tag_linkInUse('Old Faber')), findsOneWidget);
    final id = await tester.runAsync(
      () => CylinderPassportRepository().getPassportId('eq-1'),
    );
    expect(id, isNull);
  });

  testWidgets('a free tag is linked and the dialog closes', (tester) async {
    final l10n = await pumpAndOpen(tester);
    await submit(tester, l10n, 'https://submersion.app/c#f=1&p=$pid');
    expect(find.byType(AlertDialog), findsNothing);
    final id = await tester.runAsync(
      () => CylinderPassportRepository().getPassportId('eq-1'),
    );
    expect(id, pid);
    expect(l10n.passport_tag_linked, isNotEmpty);
  });

  testWidgets('an unexpected failure says so and re-enables the dialog', (
    tester,
  ) async {
    final l10n = await pumpAndOpen(
      tester,
      repository: _BrokenPassportRepository(),
    );
    await submit(tester, l10n, 'https://submersion.app/c#f=1&p=$pid');
    expect(tester.takeException(), isNull);
    expect(find.text(l10n.passport_tag_linkFailed), findsOneWidget);
    final link = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l10n.passport_tag_linkExisting),
    );
    expect(link.onPressed, isNotNull);
  });
}

class _BrokenPassportRepository extends CylinderPassportRepository {
  @override
  Future<void> assignPassportId({
    required String equipmentId,
    required String passportId,
    String? diverId,
  }) async => throw StateError('database is locked');
}
