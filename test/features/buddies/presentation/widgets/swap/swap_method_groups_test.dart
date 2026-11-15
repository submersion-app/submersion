import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/presentation/widgets/swap/swap_method_groups.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Future<void> _pump(WidgetTester tester, Widget group) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ListView(children: [group])),
    ),
  );
}

/// The two groups of ways to swap on the swap screen (issues #3728, #4598).
void main() {
  testWidgets('Send as a file hands over the row rectangle for the iPad '
      'share popover', (tester) async {
    Rect? anchor;
    await _pump(
      tester,
      GiveCardGroup(
        onShowCode: () {},
        onSendFile: (rect) => anchor = rect,
        onWriteSticker: () {},
      ),
    );
    await tester.tap(find.text('Send as a file'));
    expect(anchor, isNotNull);
    expect(
      anchor,
      tester.getRect(find.widgetWithText(ListTile, 'Send as a file')),
    );
  });

  testWidgets('each Give row calls its callback', (tester) async {
    final calls = <String>[];
    await _pump(
      tester,
      GiveCardGroup(
        onShowCode: () => calls.add('code'),
        onSendFile: (_) => calls.add('file'),
        onWriteSticker: () => calls.add('sticker'),
      ),
    );
    expect(find.text('Give your card'), findsOneWidget);
    expect(find.text('Your buddy scans it'), findsOneWidget);
    await tester.tap(find.text('Show my code'));
    await tester.tap(find.text('Send as a file'));
    await tester.tap(find.text('Write an NFC sticker'));
    expect(calls, ['code', 'file', 'sticker']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('each Get row calls its callback', (tester) async {
    final calls = <String>[];
    await _pump(
      tester,
      GetCardGroup(
        onScanCode: () => calls.add('scan'),
        onOpenFile: () => calls.add('open'),
        onReadTag: () => calls.add('tag'),
      ),
    );
    expect(find.text('Get their card'), findsOneWidget);
    await tester.tap(find.text('Scan their code'));
    await tester.tap(find.text('Open a card file'));
    await tester.tap(find.text('Receive by tap'));
    expect(calls, ['scan', 'open', 'tag']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('on macOS neither group offers NFC', (tester) async {
    await _pump(
      tester,
      Column(
        children: [
          GiveCardGroup(
            onShowCode: () {},
            onSendFile: (_) {},
            onWriteSticker: () {},
          ),
          GetCardGroup(onScanCode: () {}, onOpenFile: () {}, onReadTag: () {}),
        ],
      ),
    );
    expect(find.text('Show my code'), findsOneWidget);
    expect(find.text('Scan their code'), findsOneWidget);
    expect(find.text('Write an NFC sticker'), findsNothing);
    expect(find.text('Receive by tap'), findsNothing);
    expect(find.text('Tap an Android phone'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('iOS shows Tap an Android phone, and it reads a tag', (
    tester,
  ) async {
    var reads = 0;
    await _pump(
      tester,
      GetCardGroup(
        onScanCode: () {},
        onOpenFile: () {},
        onReadTag: () => reads++,
      ),
    );
    expect(find.text('Receive by tap'), findsNothing);
    await tester.tap(find.text('Tap an Android phone'));
    expect(reads, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
