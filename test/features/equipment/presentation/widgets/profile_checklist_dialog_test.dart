import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/presentation/widgets/profile_checklist_dialog.dart';

import '../../../../helpers/test_app.dart';

void main() {
  final profiles = [
    Diver(
      id: 'wife',
      name: 'Anna',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    Diver(
      id: 'son',
      name: 'Tom',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];

  /// Opens the dialog and returns the pending result future.
  Future<Future<Set<String>?>> open(
    WidgetTester tester, {
    bool allowEmpty = true,
    Set<String> initial = const {},
  }) async {
    late Future<Set<String>?> result;
    await tester.pumpWidget(
      testApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showProfileChecklistDialog(
              context,
              title: 'Share with',
              body: 'Body',
              profiles: profiles,
              initiallySelected: initial,
              confirmLabel: 'Share',
              allowEmpty: allowEmpty,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('returns the checked profiles', (tester) async {
    final result = await open(tester);
    await tester.tap(find.text('Tom'));
    await tester.pump();
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(await result, {'son'});
  });

  testWidgets('cancel returns null', (tester) async {
    final result = await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets(
    'confirm is disabled with nothing checked when empty is not allowed',
    (tester) async {
      await open(tester, allowEmpty: false);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Share'),
      );
      expect(button.onPressed, isNull);
    },
  );

  testWidgets('starts from the initial selection', (tester) async {
    await open(tester, initial: {'wife'});
    final tile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Anna'),
    );
    expect(tile.value, isTrue);
  });
}
