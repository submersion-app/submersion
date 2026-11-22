import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_routes.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';
import 'package:submersion/features/query/presentation/providers/query_id_set_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// A query runner whose queries all fail.
class _FailingRunner extends QueryIdSetRunner {
  _FailingRunner() : super(DatabaseService.instance.database);

  @override
  Future<Set<String>> ids(
    CompiledQuery compiled, {
    QueryScope? scope,
    QueryCte? cte,
  }) => Future.error(StateError('query failed'));
}

/// The gear item's edit addresses and panes (issue #4527, plan 6).
void main() {
  test('the edit address opens the page unlocked', () {
    expect(gearItemEditLocation('g1'), '/equipment/g1?mode=edit');
  });

  test('on a wide screen, mode=edit moves into the pane unlocked', () {
    expect(
      gearItemPaneLocation('g1', openUnlocked: true),
      '/equipment?selected=g1&mode=edit',
    );
    expect(gearItemPaneLocation('g1'), '/equipment?selected=g1');
  });

  testWidgets('the pane is the item page, unlocked', (tester) async {
    late Widget pane;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          pane = gearItemEditPane(context, 'g1', (_) {}, () {});
          return const SizedBox();
        },
      ),
    );

    expect(pane, isA<EquipmentDetailPage>());
    final page = pane as EquipmentDetailPage;
    expect(page.openUnlocked, isTrue);
    expect(page.embedded, isTrue);
  });

  group('after a Save in the list\'s pane', () {
    setUp(() async {
      await setUpTestDatabase();
      addTearDown(SyncCoordinator.reset);
    });
    tearDown(tearDownTestDatabase);

    /// Offers [status]'s view for a saved 'g1', on an app with [extra]
    /// overrides; the container, for reading what the offer changed.
    Future<ProviderContainer> offer(
      WidgetTester tester, {
      List<Override> extra = const [],
    }) async {
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
          overrides: [...overrides, ...extra].cast(),
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SizedBox()),
          ),
        ),
      );
      final context = tester.element(find.byType(SizedBox));
      final container = ProviderScope.containerOf(context);
      await tester.runAsync(
        () => offerViewRevealingSavedItem(
          messenger: ScaffoldMessenger.of(context),
          l10n: lookupAppLocalizations(const Locale('en')),
          container: container,
          equipmentId: 'g1',
          status: EquipmentStatus.wanted,
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('Show moves the list to that view and marks the item', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final container = await offer(tester);
      expect(container.read(highlightedEquipmentIdProvider), isNull);

      await tester.tap(find.text(l10n.equipment_edit_snackbar_showAction));
      await tester.pumpAndSettle();

      expect(
        container.read(equipmentFilterProvider),
        isNot(const EquipmentFilterState()),
      );
      expect(container.read(highlightedEquipmentIdProvider), 'g1');
    });

    testWidgets('a visibility check that fails still confirms the Save', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      await offer(
        tester,
        extra: [queryIdSetRunnerProvider.overrideWithValue(_FailingRunner())],
      );

      expect(find.text(l10n.equipment_edit_snackbar_updated), findsOneWidget);
      expect(
        find.text(l10n.equipment_edit_snackbar_hiddenByView),
        findsNothing,
      );
    });

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
