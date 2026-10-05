import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The type dropdown lists every type alphabetically by its localized label,
/// not in the enum's declaration order (#2937).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<void> pumpEditor(WidgetTester tester, Locale locale) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 4000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          equipmentRepositoryProvider.overrideWithValue(EquipmentRepository()),
        ].cast(),
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: EquipmentEditPage(equipmentId: null, embedded: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> dropdownLabels(WidgetTester tester, AppLocalizations l10n) {
    final dropdown = tester.widget<DropdownButton<EquipmentType>>(
      find.byType(DropdownButton<EquipmentType>),
    );
    return [
      for (final item in dropdown.items!) item.value!.localizedName(l10n),
    ];
  }

  // French labels the transmitter with a leading accent, which must sort
  // by its base letter.
  for (final locale in const [Locale('en'), Locale('de'), Locale('fr')]) {
    testWidgets('offers every type alphabetically in $locale', (tester) async {
      await pumpEditor(tester, locale);
      final l10n = lookupAppLocalizations(locale);

      final shown = dropdownLabels(tester, l10n);
      final alphabetical = [...shown]
        ..sort((a, b) => normalize(a).compareTo(normalize(b)));
      expect(shown, hasLength(EquipmentType.values.length));
      expect(shown, alphabetical);
      // Guards against a vacuous pass: the enum order is not alphabetical.
      expect(
        shown,
        isNot([for (final t in EquipmentType.values) t.localizedName(l10n)]),
      );
    });
  }
}
