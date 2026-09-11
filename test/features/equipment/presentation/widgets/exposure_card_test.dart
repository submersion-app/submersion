import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_exposure_totals.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_exposure_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/exposure_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Widget host(EquipmentExposureTotals totals) => ProviderScope(
  overrides: [
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    equipmentExposureTotalsProvider('reg').overrideWith((ref) async => totals),
  ],
  child: const MaterialApp(
    locale: Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: ExposureCard(equipmentId: 'reg')),
  ),
);

void main() {
  // The date range and the decimal separator read the process-global
  // Intl.defaultLocale, which MaterialApp.locale does not set.
  late String? savedLocale;
  setUp(() {
    savedLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });
  tearDown(() => Intl.defaultLocale = savedLocale);

  testWidgets('shows one chip per non-zero unit and the dive footer', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        EquipmentExposureTotals(
          byUnit: const {
            ExposureUnit.dives: 3,
            ExposureUnit.hours: 3.25,
            ExposureUnit.coldDives: 1,
          },
          diveCount: 3,
          firstDive: DateTime(2026, 1, 10),
          lastDive: DateTime(2026, 3, 10),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Exposure'), findsOneWidget);
    expect(find.text('3 dives'), findsOneWidget);
    expect(find.text('3.3 hours'), findsOneWidget);
    expect(find.text('1 cold dive'), findsOneWidget);
    expect(find.textContaining('Deep'), findsNothing);
    expect(find.text('3 dives, Jan 10 - Mar 10, 2026'), findsOneWidget);
  });

  testWidgets('an item with no dives shows the empty line', (tester) async {
    await tester.pumpWidget(host(EquipmentExposureTotals.empty));
    await tester.pumpAndSettle();
    expect(find.text('No dives with this item yet'), findsOneWidget);
    expect(find.byType(Chip), findsNothing);
  });
  testWidgets('a days total never renders as a blank chip', (tester) async {
    // Days are a date trigger with no usage total, so the totals should
    // never carry them; if they do, the card skips them.
    await tester.pumpWidget(
      host(
        EquipmentExposureTotals(
          byUnit: const {ExposureUnit.days: 40, ExposureUnit.dives: 3},
          diveCount: 3,
          firstDive: DateTime(2026, 1, 10),
          lastDive: DateTime(2026, 3, 10),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Chip), findsOneWidget);
    expect(find.text('3 dives'), findsOneWidget);
  });

  testWidgets('hours use the locale decimal separator', (tester) async {
    Intl.defaultLocale = 'de';
    await tester.pumpWidget(
      host(
        EquipmentExposureTotals(
          byUnit: const {ExposureUnit.hours: 3.25},
          diveCount: 3,
          firstDive: DateTime(2026, 1, 10),
          lastDive: DateTime(2026, 3, 10),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('3,3'), findsOneWidget);
  });

  testWidgets('a failed load says so in words, never the raw error', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          equipmentExposureTotalsProvider(
            'reg',
          ).overrideWith((ref) async => throw StateError('db closed')),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ExposureCard(equipmentId: 'reg')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('db closed'), findsNothing);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });
}
