import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_arrangement_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
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

  testWidgets('every order and sort field resolves to a non-empty label', (
    tester,
  ) async {
    final l10n = await localizationsFor(tester, const Locale('en'));

    for (final order in EquipmentTypeOrder.values) {
      expect(order.localizedName(l10n), isNotEmpty, reason: order.name);
    }
    for (final field in EquipmentItemSortField.values) {
      expect(field.localizedName(l10n), isNotEmpty, reason: field.name);
    }
  });

  testWidgets('labels follow the active locale', (tester) async {
    // Guards against a locale whose keys were added to the ARB but never
    // reached the generated hub, which falls back to English silently.
    final german = await localizationsFor(tester, const Locale('de'));

    expect(
      EquipmentTypeOrder.headToToe.localizedName(german),
      isNot(
        EquipmentTypeOrder.headToToe.localizedName(
          await localizationsFor(tester, const Locale('en')),
        ),
      ),
    );
  });
}
