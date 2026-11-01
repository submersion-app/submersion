import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_location_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The Buddy row on a place's page (issue #3790).
void main() {
  final row = find.byKey(const ValueKey('equipment_location_buddy_row'));
  final anna = Buddy(
    id: 'anna',
    name: 'Anna Lindqvist',
    notes: '',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pump(WidgetTester tester, {String? buddyId}) async {
    final place = EquipmentLocation(
      id: 'p',
      name: 'Anna at home',
      kind: EquipmentLocationKind.person,
      buddyId: buddyId,
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
          path: '/buddies/:id',
          builder: (context, state) =>
              Scaffold(body: Text('BUDDY ${state.pathParameters['id']}')),
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
          buddyByIdProvider('anna').overrideWith((ref) async => anna),
          buddyByIdProvider('gone').overrideWith((ref) async => null),
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

  testWidgets('a linked place shows its buddy and opens them', (tester) async {
    await pump(tester, buddyId: 'anna');
    expect(find.text('Buddy'), findsOneWidget);
    expect(find.text('Anna Lindqvist'), findsOneWidget);

    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('BUDDY anna'), findsOneWidget);
  });

  testWidgets('an unlinked place shows no row', (tester) async {
    await pump(tester);
    expect(row, findsNothing);
  });

  testWidgets('a buddy missing on this device shows no row', (tester) async {
    await pump(tester, buddyId: 'gone');
    expect(row, findsNothing);
  });
}
