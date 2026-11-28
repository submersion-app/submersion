import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/contact_hours_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

/// The merge page's Contact group (issue #5073).
void main() {
  final l = AppLocalizationsEn();
  late List<TextEditingController> controllers;

  setUp(() => controllers = List.generate(4, (_) => TextEditingController()));

  tearDown(() {
    for (final c in controllers) {
      c.dispose();
    }
  });

  Widget harness() => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: ContactHoursSection(
          addressController: controllers[0],
          phoneController: controllers[1],
          emailController: controllers[2],
          websiteController: controllers[3],
          openingHours: null,
        ),
      ),
    ),
  );

  // The address spans lines, so Return starts a new one (review).
  testWidgets('the address takes line breaks', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    final address = find.descendant(
      of: find
          .ancestor(
            of: find.text(l.diveSites_edit_contact_address_label),
            matching: find.byType(Row),
          )
          .first,
      matching: find.byType(EditableText),
    );
    expect(
      tester.widget<EditableText>(address).keyboardType,
      TextInputType.multiline,
    );
    await tester.showKeyboard(address);
    expect(
      tester.testTextInput.setClientArgs!['inputAction'],
      TextInputAction.newline.toString(),
    );
  });
}
