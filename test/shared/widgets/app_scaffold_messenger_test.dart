import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/app_scaffold_messenger.dart';
import 'package:submersion/shared/widgets/sheet_messenger_scope.dart';

void main() {
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  ScaffoldMessengerState messenger() => messengerKey.currentState!;

  Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppScaffoldMessenger(
        key: messengerKey,
        child: const Scaffold(body: SizedBox.expand()),
      ),
    ),
  );

  /// Lets a snack bar finish sliding in, which is also what starts its timer.
  Future<void> settleEntrance(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  final dismissAll = find.text('Dismiss all');

  testWidgets('a lone message offers no Dismiss all', (tester) async {
    await pumpApp(tester);

    messenger().showSnackBar(const SnackBar(content: Text('one')));
    await settleEntrance(tester);

    expect(find.text('one'), findsOneWidget);
    expect(dismissAll, findsNothing);
  });

  testWidgets('Dismiss all appears once another message is waiting', (
    tester,
  ) async {
    await pumpApp(tester);

    messenger().showSnackBar(const SnackBar(content: Text('one')));
    await settleEntrance(tester);
    expect(dismissAll, findsNothing);

    messenger().showSnackBar(const SnackBar(content: Text('two')));
    await tester.pump();

    expect(find.text('one'), findsOneWidget);
    expect(dismissAll, findsOneWidget);
  });

  testWidgets('Dismiss all clears the message showing and all those waiting', (
    tester,
  ) async {
    await pumpApp(tester);

    messenger().showSnackBar(
      SnackBar(
        content: const Text('one'),
        action: SnackBarAction(label: 'Undo', onPressed: () {}),
        persist: false,
      ),
    );
    messenger().showSnackBar(const SnackBar(content: Text('two')));
    messenger().showSnackBar(const SnackBar(content: Text('three')));
    await settleEntrance(tester);

    await tester.tap(dismissAll);
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('every message told about a Dismiss all hears it was dismissed', (
    tester,
  ) async {
    await pumpApp(tester);

    // A message that drops a held undo snapshot does so on `closed`, so one
    // that never completes would keep that snapshot for good.
    final closed = [
      messenger().showSnackBar(const SnackBar(content: Text('one'))).closed,
      messenger().showSnackBar(const SnackBar(content: Text('two'))).closed,
      messenger().showSnackBar(const SnackBar(content: Text('three'))).closed,
    ];
    await settleEntrance(tester);

    await tester.tap(dismissAll);
    await tester.pumpAndSettle();

    expect(await Future.wait(closed), [
      SnackBarClosedReason.dismiss,
      SnackBarClosedReason.dismiss,
      SnackBarClosedReason.dismiss,
    ]);
  });

  testWidgets('Dismiss all works while the message on show is sliding out', (
    tester,
  ) async {
    await pumpApp(tester);

    final closed = [
      for (final text in ['one', 'two', 'three'])
        messenger()
            .showSnackBar(SnackBar(content: Text(text), showCloseIcon: true))
            .closed,
    ];
    await settleEntrance(tester);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(dismissAll);
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(await Future.wait(closed), [
      SnackBarClosedReason.dismiss,
      SnackBarClosedReason.dismiss,
      SnackBarClosedReason.dismiss,
    ]);
  });

  testWidgets('the button goes once only one message is left', (tester) async {
    await pumpApp(tester);

    messenger().showSnackBar(
      const SnackBar(content: Text('one'), showCloseIcon: true),
    );
    messenger().showSnackBar(
      const SnackBar(content: Text('two'), showCloseIcon: true),
    );
    await settleEntrance(tester);
    expect(dismissAll, findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('two'), findsOneWidget);
    expect(dismissAll, findsNothing);
  });

  testWidgets('the framework clear leaves no phantom message behind', (
    tester,
  ) async {
    await pumpApp(tester);

    messenger().showSnackBar(const SnackBar(content: Text('one')));
    messenger().showSnackBar(const SnackBar(content: Text('two')));
    messenger().showSnackBar(const SnackBar(content: Text('three')));
    await settleEntrance(tester);

    messenger().clearSnackBars();
    await tester.pumpAndSettle();
    messenger().showSnackBar(const SnackBar(content: Text('four')));
    await settleEntrance(tester);

    expect(find.text('four'), findsOneWidget);
    expect(dismissAll, findsNothing);
  });

  testWidgets('a message with an action still times out when it says so', (
    tester,
  ) async {
    await pumpApp(tester);

    messenger().showSnackBar(
      SnackBar(
        content: const Text('one'),
        action: SnackBarAction(label: 'Undo', onPressed: () {}),
        persist: false,
        duration: const Duration(seconds: 5),
      ),
    );
    await settleEntrance(tester);
    expect(find.text('one'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a clear followed by a new message offers no Dismiss all', (
    tester,
  ) async {
    await pumpApp(tester);

    messenger().showSnackBar(const SnackBar(content: Text('one')));
    await settleEntrance(tester);

    messenger()
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('two')));
    await tester.pump();

    expect(find.text('one'), findsOneWidget, reason: 'still sliding out');
    expect(dismissAll, findsNothing);
  });

  testWidgets('a screen reader user keeps a message with an action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(accessibleNavigation: true),
          child: child!,
        ),
        home: AppScaffoldMessenger(
          key: messengerKey,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    messenger().showSnackBar(
      SnackBar(
        content: const Text('one'),
        action: SnackBarAction(label: 'Undo', onPressed: () {}),
        persist: false,
        duration: const Duration(seconds: 5),
      ),
    );
    await settleEntrance(tester);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(find.text('one'), findsOneWidget);
  });

  testWidgets('a screen reader user still has plain messages time out', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(accessibleNavigation: true),
          child: child!,
        ),
        home: AppScaffoldMessenger(
          key: messengerKey,
          child: const Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    messenger().showSnackBar(
      const SnackBar(content: Text('one'), duration: Duration(seconds: 5)),
    );
    await settleEntrance(tester);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('the shown snack bar keeps everything the caller set', (
    tester,
  ) async {
    await pumpApp(tester);

    const key = Key('message');
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(3),
    );
    void onVisible() {}
    final action = SnackBarAction(label: 'Undo', onPressed: () {});
    messenger().showSnackBar(
      SnackBar(
        key: key,
        content: const Text('one'),
        backgroundColor: Colors.teal,
        elevation: 2,
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.all(5),
        shape: shape,
        hitTestBehavior: HitTestBehavior.opaque,
        behavior: SnackBarBehavior.floating,
        action: action,
        actionOverflowThreshold: 0.5,
        showCloseIcon: true,
        closeIconColor: Colors.pink,
        duration: const Duration(seconds: 7),
        persist: false,
        onVisible: onVisible,
        dismissDirection: DismissDirection.endToStart,
        clipBehavior: Clip.antiAlias,
      ),
    );
    await settleEntrance(tester);

    final shown = tester.widget<SnackBar>(find.byKey(key));
    expect(shown.backgroundColor, Colors.teal);
    expect(shown.elevation, 2);
    expect(shown.margin, const EdgeInsets.all(3));
    expect(shown.padding, const EdgeInsets.all(5));
    expect(shown.shape, shape);
    expect(shown.hitTestBehavior, HitTestBehavior.opaque);
    expect(shown.behavior, SnackBarBehavior.floating);
    expect(shown.action, same(action));
    expect(shown.actionOverflowThreshold, 0.5);
    expect(shown.showCloseIcon, isTrue);
    expect(shown.closeIconColor, Colors.pink);
    expect(shown.duration, const Duration(seconds: 7));
    expect(shown.persist, isFalse);
    expect(shown.onVisible, same(onVisible));
    expect(shown.dismissDirection, DismissDirection.endToStart);
    expect(shown.clipBehavior, Clip.antiAlias);
  });

  testWidgets('a width survives, since it cannot sit beside a margin', (
    tester,
  ) async {
    await pumpApp(tester);

    messenger().showSnackBar(
      const SnackBar(
        key: Key('message'),
        content: Text('one'),
        width: 320,
        behavior: SnackBarBehavior.floating,
      ),
    );
    await settleEntrance(tester);

    expect(
      tester.widget<SnackBar>(find.byKey(const Key('message'))).width,
      320,
    );
  });

  testWidgets('a lone message lays out exactly as the caller wrote it', (
    tester,
  ) async {
    await pumpApp(tester);

    // The default content slot hands its child a tight width, which a
    // message laying out a Row with an Expanded relies on.
    messenger().showSnackBar(
      const SnackBar(
        content: SizedBox(key: Key('content'), height: 10),
        padding: EdgeInsets.zero,
      ),
    );
    await settleEntrance(tester);

    expect(tester.getSize(find.byKey(const Key('content'))).width, 800);
  });

  testWidgets('messages raised inside a sheet can be dismissed together', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SheetMessengerScope(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context)
                    ..showSnackBar(const SnackBar(content: Text('one')))
                    ..showSnackBar(const SnackBar(content: Text('two')));
                },
                child: const Text('toast'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('toast'));
    await settleEntrance(tester);
    await tester.tap(dismissAll);
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
  });
}
