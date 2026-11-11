import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/services/assembly_totals.dart';
import 'package:submersion/features/equipment/presentation/providers/assembly_totals_provider.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_totals_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    AssemblyTotals totals, {
    WeightUnit unit = WeightUnit.kilograms,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(AppSettings(weightUnit: unit)),
          ),
          assemblyTotalsProvider('harness').overrideWith((ref) async => totals),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AssemblyTotalsSection(assemblyId: 'harness')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the summed buoyancy and dry weight in kg', (tester) async {
    await pump(
      tester,
      const AssemblyTotals(
        partCount: 2,
        buoyancy: (kg: -7.0, parts: 2),
        dryWeight: (kg: 0.6, parts: 2),
      ),
    );

    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Buoyancy'), findsOneWidget);
    expect(find.text('-7 kg'), findsOneWidget);
    expect(find.text('Dry weight'), findsOneWidget);
    expect(find.text('0.6 kg'), findsOneWidget);
    expect(find.textContaining('From '), findsNothing);
  });

  testWidgets('follows the diver weight unit', (tester) async {
    await pump(
      tester,
      const AssemblyTotals(partCount: 2, buoyancy: (kg: -7.0, parts: 2)),
      unit: WeightUnit.pounds,
    );

    expect(find.text('-15.43 lbs'), findsOneWidget);
  });

  testWidgets('says how many parts a partial sum is from', (tester) async {
    await pump(
      tester,
      const AssemblyTotals(partCount: 2, buoyancy: (kg: -4.0, parts: 1)),
    );

    expect(find.text('-4 kg'), findsOneWidget);
    expect(find.text('From 1 of 2 components'), findsOneWidget);
  });

  testWidgets('leaves out a measure no part declares', (tester) async {
    await pump(
      tester,
      const AssemblyTotals(partCount: 2, dryWeight: (kg: 0.6, parts: 2)),
    );

    expect(find.text('Dry weight'), findsOneWidget);
    expect(find.text('Buoyancy'), findsNothing);
  });

  testWidgets('shows nothing when no part declares either measure', (
    tester,
  ) async {
    await pump(tester, const AssemblyTotals(partCount: 2));

    expect(find.text('Total'), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });
}
