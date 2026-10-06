import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/presentation/widgets/currency_mapping_dialog.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The "which dives count" dialog against built-ins the diver hid from the
/// pickers (issue #401).
void main() {
  final t0 = DateTime(2026);

  DiveTypeEntity type(String id, String name) => DiveTypeEntity(
    id: id,
    name: name,
    isBuiltIn: true,
    createdAt: t0,
    updatedAt: t0,
  );

  final caveRule = CurrencyRule(
    id: 'cave_currency',
    name: 'Cave currency',
    clockKind: CurrencyClockKind.activity,
    lapseDays: 365,
    leadDays: 90,
    countedDiveTypeIds: const ['cave', 'cavern'],
    isBuiltIn: true,
    createdAt: t0,
    updatedAt: t0,
  );

  Future<void> openDialog(
    WidgetTester tester, {
    CurrencyRule? rule,
    List<String>? types,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(
              const AppSettings(
                hiddenBuiltInIds: {
                  'diveTypes': {'cave'},
                },
              ),
            ),
          ),
          diveTypesProvider.overrideWith(
            (ref) async => [
              type('cave', 'Cave'),
              type('cavern', 'Cavern'),
              type('wreck', 'Wreck'),
            ],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showCurrencyMappingDialog(
                  context,
                  rule: rule ?? caveRule,
                  types: types,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Open the dive type checklist.
    await tester.tap(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a hidden type the rule counts by default stays offered after '
      'the card stopped counting it', (tester) async {
    await openDialog(tester, types: ['cavern']);

    expect(find.widgetWithText(CheckboxListTile, 'Cave'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Wreck'), findsOneWidget);
  });

  testWidgets('a hidden type neither the rule nor the card counts stays out', (
    tester,
  ) async {
    final wreckOnly = caveRule.copyWith(countedDiveTypeIds: const ['wreck']);
    await openDialog(tester, rule: wreckOnly);

    expect(find.widgetWithText(CheckboxListTile, 'Wreck'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Cave'), findsNothing);
  });
}
