import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The set page's Clone (issue #2156) opens the clone form, and once the
/// clone is saved shows the clone in place of the set it came from.
void main() {
  EquipmentSet set(String id) => EquipmentSet(
    id: id,
    name: 'Set $id',
    items: const [],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  /// The clone form's stand-in: it shows where it was opened from and pops
  /// with [savedId], or with nothing for a discard.
  Widget cloneForm(BuildContext context, GoRouterState state) => Scaffold(
    body: Column(
      children: [
        Text('CLONE FORM from=${state.uri.queryParameters['cloneFrom']}'),
        TextButton(
          onPressed: () => context.pop('copy'),
          child: const Text('SAVE_CLONE'),
        ),
        TextButton(
          onPressed: () => context.pop(),
          child: const Text('DISCARD_CLONE'),
        ),
      ],
    ),
  );

  Future<GoRouter> pump(WidgetTester tester, String initialLocation) async {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        // The desktop split: the detail pane follows ?setSelected.
        GoRoute(
          path: '/equipment',
          builder: (_, state) {
            final id = state.uri.queryParameters['setSelected'];
            return id == null
                ? const Scaffold(body: Text('LIST'))
                : EquipmentSetDetailPage(key: ValueKey(id), setId: id);
          },
          routes: [
            GoRoute(path: 'sets/new', builder: cloneForm),
            GoRoute(
              path: 'sets/:setId',
              builder: (_, state) =>
                  EquipmentSetDetailPage(setId: state.pathParameters['setId']!),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          equipmentSetProvider.overrideWith((ref, id) async => set(id)),
          equipmentSetGeofencesProvider.overrideWith((ref, id) async => []),
          equipmentComponentsIndexProvider.overrideWith(
            (ref) => Future.value(ComponentsIndex.fromRows(const [])),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> chooseClone(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clone'));
    await tester.pumpAndSettle();
  }

  testWidgets('the menu offers Clone, which opens the clone form', (
    tester,
  ) async {
    await pump(tester, '/equipment/sets/s1');
    await chooseClone(tester);
    expect(find.text('CLONE FORM from=s1'), findsOneWidget);
  });

  testWidgets('Clone sits just above Delete', (tester) async {
    await pump(tester, '/equipment/sets/s1');
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    final values = [
      for (final item in tester.widgetList<PopupMenuItem<String>>(
        find.byType(PopupMenuItem<String>),
      ))
        item.value,
    ];
    expect(values.sublist(values.length - 2), ['clone', 'delete']);
  });

  testWidgets('a saved clone takes the source page\'s place', (tester) async {
    final router = await pump(tester, '/equipment/sets/s1');
    await chooseClone(tester);
    await tester.tap(find.text('SAVE_CLONE'));
    await tester.pumpAndSettle();

    expect(find.text('Set copy'), findsWidgets);
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/equipment/sets/copy',
    );
  });

  testWidgets('a discarded clone returns to the source', (tester) async {
    await pump(tester, '/equipment/sets/s1');
    await chooseClone(tester);
    await tester.tap(find.text('DISCARD_CLONE'));
    await tester.pumpAndSettle();

    expect(find.text('Set s1'), findsWidgets);
  });

  testWidgets('in the split view a saved clone is selected in the list', (
    tester,
  ) async {
    final router = await pump(tester, '/equipment?setSelected=s1');
    await chooseClone(tester);
    await tester.tap(find.text('SAVE_CLONE'));
    await tester.pumpAndSettle();

    expect(find.text('Set copy'), findsWidgets);
    final uri = router.routerDelegate.currentConfiguration.uri;
    expect(uri.path, '/equipment');
    expect(uri.queryParameters['setSelected'], 'copy');
  });
}
