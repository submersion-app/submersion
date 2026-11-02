import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The location card names the buddy who has the item (issue #3790).
void main() {
  const wetsuit = EquipmentItem(
    id: 'wet',
    name: 'Wetsuit',
    type: EquipmentType.wetsuit,
  );
  final anna = Buddy(
    id: 'anna',
    name: 'Anna Renamed',
    notes: '',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final current = find.byKey(const ValueKey('equipment_location_current'));

  Future<void> pump(WidgetTester tester, {String? buddyId}) async {
    final place = EquipmentLocation(
      id: 'p',
      name: 'Anna Lindqvist',
      kind: EquipmentLocationKind.person,
      buddyId: buddyId,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: SingleChildScrollView(
              child: EquipmentLocationCard(equipment: wetsuit),
            ),
          ),
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
          equipmentLocationMovesProvider('wet').overrideWith(
            (ref) async => [
              EquipmentLocationMove(
                id: 'm',
                equipmentId: 'wet',
                locationId: 'p',
                movedAt: DateTime(2026, 10, 12),
                createdAt: DateTime(2026, 10, 12),
              ),
            ],
          ),
          allEquipmentLocationsByIdProvider.overrideWith(
            (ref) async => {'p': place},
          ),
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

  Text title(WidgetTester tester) => tester.widget<Text>(
    find.descendant(of: current, matching: find.byType(Text)).first,
  );

  testWidgets('a linked place reads With the buddy\'s current name', (
    tester,
  ) async {
    await pump(tester, buddyId: 'anna');
    expect(title(tester).data, 'With Anna Renamed');
  });

  testWidgets('the row opens the buddy', (tester) async {
    await pump(tester, buddyId: 'anna');
    await tester.tap(current);
    await tester.pumpAndSettle();
    expect(find.text('BUDDY anna'), findsOneWidget);
  });

  testWidgets('history rows keep the place name', (tester) async {
    await pump(tester, buddyId: 'anna');
    expect(find.text('Anna Lindqvist'), findsOneWidget);
  });

  testWidgets('an unlinked place keeps its name and opens nothing', (
    tester,
  ) async {
    await pump(tester);
    expect(title(tester).data, 'Anna Lindqvist');
    expect(tester.widget<ListTile>(current).onTap, isNull);
  });

  testWidgets('a buddy missing here keeps the place name and opens nothing', (
    tester,
  ) async {
    await pump(tester, buddyId: 'gone');
    expect(title(tester).data, 'Anna Lindqvist');
    expect(tester.widget<ListTile>(current).onTap, isNull);
  });
}
