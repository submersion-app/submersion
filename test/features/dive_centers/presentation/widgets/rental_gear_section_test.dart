import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_gear_note_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/rental_gear_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  DiveCenterGearNote note(String id, EquipmentType type, {String? label}) =>
      DiveCenterGearNote(
        id: id,
        diveCenterId: 'c1',
        gearType: type,
        label: label,
        verdict: RentalVerdict.worked,
        notedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  Future<void> pump(WidgetTester tester, List<DiveCenterGearNote> notes) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          diveCenterGearNotesProvider('c1').overrideWith((ref) async => notes),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RentalGearSection(centerId: 'c1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('groups notes by gear type in the canonical order', (
    tester,
  ) async {
    await pump(tester, [
      note('n1', EquipmentType.fins, label: 'fins'),
      note('n2', EquipmentType.regulator, label: 'reg 14'),
      note('n3', EquipmentType.regulator, label: 'reg 9'),
    ]);
    expect(find.text('Rental gear'), findsOneWidget);
    final reg14 = tester.getTopLeft(find.text('reg 14'));
    final reg9 = tester.getTopLeft(find.text('reg 9'));
    final fins = tester.getTopLeft(find.text('fins'));
    // Regulators come before fins in the canonical order.
    expect(reg14.dy, lessThan(fins.dy));
    expect(reg9.dy, lessThan(fins.dy));
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('with no notes shows the empty line and the add button', (
    tester,
  ) async {
    await pump(tester, const []);
    expect(find.text('Rental gear'), findsOneWidget);
    expect(find.text('No rental notes for this center yet.'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('the add button opens the sheet', (tester) async {
    await pump(tester, const []);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('New rental note'), findsOneWidget);
  });

  testWidgets('a tapped note opens its editor', (tester) async {
    await pump(tester, [note('n1', EquipmentType.fins, label: 'fins')]);
    await tester.tap(find.text('fins'));
    await tester.pumpAndSettle();
    expect(find.text('Edit rental note'), findsOneWidget);
  });
}
