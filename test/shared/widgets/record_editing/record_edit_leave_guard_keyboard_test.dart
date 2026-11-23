import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_leave_guard.dart';

// On Android, the system Back is also the key that hides the on-screen
// keyboard. A Back that reaches the page while the keyboard is up closes
// the keyboard and nothing else: it neither leaves the page nor asks
// about unsaved changes (#4961).

@immutable
class _Rec {
  const _Rec({this.notes = ''});

  final String notes;

  @override
  bool operator ==(Object other) => other is _Rec && other.notes == notes;

  @override
  int get hashCode => notes.hashCode;
}

final _notes = EditField<_Rec, String>(
  id: 'notes',
  cardId: 'notes',
  read: (r) => r.notes,
  write: (r, v) => _Rec(notes: v),
);

const _field = ValueKey('a field');
const _otherField = ValueKey('a field on a page above');

/// The app as it runs: a router, so the system Back goes through its back
/// button dispatcher before any route hears of it. Home pushes the guarded
/// record page, which can push a page of its own above it. With
/// [inShellBody] the page sits in another Scaffold's body, as the shell's
/// pages do, where MediaQuery has the keyboard's inset taken out.
Future<RecordEditController<_Rec>> _open(
  WidgetTester tester, {
  bool inShellBody = false,
}) async {
  final controller = RecordEditController<_Rec>(onSave: (_) async {});
  addTearDown(controller.dispose);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/record'),
            child: const Text('open'),
          ),
        ),
      ),
      GoRoute(
        path: '/record',
        builder: (context, _) => _shell(
          inShellBody,
          RecordEditLeaveGuard<_Rec>(
            controller: controller,
            child: Scaffold(
              appBar: AppBar(title: const Text('Record')),
              body: Column(
                children: [
                  const TextField(key: _field),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Above')),
                          body: const TextField(key: _otherField),
                        ),
                      ),
                    ),
                    child: const Text('push a page'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.text('Record'), findsOneWidget);
  return controller;
}

Widget _shell(bool inShellBody, Widget page) =>
    inShellBody ? Scaffold(body: page) : page;

/// Puts the caret in [field] and, when [keyboardUp], the on-screen
/// keyboard over the bottom of the window, as Android does.
Future<void> _typeIn(
  WidgetTester tester,
  Key field, {
  bool keyboardUp = true,
}) async {
  await tester.showKeyboard(find.byKey(field));
  if (keyboardUp) {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
  }
  await tester.pump();
  expect(_focused(tester, field), isTrue);
}

bool _focused(WidgetTester tester, Key field) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(field),
        matching: find.byType(EditableText),
      ),
    )
    .focusNode
    .hasFocus;

/// What the keyboard closing does to the window.
Future<void> _keyboardGoes(WidgetTester tester) async {
  tester.view.resetViewInsets();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('with changes, Back with the keyboard up only closes it', (
    tester,
  ) async {
    final controller = await _open(tester);
    controller.unlock(const _Rec());
    controller.session!.set(_notes, 'changed');
    await _typeIn(tester, _field);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Record'), findsOneWidget);
    expect(_focused(tester, _field), isFalse);
    expect(controller.isUnlocked, isTrue);
    expect(controller.isDirty, isTrue);
  });

  testWidgets('in a Scaffold body (the shell), where MediaQuery hides the '
      'keyboard, Back with it up still only closes it', (tester) async {
    final controller = await _open(tester, inShellBody: true);
    controller.unlock(const _Rec());
    controller.session!.set(_notes, 'changed');
    await _typeIn(tester, _field);
    expect(
      MediaQuery.viewInsetsOf(tester.element(find.byKey(_field))).bottom,
      0,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Record'), findsOneWidget);
    expect(_focused(tester, _field), isFalse);
  });

  testWidgets('with changes, the Back after the keyboard is gone asks', (
    tester,
  ) async {
    final controller = await _open(tester);
    controller.unlock(const _Rec());
    controller.session!.set(_notes, 'changed');
    await _typeIn(tester, _field);

    await tester.binding.handlePopRoute();
    await _keyboardGoes(tester);
    expect(find.text('Discard changes?'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    // Keep editing does not set off the question again.
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Record'), findsOneWidget);
    expect(controller.isDirty, isTrue);
  });

  testWidgets('with no changes, Back with the keyboard up stays on the page', (
    tester,
  ) async {
    final controller = await _open(tester);
    controller.unlock(const _Rec());
    await _typeIn(tester, _field);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Record'), findsOneWidget);
    expect(_focused(tester, _field), isFalse);
    expect(controller.isUnlocked, isTrue);
  });

  testWidgets('a field focused with no keyboard on screen (a hardware '
      'keyboard) leaves Back as it was: with changes it asks', (tester) async {
    final controller = await _open(tester);
    controller.unlock(const _Rec());
    controller.session!.set(_notes, 'changed');
    await _typeIn(tester, _field, keyboardUp: false);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
  });

  testWidgets('the app bar back arrow with the keyboard up still asks', (
    tester,
  ) async {
    final controller = await _open(tester);
    controller.unlock(const _Rec());
    controller.session!.set(_notes, 'changed');
    await _typeIn(tester, _field);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
  });

  testWidgets('the app bar back arrow with the keyboard up and no changes '
      'leaves and locks', (tester) async {
    final controller = await _open(tester);
    controller.unlock(const _Rec());
    await _typeIn(tester, _field);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Record'), findsNothing);
    expect(controller.isUnlocked, isFalse);
  });

  testWidgets('a page above with its own keyboard up is left to its own '
      'Back', (tester) async {
    final controller = await _open(tester);
    controller.unlock(const _Rec());
    controller.session!.set(_notes, 'changed');
    await tester.tap(find.text('push a page'));
    await tester.pumpAndSettle();
    await _typeIn(tester, _otherField);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Above'), findsNothing);
    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Discard changes?'), findsNothing);
  });

  testWidgets('locked, Back with the keyboard up only closes it', (
    tester,
  ) async {
    final controller = await _open(tester);
    await _typeIn(tester, _field);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Record'), findsOneWidget);
    expect(_focused(tester, _field), isFalse);
    expect(controller.isUnlocked, isFalse);
  });
}
