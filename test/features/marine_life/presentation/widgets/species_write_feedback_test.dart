import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_write_feedback.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('a failed write says so instead of throwing', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => saveWithFeedback(
              context,
              () async => throw StateError('disk full'),
            ),
            child: const Text('SAVE'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't save your changes. Nothing was changed."),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a write that works shows nothing', (tester) async {
    var ran = false;
    await tester.pumpWidget(
      testApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => saveWithFeedback(context, () async => ran = true),
            child: const Text('SAVE'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(ran, isTrue);
    expect(find.byType(SnackBar), findsNothing);
  });
}
