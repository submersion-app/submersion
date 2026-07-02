import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  testWidgets('TheDiveSection renders a Name row bound to its controller', (
    tester,
  ) async {
    final nameController = TextEditingController();
    addTearDown(nameController.dispose);
    final controllers = List.generate(5, (_) => TextEditingController());
    for (final c in controllers) {
      addTearDown(c.dispose);
    }

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TheDiveSection(
              depthSymbol: 'm',
              nameController: nameController,
              maxDepthController: controllers[0],
              avgDepthController: controllers[1],
              bottomTimeController: controllers[2],
              runtimeController: controllers[3],
              diveNumberController: controllers[4],
              entryText: 'Jul 1, 2026',
              onEditEntry: () {},
              exitText: null,
              onEditExit: () {},
              siteName: null,
              onPickSite: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Name'), findsOneWidget);

    // FormRow.text rows render a read-only value/placeholder row until
    // tapped, then swap in a real TextFormField for editing.
    await tester.tap(find.text('Optional name for this dive'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'Wreck penetration dive',
    );
    expect(nameController.text, 'Wreck penetration dive');
  });
}
