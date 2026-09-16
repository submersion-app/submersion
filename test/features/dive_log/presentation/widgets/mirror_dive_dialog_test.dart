import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/data/services/dive_mirror_service.dart';
import 'package:submersion/features/dive_log/presentation/widgets/mirror_dive_dialog.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/test_app.dart';

MirrorCandidate _candidate(String id, String name) => (
  buddy: Buddy(
    id: 'b-$id',
    name: name,
    linkedDiverId: id,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  diver: Diver(
    id: id,
    name: name,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
);

void main() {
  Future<List<String>?> open(
    WidgetTester tester,
    List<MirrorCandidate> candidates,
  ) async {
    List<String>? chosen;
    var settled = false;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              chosen = await showMirrorDiveDialog(
                context,
                candidates: candidates,
              );
              settled = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(settled, isFalse);
    return chosen;
  }

  testWidgets('lists candidates checked and returns the chosen diver ids', (
    tester,
  ) async {
    await open(tester, [
      _candidate('chris', 'Chris'),
      _candidate('dana', 'Dana'),
    ]);
    expect(find.text('Also log this dive in another profile?'), findsOneWidget);
    expect(find.text('Chris'), findsOneWidget);
    expect(find.text('Dana'), findsOneWidget);

    await tester.tap(find.text('Dana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();

    expect(find.text('Log'), findsNothing);
  });

  testWidgets('Log returns only the checked ids', (tester) async {
    List<String>? chosen;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              chosen = await showMirrorDiveDialog(
                context,
                candidates: [
                  _candidate('chris', 'Chris'),
                  _candidate('dana', 'Dana'),
                ],
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log'));
    await tester.pumpAndSettle();
    expect(chosen, ['chris']);
  });

  testWidgets('Not now returns null', (tester) async {
    List<String>? chosen = const ['sentinel'];
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              chosen = await showMirrorDiveDialog(
                context,
                candidates: [_candidate('chris', 'Chris')],
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(chosen, isNull);
  });

  testWidgets('Log is disabled once every candidate is unchecked', (
    tester,
  ) async {
    await open(tester, [_candidate('chris', 'Chris')]);
    await tester.tap(find.text('Chris'));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Log'),
    );
    expect(button.onPressed, isNull);
  });
}
