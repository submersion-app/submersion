import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/presentation/widgets/custom_field_input_row.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/contrast_ratio.dart';

Widget _host({
  required DiveCustomField field,
  required List<String> keySuggestions,
  required ValueChanged<DiveCustomField> onChanged,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: CustomFieldInputRow(
        index: 0,
        field: field,
        keySuggestions: keySuggestions,
        onChanged: onChanged,
        onDelete: () {},
      ),
    ),
  );
}

void main() {
  testWidgets('the key field offers matching suggestions', (tester) async {
    await tester.pumpWidget(
      _host(
        field: const DiveCustomField(id: 'f1', key: '', value: ''),
        keySuggestions: const ['Visibility', 'Vis notes', 'Current'],
        onChanged: (_) {},
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'Vis');
    await tester.pumpAndSettle();

    expect(find.text('Visibility'), findsOneWidget);
    expect(find.text('Vis notes'), findsOneWidget);
    expect(find.text('Current'), findsNothing);
  });

  testWidgets('arrow keys and Enter commit a highlighted key suggestion', (
    tester,
  ) async {
    DiveCustomField? changed;
    await tester.pumpWidget(
      _host(
        field: const DiveCustomField(id: 'f1', key: '', value: ''),
        keySuggestions: const ['Visibility', 'Vis notes', 'Current'],
        onChanged: (field) => changed = field,
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'Vis');
    await tester.pumpAndSettle();

    // Move off the first option, then commit with Enter. Without the field
    // forwarding onFieldSubmitted this leaves the typed text in place.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(changed, isNotNull);
    expect(changed!.key, 'Vis notes');
  });

  // The drag handle was fixed Colors.grey, about 2.5:1 on a light surface.
  testWidgets('the drag handle reads on the surface', (tester) async {
    await tester.pumpWidget(
      _host(
        field: const DiveCustomField(id: 'f1', key: '', value: ''),
        keySuggestions: const [],
        onChanged: (_) {},
      ),
    );

    final handle = find.byIcon(Icons.drag_handle);
    final color = tester.widget<Icon>(handle).color!;
    final surface = Theme.of(tester.element(handle)).colorScheme.surface;
    expect(contrastRatio(color, surface), greaterThanOrEqualTo(3.0));
  });
}
