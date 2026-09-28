import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/accessibility/app_shortcuts.dart';
import 'package:submersion/core/accessibility/not_while_typing_activator.dart';
import 'package:submersion/core/accessibility/shortcut_registry.dart';
import 'package:submersion/core/accessibility/shortcuts_help_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The shortcuts-help keys are bound around the whole app shell, so every
/// text field sits inside their scope. A bare "?" must reach the text field
/// while the diver is typing, and Ctrl+/ (Cmd+/ on macOS) must open the help
/// from anywhere, including a text field (#2145).
///
/// Tests default to TargetPlatform.android, so platformShortcut() builds
/// Control-based activators here.
void main() {
  Future<void> pumpShell(WidgetTester tester, Widget body) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => CallbackShortcuts(
            bindings: AppShortcuts.globalBindings(context),
            child: Focus(autofocus: true, child: Scaffold(body: body)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Presses Shift+/ so the key event carries the "?" character, the way a
  /// US layout produces it. Returns whether the framework handled the press.
  Future<bool> pressQuestionMark(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    final handled = await tester.sendKeyDownEvent(
      LogicalKeyboardKey.slash,
      character: '?',
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.slash);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    return handled;
  }

  /// Taps the field the way a diver would. `autofocus` would lose to the
  /// shell's own autofocused Focus, which claims focus first.
  Future<void> focusTextField(WidgetTester tester) async {
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(NotWhileTypingActivator.isEditingText(), isTrue);
  }

  Future<void> pressControlSlash(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.slash);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.slash);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  group('shortcuts help keys', () {
    testWidgets('"?" opens the help when no text field has focus', (
      tester,
    ) async {
      await pumpShell(tester, const Text('Dive list'));

      await pressQuestionMark(tester);

      expect(find.byType(ShortcutsHelpDialog), findsOneWidget);
    });

    testWidgets('"?" is left for a focused text field to type', (tester) async {
      await pumpShell(tester, const TextField());
      await focusTextField(tester);

      final handled = await pressQuestionMark(tester);

      expect(find.byType(ShortcutsHelpDialog), findsNothing);
      // Unhandled is what lets the engine hand the key on to the text input
      // system, which is what actually inserts the "?".
      expect(handled, isFalse);
    });

    testWidgets('"?" still opens the help from read-only selectable text', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await pumpShell(
        tester,
        SelectableText('Dive notes', focusNode: focusNode),
      );
      focusNode.requestFocus();
      await tester.pumpAndSettle();

      await pressQuestionMark(tester);

      expect(find.byType(ShortcutsHelpDialog), findsOneWidget);
    });

    testWidgets('Ctrl+/ opens the help when no text field has focus', (
      tester,
    ) async {
      await pumpShell(tester, const Text('Dive list'));

      await pressControlSlash(tester);

      expect(find.byType(ShortcutsHelpDialog), findsOneWidget);
    });

    testWidgets('Ctrl+/ opens the help from inside a text field', (
      tester,
    ) async {
      await pumpShell(tester, const TextField());
      await focusTextField(tester);

      await pressControlSlash(tester);

      expect(find.byType(ShortcutsHelpDialog), findsOneWidget);
    });
  });

  group('NotWhileTypingActivator', () {
    // Built at runtime, not const, so the constructor itself executes.
    final inner = platformShortcut(LogicalKeyboardKey.slash);
    final activator = NotWhileTypingActivator(inner);

    test('forwards the wrapped activator triggers', () {
      expect(activator.triggers, inner.triggers);
      expect(
        const NotWhileTypingActivator(CharacterActivator('?')).triggers,
        isNull,
      );
    });

    test('describes the wrapped keys and the typing guard', () {
      expect(
        activator.debugDescribeKeys(),
        '${inner.debugDescribeKeys()} (not while typing)',
      );
    });

    test('is not editing text when nothing has focus', () {
      expect(FocusManager.instance.primaryFocus, isNull);
      expect(NotWhileTypingActivator.isEditingText(), isFalse);
    });
  });

  group('shortcuts help catalog entries', () {
    // Another file in the isolate may have cleared the catalog after the
    // shortcuts were registered. Start from a known state.
    setUpAll(() {
      ShortcutCatalog.instance.clear();
      AppShortcuts.debugReset();
      AppShortcuts.ensureRegistered();
    });

    test('lists both "?" and Ctrl+/ for the keyboard shortcuts help', () {
      final helpKeys = ShortcutCatalog.instance.entries
          .where((e) => e.label == 'Keyboard shortcuts')
          .map((e) => e.displayKey(TargetPlatform.windows))
          .toList();

      expect(helpKeys, containsAll(<String>['?', 'Ctrl+/']));
    });
  });
}
