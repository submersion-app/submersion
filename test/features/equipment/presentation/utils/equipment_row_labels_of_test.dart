import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_label.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_labels_of.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  testWidgets('feeds the builder the localized strings and the date format', (
    tester,
  ) async {
    final items = [
      EquipmentItem(
        id: 'b',
        name: 'Pouches',
        type: EquipmentType.other,
        purchaseDate: DateTime(2025, 6, 1),
      ),
      EquipmentItem(
        id: 'a',
        name: 'Pouches',
        type: EquipmentType.other,
        purchaseDate: DateTime(2024, 3, 9),
      ),
    ];
    late Map<String, EquipmentRowLabel> labels;
    late String expectedDate;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              labels = equipmentRowLabelsOf(context, ref, items);
              expectedDate = UnitFormatter(
                ref.watch(settingsProvider),
              ).formatDate(DateTime(2024, 3, 9));
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(labels['a']!.subtitle, 'Bought $expectedDate');
  });
}
