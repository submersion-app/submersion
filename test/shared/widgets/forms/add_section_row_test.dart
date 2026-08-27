import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/add_section_row.dart';

void main() {
  testWidgets('renders entries and fires their callbacks', (tester) async {
    String? tapped;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AddSectionRow(
            entries: [
              AddSectionEntry(label: 'Course', onTap: () => tapped = 'course'),
              AddSectionEntry(
                label: 'Custom fields',
                onTap: () => tapped = 'custom',
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.textContaining('Add:'), findsOneWidget);
    await tester.tap(find.text('Course'));
    expect(tapped, 'course');
    await tester.tap(find.text('Custom fields'));
    expect(tapped, 'custom');
  });

  testWidgets('renders nothing when all entries used', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: AddSectionRow(entries: [])),
      ),
    );
    expect(find.textContaining('Add:'), findsNothing);
  });
}
