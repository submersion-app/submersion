import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// applyEquipmentSorting compared EquipmentType.displayName, the hardcoded
/// English label, while the list rendered type.localizedName. On a non-English
/// build the Equipment page's "sort by type" therefore ordered by names the
/// diver never sees.
void main() {
  const zeagle = EquipmentItem(
    id: 'bcd-1',
    name: 'Zeagle',
    type: EquipmentType.bcd,
  );
  const faber = EquipmentItem(
    id: 'tank-1',
    name: 'Faber',
    type: EquipmentType.tank,
  );
  const apeks = EquipmentItem(
    id: 'reg-1',
    name: 'Apeks',
    type: EquipmentType.regulator,
  );

  Future<AppLocalizations> localizationsFor(
    WidgetTester tester,
    Locale locale,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return l10n;
  }

  testWidgets('type sorting follows the localized name', (tester) async {
    // In German the three types are Tarierjacket (BCD), Flasche (tank) and
    // Atemregler (regulator), so the German alphabetical order reverses the
    // English one. Any implementation comparing displayName produces the
    // English sequence here.
    final german = await localizationsFor(tester, const Locale('de'));

    final sorted = applyEquipmentSorting(
      const [zeagle, faber, apeks],
      const SortState(
        field: EquipmentSortField.type,
        direction: SortDirection.descending,
      ),
      typeLabel: (t) => t.localizedName(german),
    );

    expect(sorted.map((e) => e.type).toList(), [
      EquipmentType.regulator, // Atemregler
      EquipmentType.tank, // Flasche
      EquipmentType.bcd, // Tarierjacket
    ]);
  });

  testWidgets('without a resolver it keeps the old English behaviour', (
    tester,
  ) async {
    final sorted = applyEquipmentSorting(
      const [zeagle, faber, apeks],
      const SortState(
        field: EquipmentSortField.type,
        direction: SortDirection.descending,
      ),
    );

    expect(sorted.map((e) => e.type).toList(), [
      EquipmentType.bcd, // BCD
      EquipmentType.regulator, // Regulator
      EquipmentType.tank, // Tank
    ]);
  });
}
