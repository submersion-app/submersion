import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_share_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_shares_sharing_adapter.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_sharing_sitting.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_sharing_row.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The gear item page's "Shared with" row (issue #2046), and its sitting
/// mode where the page edits in place (issue #4527, phase 3, plan 6).
void main() {
  final l = AppLocalizationsEn();
  const bcd = EquipmentItem(
    id: 'bcd',
    diverId: 'me',
    name: 'BCD',
    type: EquipmentType.bcd,
  );

  late EquipmentShareRepository shares;

  setUp(() async {
    final db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['me', 'sam']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id == 'me' ? 'Me' : 'Sam',
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'bcd',
            name: 'BCD',
            type: 'bcd',
            createdAt: t,
            updatedAt: t,
            diverId: const Value('me'),
          ),
        );
    shares = EquipmentShareRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> storedShares() async => {
    for (final s in await shares.getSharesFor('bcd')) s.diverId,
  };

  Future<void> pumpRow(
    WidgetTester tester, {
    String activeDiver = 'me',
    EditSession<EquipmentItem>? editing,
    EditSession<EquipmentItem>? shown,
    bool readOnly = false,
  }) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) async => activeDiver,
          ),
        ].cast(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EquipmentSharingRow(
              equipment: bcd,
              editing: editing,
              shown: shown,
              readOnly: readOnly,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> shareWithSam(WidgetTester tester) async {
    await tester.tap(find.text(l.equipment_sharing_sharedWithLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.common_action_save));
    await tester.pumpAndSettle();
  }

  testWidgets('the owner\'s tap opens the checklist and shares at once', (
    tester,
  ) async {
    await pumpRow(tester);

    await shareWithSam(tester);

    expect(await storedShares(), {'sam'});
  });

  testWidgets('a sharee sees it read only', (tester) async {
    await pumpRow(tester, activeDiver: 'sam');

    expect(find.text(l.equipment_sharing_ownedByLabel), findsOneWidget);
    await tester.tap(find.text(l.equipment_sharing_sharedWithLabel));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('in a sitting a share is held until Save', (tester) async {
    final session = EditSession(bcd);
    addTearDown(session.dispose);
    await tester.runAsync(
      () => gearItemSharing.load(
        session,
        EquipmentSharesSharingAdapter(shares),
        actingDiverId: 'me',
      ),
    );
    await pumpRow(tester, editing: session);

    await shareWithSam(tester);

    expect(await storedShares(), isEmpty);
    expect(gearItemSharing.inSitting(session), {'sam'});
    expect(session.changedCardIds, {'details'});
    expect(find.text('Sam'), findsOneWidget);

    await tester.runAsync(session.runHeldWrites);
    expect(await storedShares(), {'sam'});
  });

  testWidgets('locked with the switch on, no tap writes', (tester) async {
    await pumpRow(tester, readOnly: true);

    await tester.tap(find.text(l.equipment_sharing_sharedWithLabel));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(await storedShares(), isEmpty);
  });

  test('a share the profile may no longer make is refused at Save', () async {
    final session = EditSession(bcd);
    addTearDown(session.dispose);
    await gearItemSharing.load(
      session,
      EquipmentSharesSharingAdapter(shares),
      actingDiverId: 'me',
    );
    gearItemSharing.set(session, {'sam'}, actingDiverId: 'me');
    // The item changed hands on another device meanwhile.
    await DatabaseService.instance.database.customStatement(
      "UPDATE equipment SET diver_id = 'sam' WHERE id = 'bcd'",
    );

    await expectLater(
      session.runHeldWrites(),
      throwsA(isA<RecordSittingRefusal>()),
    );
    expect(await storedShares(), isEmpty);
  });
}
