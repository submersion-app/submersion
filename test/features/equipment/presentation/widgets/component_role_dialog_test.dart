import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/presentation/widgets/component_role_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Widget host(void Function(BuildContext) onOpen) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => onOpen(context),
          child: const Text('open'),
        ),
      ),
    ),
  );

  testWidgets('returns the trimmed text on Save', (tester) async {
    String? result = 'unset';
    await tester.pumpWidget(
      host((context) async {
        result = await showComponentRoleDialog(
          context,
          initial: 'Primary',
          suggestions: const ['Necklace'],
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Backup  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result, 'Backup');
  });

  testWidgets('a suggestion chip fills the field', (tester) async {
    String? result;
    await tester.pumpWidget(
      host((context) async {
        result = await showComponentRoleDialog(
          context,
          initial: '',
          suggestions: const ['Necklace'],
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Necklace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result, 'Necklace');
  });

  testWidgets('returns null on Cancel', (tester) async {
    String? result = 'unset';
    await tester.pumpWidget(
      host((context) async {
        result = await showComponentRoleDialog(
          context,
          initial: 'Primary',
          suggestions: const [],
        );
      }),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
