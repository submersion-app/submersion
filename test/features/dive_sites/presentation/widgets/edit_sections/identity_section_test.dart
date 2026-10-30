import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/identity_section.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';

import '../../../../../helpers/test_app.dart';

/// The site edit page's identity group: names and places, plus the Markdown
/// description (#3683).
void main() {
  final controllers = List.generate(7, (_) => TextEditingController());
  tearDownAll(() {
    for (final c in controllers) {
      c.dispose();
    }
  });

  testWidgets('the description capitalises sentences, the names words', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: SingleChildScrollView(
          child: IdentitySection(
            allSites: const [],
            nameController: controllers[0],
            descriptionController: controllers[1],
            countryController: controllers[2],
            regionController: controllers[3],
            cityController: controllers[4],
            islandController: controllers[5],
            bodyOfWaterController: controllers[6],
            nameValidator: (_) => null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    TextCapitalization capitalisationOf(TextEditingController c) => tester
        .widget<EditableText>(
          find.byWidgetPredicate(
            (w) => w is EditableText && identical(w.controller, c),
          ),
        )
        .textCapitalization;

    expect(find.byType(MarkdownNotesField), findsOneWidget);
    expect(capitalisationOf(controllers[1]), TextCapitalization.sentences);
    expect(capitalisationOf(controllers[0]), TextCapitalization.words);
  });
}
