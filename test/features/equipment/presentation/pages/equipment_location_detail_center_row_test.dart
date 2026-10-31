import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_location_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The Saved dive center row on a place's page (issue #3623).
void main() {
  final row = find.byKey(const ValueKey('equipment_location_center_row'));
  final reef = DiveCenter(
    id: 'reef',
    name: 'Blue Reef Divers',
    notes: '',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pump(WidgetTester tester, {String? centerId}) async {
    final place = EquipmentLocation(
      id: 'p',
      name: 'Reef locker',
      kind: EquipmentLocationKind.diveCenter,
      diveCenterId: centerId,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const EquipmentLocationDetailPage(locationId: 'p'),
        ),
        GoRoute(
          path: '/dive-centers/:id',
          builder: (context, state) =>
              Scaffold(body: Text('CENTER ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          allEquipmentLocationsByIdProvider.overrideWith(
            (ref) async => {'p': place},
          ),
          currentEquipmentLocationsProvider.overrideWith(
            (ref) async => const <String, EquipmentLocation>{},
          ),
          allEquipmentProvider.overrideWith((ref) async => const []),
          equipmentLocationInUseProvider('p').overrideWith((ref) async => true),
          diveCenterByIdProvider('reef').overrideWith((ref) async => reef),
          diveCenterByIdProvider('gone').overrideWith((ref) async => null),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a linked place shows its center and opens it', (tester) async {
    await pump(tester, centerId: 'reef');
    expect(find.text('Saved dive center'), findsOneWidget);
    expect(find.text('Blue Reef Divers'), findsOneWidget);

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('CENTER reef'), findsOneWidget);
  });

  testWidgets('an unlinked place shows no row', (tester) async {
    await pump(tester);
    expect(row, findsNothing);
  });

  testWidgets('a center missing on this device shows no row', (tester) async {
    await pump(tester, centerId: 'gone');
    expect(row, findsNothing);
  });
}
