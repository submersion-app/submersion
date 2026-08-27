import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/forms/form_empty_row.dart';

void main() {
  testWidgets('renders the muted label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FormEmptyRow(label: 'No equipment yet')),
      ),
    );
    expect(find.text('No equipment yet'), findsOneWidget);
  });
}
