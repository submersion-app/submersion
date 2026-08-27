import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/suggestion_field.dart';

import '../../../../helpers/test_app.dart';

void main() {
  group('SuggestionField', () {
    testWidgets('shows substring matches as the user types', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: const SuggestionField(
            suggestions: ['Indonesia', 'India', 'Egypt'],
            decoration: InputDecoration(labelText: 'Country'),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'ind');
      await tester.pumpAndSettle();

      expect(find.text('Indonesia'), findsOneWidget);
      expect(find.text('India'), findsOneWidget);
      expect(find.text('Egypt'), findsNothing);
    });

    testWidgets('writes the selection into an external controller', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        testApp(
          child: SuggestionField(
            controller: controller,
            suggestions: const ['Indonesia', 'India'],
            decoration: const InputDecoration(labelText: 'Country'),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'indo');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Indonesia').last);
      await tester.pumpAndSettle();

      expect(controller.text, 'Indonesia');
    });

    testWidgets('surfaces fuzzy near-matches when enableFuzzy is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: const SuggestionField(
            suggestions: ['Manta Point'],
            enableFuzzy: true,
            decoration: InputDecoration(labelText: 'Site'),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'Manta Pt');
      await tester.pumpAndSettle();

      expect(find.text('Manta Point'), findsOneWidget);
    });
  });
}
