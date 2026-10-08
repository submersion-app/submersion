import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_filter_gear_attributes_section.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_choice_attribute_filter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/core/text/fuzzy_match.dart';

void main() {
  testWidgets('lists the gear categories by their label (#2937)', (
    tester,
  ) async {
    // Every type with a choice field, owned, handed over in enum order.
    final withChoices = [
      for (final t in EquipmentType.values)
        if (EquipmentChoiceAttributeFilter.choiceDefsFor(t).isNotEmpty) t,
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [diveGearTypesProvider.overrideWithValue(withChoices)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveFilterGearAttributesSection(
              category: null,
              conditions: const [],
              onChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    final dropdown = tester.widget<DropdownButton<EquipmentType?>>(
      find.byType(DropdownButton<EquipmentType?>),
    );
    final shown = [
      for (final item in dropdown.items!)
        if (item.value case final type?) type.localizedName(l10n),
    ];
    final alphabetical = [...shown]
      ..sort((a, b) => normalize(a).compareTo(normalize(b)));
    expect(shown, hasLength(withChoices.length));
    expect(shown, alphabetical);
    expect(
      shown,
      isNot([for (final t in withChoices) t.localizedName(l10n)]),
      reason: 'the enum order must differ, or this test proves nothing',
    );
  });
}
