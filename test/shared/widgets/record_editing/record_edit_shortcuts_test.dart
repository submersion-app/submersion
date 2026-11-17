import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_shortcuts.dart';

final _notes = EditField<String, String>(
  id: 'notes',
  cardId: 'notes',
  read: (r) => r,
  write: (r, v) => v,
);

/// A record page that registers itself as the keys' target, as the dive
/// page does.
class _Page extends ConsumerStatefulWidget {
  const _Page({required this.controller, this.onEscapeBelow});

  final RecordEditController<String> controller;
  final VoidCallback? onEscapeBelow;

  @override
  ConsumerState<_Page> createState() => _PageState();
}

class _PageState extends ConsumerState<_Page> {
  late final RecordEditShortcutTarget _target;
  late final RecordEditShortcutTargets _targets;

  @override
  void initState() {
    super.initState();
    _targets = ref.read(recordEditShortcutTargetsProvider);
    _target = RecordEditShortcutTarget(
      controller: widget.controller,
      unlock: () => widget.controller.unlock('stored'),
      save: () => widget.controller.save(),
      cancel: widget.controller.lock,
      isCurrent: () => mounted && (ModalRoute.of(context)?.isCurrent ?? true),
    );
    _targets.add(_target);
  }

  @override
  void dispose() {
    _targets.remove(_target);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: _body(context));

  Widget _body(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: (_, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        widget.onEscapeBelow?.call();
      }
      return KeyEventResult.ignored;
    },
    child: Column(
      children: [
        const TextField(key: ValueKey('field')),
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(content: Text('Dialog')),
            ),
            child: const Text('Open dialog'),
          ),
        ),
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('On top')),
              ),
            ),
            child: const Text('Push page'),
          ),
        ),
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => const SizedBox(height: 100, child: Text('Sheet')),
            ),
            child: const Text('Open sheet'),
          ),
        ),
        PopupMenuButton<String>(
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'a', child: Text('Menu item')),
          ],
        ),
        Autocomplete<String>(
          optionsBuilder: (value) => value.text.isEmpty
              ? const <String>[]
              : const ['Suggestion one', 'Suggestion two'],
        ),
      ],
    ),
  );
}

void main() {
  late RecordEditController<String> controller;
  late int saves;

  setUp(() {
    saves = 0;
    controller = RecordEditController<String>(onSave: (_) async => saves++);
  });
  tearDown(() => controller.dispose());

  Future<void> pump(
    WidgetTester tester, {
    VoidCallback? onEscapeBelow,
    SelectionController? list,
  }) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final page = _Page(controller: controller, onEscapeBelow: onEscapeBelow);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => RecordEditShortcuts(child: child!),
          // With [list], the page sits inside a list's selection scope, as
          // the dive list's pane does beside its list.
          home: list == null
              ? page
              : SelectableListScope(
                  controller: list,
                  selectableIds: const ['a', 'b'],
                  child: page,
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> chord(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  testWidgets('Ctrl+L unlocks, Ctrl+S saves, Escape cancels', (tester) async {
    await pump(tester);

    await chord(tester, LogicalKeyboardKey.keyL);
    expect(controller.isUnlocked, isTrue);

    controller.session!.set(_notes, 'changed');
    await chord(tester, LogicalKeyboardKey.keyS);
    expect(saves, 1);
    expect(controller.isUnlocked, isFalse);

    await chord(tester, LogicalKeyboardKey.keyL);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(controller.isUnlocked, isFalse);
  });

  // The list pane (issue #4527): the list's own Escape leaves selection
  // mode, and with nothing selected it lets Escape on to the sitting.
  testWidgets('Escape inside a list with nothing selected cancels', (
    tester,
  ) async {
    final list = SelectionController();
    addTearDown(list.dispose);
    await pump(tester, list: list);
    await chord(tester, LogicalKeyboardKey.keyL);
    expect(controller.isUnlocked, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(controller.isUnlocked, isFalse);
  });

  testWidgets('Escape inside a list with rows selected leaves selection '
      'and keeps the sitting', (tester) async {
    final list = SelectionController();
    addTearDown(list.dispose);
    await pump(tester, list: list);
    await chord(tester, LogicalKeyboardKey.keyL);
    list.enterImplicit('a');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(list.value.isActive, isFalse);
    expect(controller.isUnlocked, isTrue);
  });

  // Escape held down to leave selection mode repeats: the repeats are the
  // same press, and must not go on to cancel the sitting (issue #4527).
  testWidgets('Escape held inside a list with rows selected leaves selection '
      'and keeps the sitting', (tester) async {
    final list = SelectionController();
    addTearDown(list.dispose);
    await pump(tester, list: list);
    await chord(tester, LogicalKeyboardKey.keyL);
    list.enterImplicit('a');
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(list.value.isActive, isFalse);
    expect(controller.isUnlocked, isTrue);
  });

  testWidgets('Save and Escape work while a text field has focus', (
    tester,
  ) async {
    await pump(tester);
    await chord(tester, LogicalKeyboardKey.keyL);
    controller.session!.set(_notes, 'changed');
    await tester.tap(find.byKey(const ValueKey('field')));
    await tester.pump();

    await chord(tester, LogicalKeyboardKey.keyS);
    expect(saves, 1);

    // Unlocked again from outside the field (the unlock key is refused
    // while typing), then Escape from inside it.
    controller.unlock('stored');
    await tester.tap(find.byKey(const ValueKey('field')));
    await tester.pump();
    expect(controller.isUnlocked, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(controller.isUnlocked, isFalse);
  });

  testWidgets('Ctrl+L does nothing while typing', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('field')));
    await tester.pump();

    await chord(tester, LogicalKeyboardKey.keyL);

    expect(controller.isUnlocked, isFalse);
  });

  testWidgets('Escape with a dialog open closes the dialog and keeps the '
      'sitting', (tester) async {
    await pump(tester);
    await chord(tester, LogicalKeyboardKey.keyL);
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Dialog'), findsNothing);
    expect(controller.isUnlocked, isTrue);
  });

  testWidgets('a pushed page on top: the keys act on the page underneath '
      'no more', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Push page'));
    await tester.pumpAndSettle();

    await chord(tester, LogicalKeyboardKey.keyL);

    expect(controller.isUnlocked, isFalse);
  });

  testWidgets('Escape in an open sheet closes it and keeps the sitting', (
    tester,
  ) async {
    await pump(tester);
    await chord(tester, LogicalKeyboardKey.keyL);
    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Sheet'), findsNothing);
    expect(controller.isUnlocked, isTrue);
  });

  testWidgets('Escape in an open menu closes it and keeps the sitting', (
    tester,
  ) async {
    await pump(tester);
    await chord(tester, LogicalKeyboardKey.keyL);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Menu item'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Menu item'), findsNothing);
    expect(controller.isUnlocked, isTrue);
  });

  testWidgets('Escape with suggestions showing closes them and keeps the '
      'sitting', (tester) async {
    await pump(tester);
    await chord(tester, LogicalKeyboardKey.keyL);
    await tester.tap(find.byType(TextField).last);
    await tester.enterText(find.byType(TextField).last, 'S');
    await tester.pumpAndSettle();
    expect(find.text('Suggestion one'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Suggestion one'), findsNothing);
    expect(controller.isUnlocked, isTrue);
  });

  testWidgets('Save with nothing to save does nothing', (tester) async {
    await pump(tester);
    await chord(tester, LogicalKeyboardKey.keyL);

    await chord(tester, LogicalKeyboardKey.keyS);

    expect(saves, 0);
    expect(controller.isUnlocked, isTrue);
  });
}
