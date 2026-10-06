import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/presentation/widgets/currency_rule_edit_dialog.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The rule editor against built-in dive types the diver hid from the
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

  testWidgets('a hidden type the rule counted stays offered after it is '
      'unticked', (tester) async {
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
                onPressed: () => showCurrencyRuleEditDialog(
                  context,
                  editing: caveRule,
                  diverId: 'me',
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

    Future<void> openChecklist() async {
      final field = find.ancestor(
        of: find.text('Dive types'),
        matching: find.byType(InputDecorator),
      );
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
    }

    await openChecklist();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Cave'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await openChecklist();
    final cave = find.widgetWithText(CheckboxListTile, 'Cave');
    expect(cave, findsOneWidget);
    expect(tester.widget<CheckboxListTile>(cave).value, isFalse);
  });
}
