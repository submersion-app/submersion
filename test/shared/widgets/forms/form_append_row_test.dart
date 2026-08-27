import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/forms/form_append_row.dart';

void main() {
  testWidgets('renders plus icon + label and fires onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Material(
            child: FormAppendRow(label: 'Add tank', onTap: () => tapped = true),
          ),
        ),
      ),
    );
    expect(find.text('Add tank'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    await tester.tap(find.text('Add tank'));
    expect(tapped, isTrue);
  });
}
