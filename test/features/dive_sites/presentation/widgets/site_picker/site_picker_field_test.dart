import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_field.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_picker/site_picker_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

const _sites = [
  DiveSite(id: 's1', name: 'Blue Hole', country: 'Egypt', city: 'Dahab'),
  DiveSite(id: 's2', name: 'Coral Garden', country: 'Mexico'),
];

Future<List<String?>> _pump(WidgetTester tester, String? value) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(500, 900);
  addTearDown(tester.view.reset);
  final changes = <String?>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        sitesProvider.overrideWith((ref) async => _sites),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: SitePickerField(value: value, onChanged: changes.add),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return changes;
}

void main() {
  testWidgets('shows All sites when nothing is selected', (tester) async {
    await _pump(tester, null);
    expect(find.text('All sites'), findsOneWidget);
    expect(find.text('Dive Site'), findsOneWidget);
    expect(find.byTooltip('Clear site filter'), findsNothing);
  });

  testWidgets('shows the selected site with its location', (tester) async {
    await _pump(tester, 's1');
    expect(find.text('Blue Hole'), findsOneWidget);
    expect(find.text('Dahab · Egypt'), findsOneWidget);
  });

  testWidgets('a deleted site id shows All sites but stays clearable', (
    tester,
  ) async {
    final changes = await _pump(tester, 'gone');
    expect(find.text('All sites'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear site filter'));
    await tester.pumpAndSettle();
    expect(changes, [null]);
  });

  testWidgets('tapping opens the sheet, searching and picking sets the id', (
    tester,
  ) async {
    final changes = await _pump(tester, null);
    await tester.tap(find.byKey(sitePickerFieldKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'mexico');
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(sitePickerListKey),
        matching: find.text('Coral Garden'),
      ),
    );
    await tester.pumpAndSettle();
    expect(changes, ['s2']);
  });

  testWidgets('All sites in the sheet clears the filter', (tester) async {
    final changes = await _pump(tester, 's1');
    await tester.tap(find.byKey(sitePickerFieldKey));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(sitePickerListKey),
        matching: find.text('All sites'),
      ),
    );
    await tester.pumpAndSettle();
    expect(changes, [null]);
  });

  testWidgets('dismissing the sheet changes nothing', (tester) async {
    final changes = await _pump(tester, 's1');
    await tester.tap(find.byKey(sitePickerFieldKey));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(250, 20));
    await tester.pumpAndSettle();
    expect(changes, isEmpty);
  });

  testWidgets('the clear button clears without opening the sheet', (
    tester,
  ) async {
    final changes = await _pump(tester, 's1');
    await tester.tap(find.byTooltip('Clear site filter'));
    await tester.pumpAndSettle();
    expect(changes, [null]);
    expect(find.byKey(sitePickerListKey), findsNothing);
  });
}
