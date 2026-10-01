import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/tile_subtitle_action.dart';

void main() {
  Future<void> pumpTile(WidgetTester tester, {VoidCallback? onPressed}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Backup location'),
              subtitle: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('/Users/diver/Backups'),
                  TileSubtitleAction(label: 'Change', onPressed: onPressed),
                ],
              ),
            ),
          ),
        ),
      );

  testWidgets('lines its label up with the subtitle text above it', (
    tester,
  ) async {
    await pumpTile(tester, onPressed: () {});

    final subtitle = tester.getRect(find.text('/Users/diver/Backups'));
    final label = tester.getRect(find.text('Change'));
    expect(label.left, subtitle.left);
    expect(label.top, greaterThanOrEqualTo(subtitle.bottom));
  });

  testWidgets('sizes to its button where the parent allows it', (tester) async {
    await pumpTile(tester, onPressed: () {});

    expect(
      tester.getRect(find.byType(TileSubtitleAction)),
      tester.getRect(find.byType(TextButton)),
    );
  });

  testWidgets('puts actionKey on the button, so tapping the key runs the '
      'action even as the whole subtitle', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListTile(
            title: const Text('No site'),
            // As the whole subtitle the widget gets the full line width.
            subtitle: TileSubtitleAction(
              actionKey: const ValueKey('choose-site'),
              label: 'Choose site',
              onPressed: () => taps++,
            ),
          ),
        ),
      ),
    );

    final key = find.byKey(const ValueKey('choose-site'));
    expect(tester.widget(key), isA<TextButton>());
    await tester.tap(key);
    expect(taps, 1);
  });

  testWidgets('runs its action when tapped', (tester) async {
    var taps = 0;
    await pumpTile(tester, onPressed: () => taps++);

    await tester.tap(find.text('Change'));

    expect(taps, 1);
  });

  testWidgets('is a disabled text button when there is no action', (
    tester,
  ) async {
    await pumpTile(tester);

    final button = tester.widget<TextButton>(find.byType(TextButton));
    expect(button.onPressed, isNull);
  });
}
