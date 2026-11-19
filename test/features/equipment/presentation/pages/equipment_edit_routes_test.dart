import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_routes.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The gear item's edit addresses and panes behind phase 3's switch (issue
/// #4527, plan 6).
void main() {
  test('the edit address redirects with the switch on, not off', () {
    expect(
      gearItemEditLocation('g1', unlockEditing: true),
      '/equipment/g1?mode=edit',
    );
    expect(gearItemEditLocation('g1', unlockEditing: false), isNull);
  });

  test('on a wide screen, mode=edit moves into the pane unlocked', () {
    expect(
      gearItemPaneLocation('g1', openUnlocked: true),
      '/equipment?selected=g1&mode=edit',
    );
    expect(gearItemPaneLocation('g1'), '/equipment?selected=g1');
  });

  testWidgets('the pane is the item page, unlocked, with the switch on', (
    tester,
  ) async {
    late Widget pane;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          pane = gearItemEditPane(
            context,
            'g1',
            (_) {},
            () {},
            unlockEditing: true,
          );
          return const SizedBox();
        },
      ),
    );

    expect(pane, isA<EquipmentDetailPage>());
    final page = pane as EquipmentDetailPage;
    expect(page.openUnlocked, isTrue);
    expect(page.embedded, isTrue);
  });

  testWidgets('with the switch off the pane opens the form', (tester) async {
    late Widget pane;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          pane = gearItemEditPane(
            context,
            'g1',
            (_) {},
            () {},
            unlockEditing: false,
          );
          return const SizedBox();
        },
      ),
    );

    expect(pane, isA<EquipmentEditPage>());
  });

  group('after a Save in the list\'s pane', () {
    setUp(() async {
      await setUpTestDatabase();
      addTearDown(SyncCoordinator.reset);
    });
    tearDown(tearDownTestDatabase);

    // The pane's page may be gone by the time the check answers: it runs on
    // the provider container and a messenger taken up front, never on the
    // page's own ref.
    testWidgets('an item the list\'s view hides is offered its view', (
      tester,
    ) async {
      await EquipmentRepository().createEquipment(
        const EquipmentItem(
          id: 'g1',
          name: 'Dream Fins',
          type: EquipmentType.fins,
          status: EquipmentStatus.wanted,
          isActive: false,
        ),
      );
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides.cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SizedBox()),
          ),
        ),
      );
      final context = tester.element(find.byType(SizedBox));
      final messenger = ScaffoldMessenger.of(context);
      final l10n = lookupAppLocalizations(const Locale('en'));
      final container = ProviderScope.containerOf(context);

      await tester.runAsync(
        () => offerViewRevealingSavedItem(
          messenger: messenger,
          l10n: l10n,
          container: container,
          equipmentId: 'g1',
          status: EquipmentStatus.wanted,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.equipment_edit_snackbar_hiddenByView), findsOne);
    });
  });
}
