import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_editor_header.dart';

/// The cylinder editor's header (issue #4962).
void main() {
  testWidgets('a menu item runs its own action even when the actions change '
      'while the menu is open', (tester) async {
    final ran = <String>[];
    TankHeaderAction action(String name) => TankHeaderAction(
      key: Key(name),
      icon: Icons.circle,
      label: name,
      onPressed: () => ran.add(name),
    );
    late StateSetter setOuter;
    var withOwn = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 160,
            child: StatefulBuilder(
              builder: (context, setState) {
                setOuter = setState;
                return TankEditorHeader(
                  leading: const SizedBox(width: 40),
                  title: 'Cylinder 3',
                  subtitle: 'EAN50',
                  actions: [
                    if (withOwn) action('own'),
                    action('scan'),
                    action('remove'),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('tank-actions-menu')));
    await tester.pumpAndSettle();
    // The diver's gear loads behind the open menu.
    setOuter(() => withOwn = true);
    await tester.pump();
    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();

    expect(ran, ['scan']);
  });

  testWidgets('a lone action stays a button however narrow, since a menu '
      'would take the same room', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            child: TankEditorHeader(
              leading: const SizedBox(width: 40),
              title: 'All tanks',
              subtitle: 'EAN32',
              actions: [
                TankHeaderAction(
                  key: const Key('scan'),
                  icon: Icons.circle,
                  label: 'scan',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('tank-actions-menu')), findsNothing);
    expect(
      find.descendant(
        of: find.byType(IconButton),
        matching: find.byIcon(Icons.circle),
      ),
      findsOneWidget,
    );
  });
}
