import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  EquipmentSet set({required bool isDefault}) => EquipmentSet(
    id: 's1',
    name: 'Cold Water',
    isDefault: isDefault,
    items: const [],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pump(WidgetTester tester, {required bool isDefault}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          equipmentSetProvider.overrideWith(
            (ref, id) async => set(isDefault: isDefault),
          ),
          equipmentSetGeofencesProvider.overrideWith((ref, id) async => []),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EquipmentSetDetailPage(setId: 's1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the Default badge when the set is default', (
    tester,
  ) async {
    await pump(tester, isDefault: true);
    expect(find.text('Default'), findsOneWidget);
  });

  testWidgets('offers "Set as default" only when not already default', (
    tester,
  ) async {
    await pump(tester, isDefault: false);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Set as default'), findsOneWidget);
  });
}
