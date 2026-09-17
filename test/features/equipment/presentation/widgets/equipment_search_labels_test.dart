import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import '../../../../helpers/mock_providers.dart';

/// Equipment search labels its hits as one list (issue #1549), so two
/// identical results read differently from each other.
void main() {
  EquipmentItem pouch(String id, String serial) => EquipmentItem(
    id: id,
    name: 'Pouches',
    type: EquipmentType.other,
    brand: 'Palantic',
    model: 'Drop-Bottom',
    serialNumber: serial,
  );

  Future<void> openSearchFor(WidgetTester tester, String query) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => showSearch(
                context: context,
                delegate: EquipmentSearchDelegate(context.l10n),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(
          path: '/equipment/:id',
          builder: (_, state) =>
              Scaffold(body: Text('detail ${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          // Descending serial order, so input order cannot produce the
          // result.
          equipmentSearchProvider.overrideWith(
            (ref, query) async => [pouch('b', 'X2'), pouch('a', 'X1')],
          ),
          equipmentComponentsIndexProvider.overrideWith(
            (ref) => Future.value(ComponentsIndex.fromRows(const [])),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), query);
    // Past the 300 ms debounce, then let the results settle.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  testWidgets('identical search results gain the serial number that differs', (
    tester,
  ) async {
    await openSearchFor(tester, 'pou');
    expect(find.text('Palantic Drop-Bottom · S/N X1'), findsOneWidget);
    expect(find.text('Palantic Drop-Bottom · S/N X2'), findsOneWidget);
  });

  testWidgets('tapping a labelled result opens that item', (tester) async {
    await openSearchFor(tester, 'pou');
    await tester.tap(find.text('Palantic Drop-Bottom · S/N X1'));
    await tester.pumpAndSettle();
    expect(find.text('detail a'), findsOneWidget);
  });
}
