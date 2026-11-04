import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/data_quality/presentation/widgets/set_primary_source_dialog.dart';

import '../../../helpers/l10n_test_helpers.dart';

void main() {
  Future<List<bool>> open(WidgetTester tester, {String? source}) async {
    final answers = <bool>[];
    await tester.pumpWidget(
      localizedMaterialApp(
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async => answers.add(
                await confirmSetPrimarySource(context, source: source),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return answers;
  }

  // The repair has no snackbar undo, so it names the source it promotes
  // and waits for a yes (issue #4209).
  testWidgets('names the source and confirms on the confirm button', (
    tester,
  ) async {
    final answers = await open(tester, source: 'Shearwater Perdix 2');
    expect(
      find.text('Make Shearwater Perdix 2 the primary source?'),
      findsOneWidget,
    );
    expect(
      find.textContaining('come from Shearwater Perdix 2'),
      findsOneWidget,
    );

    await tester.tap(find.text('Make primary'));
    await tester.pumpAndSettle();
    expect(answers, [true]);
  });

  testWidgets('cancel answers no', (tester) async {
    final answers = await open(tester, source: 'Shearwater Perdix 2');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(answers, [false]);
  });

  testWidgets('dismissing the dialog answers no', (tester) async {
    final answers = await open(tester, source: 'Shearwater Perdix 2');
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(answers, [false]);
  });

  testWidgets('an unnamed source still asks, in general terms', (tester) async {
    await open(tester);
    expect(find.text('Make this source primary'), findsOneWidget);
    expect(find.textContaining('come from this source'), findsOneWidget);
  });
}
