import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_leave_guard.dart';
import 'package:submersion/shared/widgets/tab_visibility.dart';

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

/// What the page's "cancel" button last got back from [cancelSitting].
bool? _cancelResult;

/// How often the page's other control was pressed.
int _taps = 0;

/// A home page that pushes the guarded record page, in a kept-alive tab
/// shown or hidden when [tabVisible] is given (#3437), beside another
/// scope that refuses Back when [backRefused] (the tab on screen's own
/// changes or selection).
Widget _app(
  RecordEditController<_Rec> controller, {
  bool? tabVisible,
  bool backRefused = false,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _inTab(
                tabVisible,
                backRefused,
                RecordEditLeaveGuard<_Rec>(
                  controller: controller,
                  child: Scaffold(
                    appBar: AppBar(title: const Text('Record')),
                    body: Builder(
                      builder: (context) => Column(
                        children: [
                          TextButton(
                            onPressed: () async {
                              _cancelResult = await cancelSitting(
                                context,
                                controller,
                              );
                            },
                            child: const Text('cancel sitting'),
                          ),
                          TextButton(
                            onPressed: () => _taps++,
                            child: const Text('a control'),
                          ),
                          const TextField(key: ValueKey('a field')),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
}

/// [child] in a tab shown or hidden by [visible] (as it is when null),
/// under a scope that refuses Back when [backRefused].
Widget _inTab(bool? visible, bool backRefused, Widget child) {
  final tab = visible == null
      ? child
      : TabVisibility(visible: visible, child: child);
  return backRefused ? PopScope(canPop: false, child: tab) : tab;
}

Future<RecordEditController<_Rec>> _open(
  WidgetTester tester, {
  Future<void> Function()? onSave,
  bool? tabVisible,
  bool backRefused = false,
}) async {
  _taps = 0;
  final controller = RecordEditController<_Rec>(
    onSave: (_) async => onSave?.call(),
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    _app(controller, tabVisible: tabVisible, backRefused: backRefused),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.text('Record'), findsOneWidget);
  return controller;
}

void main() {
  setUp(() => _cancelResult = null);

  testWidgets('locked: back pops', (tester) async {
    await _open(tester);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Record'), findsNothing);
  });

  testWidgets('unlocked with no changes: back pops and locks', (tester) async {
    final controller = await _open(tester);
    controller.unlock(const _Rec());
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Record'), findsNothing);
    expect(controller.isUnlocked, isFalse);
  });

  // A scope inside the page can refuse Back for a step of its own (the
  // photo viewer leaving fullscreen first). Every scope is then told the pop
  // did not happen; the guard did not refuse it, so it must not finish the
  // pop itself.
  for (final unlocked in [false, true]) {
    testWidgets('${unlocked ? 'unlocked, no changes' : 'locked'}: a Back a '
        'scope inside refuses stays on the page', (tester) async {
      final controller = RecordEditController<_Rec>(onSave: (_) async {});
      addTearDown(controller.dispose);
      if (unlocked) controller.unlock(const _Rec());
      var refused = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RecordEditLeaveGuard<_Rec>(
                    controller: controller,
                    child: PopScope(
                      canPop: false,
                      onPopInvokedWithResult: (didPop, _) => refused++,
                      child: const Scaffold(body: Text('Record')),
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(refused, 1);
      expect(find.text('Record'), findsOneWidget);
      expect(controller.isUnlocked, unlocked);
    });
  }

  // With changes held, a page that backs out of a step of its own first
  // (the photo viewer's fullscreen) takes Back for that step: no discard
  // question, and the page stays.
  testWidgets('with changes, a step the page backs out of first takes Back', (
    tester,
  ) async {
    final controller = RecordEditController<_Rec>(onSave: (_) async {});
    addTearDown(controller.dispose);
    controller.unlock(const _Rec());
    controller.session!.set(_notes, 'changed');
    var inStep = true;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RecordEditLeaveGuard<_Rec>(
                  controller: controller,
                  backsOutFirst: () => inStep,
                  child: PopScope(
                    canPop: false,
                    onPopInvokedWithResult: (didPop, _) => inStep = false,
                    child: const Scaffold(body: Text('Record')),
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(inStep, isFalse);
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Record'), findsOneWidget);
    expect(controller.isDirty, isTrue);

    // Out of the step, Back asks as it always has.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
  });

  testWidgets('unlocked with changes: back asks, and Keep editing stays', (
    tester,
  ) async {
    final controller = await _open(tester);
    controller.unlock(const _Rec());
    controller.session!.set(_notes, 'b');
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    expect(find.text('Record'), findsOneWidget);
    expect(controller.isDirty, isTrue);
  });

  // A page that keeps its tabs mounted (Training, Media and Documents)
  // leaves on Back while a record with changes sits in the hidden tab: the
  // discard dialog is the tab on screen's to ask (#3437).
  testWidgets('with changes in a hidden tab, back leaves and asks nothing', (
    tester,
  ) async {
    final controller = await _open(tester, tabVisible: false);
    controller.unlock(const _Rec());
    controller.session!.set(_notes, 'b');
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Record'), findsNothing);
    // The page left with the hidden record's sitting.
    expect(controller.isUnlocked, isFalse);
  });

  testWidgets('with changes in a hidden tab, a Back another scope refuses '
      'asks nothing either', (tester) async {
    // A route tells every scope of a refused Back, the hidden tab's too.
    final controller = await _open(
      tester,
      tabVisible: false,
      backRefused: true,
    );
    controller.unlock(const _Rec());
    controller.session!.set(_notes, 'b');
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Record'), findsOneWidget);
    expect(controller.isDirty, isTrue);
  });

  testWidgets('with changes in the tab on screen, back still asks', (
    tester,
  ) async {
    final controller = await _open(tester, tabVisible: true);
    controller.unlock(const _Rec());
    controller.session!.set(_notes, 'b');
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('Record'), findsOneWidget);
  });

  testWidgets('unlocked with changes: back asks, and Discard pops and locks', (
    tester,
  ) async {
    final controller = await _open(tester);
    controller.unlock(const _Rec());
    controller.session!.set(_notes, 'b');
    await tester.pump();

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Record'), findsNothing);
    expect(controller.isUnlocked, isFalse);
  });

  // The list pane's page is its tab's first page: there is nothing under
  // it to go back to (issue #4527, plan 7).
  testWidgets('at the root, Back with changes asks, and Discard locks in '
      'place', (tester) async {
    final controller = RecordEditController<_Rec>(onSave: (_) async {});
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RecordEditLeaveGuard<_Rec>(
          controller: controller,
          child: const Scaffold(body: Text('Root record')),
        ),
      ),
    );
    controller.unlock(const _Rec());
    controller.session!.set(_notes, 'b');
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Root record'), findsOneWidget);
    expect(controller.isUnlocked, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelSitting with changes asks, and Discard locks in place', (
    tester,
  ) async {
    final controller = await _open(tester);
    controller.unlock(const _Rec());
    controller.session!.set(_notes, 'b');
    await tester.pump();

    await tester.tap(find.text('cancel sitting'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    expect(controller.isUnlocked, isTrue);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(_cancelResult, isTrue);
    expect(controller.isUnlocked, isFalse);
    expect(find.text('Record'), findsOneWidget);
  });

  testWidgets('cancelSitting with changes: Keep editing changes nothing', (
    tester,
  ) async {
    final controller = await _open(tester);
    controller.unlock(const _Rec());
    controller.session!.set(_notes, 'b');
    await tester.pump();

    await tester.tap(find.text('cancel sitting'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    expect(_cancelResult, isFalse);
    expect(controller.session!.valueOf(_notes), 'b');
  });

  testWidgets('cancelSitting with no changes locks at once', (tester) async {
    final controller = await _open(tester);
    controller.unlock(const _Rec());
    await tester.pump();

    await tester.tap(find.text('cancel sitting'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(_cancelResult, isTrue);
    expect(controller.isUnlocked, isFalse);
  });

  // The write takes a moment. Until it ends the sitting is neither left nor
  // changed: discarding it then would let the write land on a page the
  // diver thinks they abandoned.
  group('while a save is running', () {
    Future<({RecordEditController<_Rec> controller, Completer<void> gate})>
    saving(WidgetTester tester, {bool fail = false}) async {
      final gate = Completer<void>();
      final controller = await _open(
        tester,
        onSave: () async {
          await gate.future;
          if (fail) throw StateError('no');
        },
      );
      controller.unlock(const _Rec(notes: 'a'));
      controller.session!.set(_notes, 'b');
      await tester.pump();
      unawaited(controller.save());
      await tester.pump();
      expect(controller.isSaving, isTrue);
      return (controller: controller, gate: gate);
    }

    testWidgets('Back is ignored, and the page closes nothing', (tester) async {
      final page = await saving(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Record'), findsOneWidget);
      expect(page.controller.isUnlocked, isTrue);

      page.gate.complete();
      await tester.pumpAndSettle();
      expect(page.controller.isUnlocked, isFalse);
      expect(find.text('Record'), findsOneWidget);
    });

    testWidgets('cancelSitting does nothing', (tester) async {
      final page = await saving(tester);

      final cancelled = cancelSitting(
        tester.element(find.text('Record')),
        page.controller,
      );
      await tester.pumpAndSettle();

      expect(await cancelled, isFalse);
      expect(find.text('Discard changes?'), findsNothing);
      expect(page.controller.isSaving, isTrue);

      page.gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('controls on the page do not respond', (tester) async {
      final page = await saving(tester);

      await tester.tap(find.text('a control'), warnIfMissed: false);
      await tester.pump();

      expect(_taps, 0);

      page.gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a field being typed in loses the keyboard', (tester) async {
      final gate = Completer<void>();
      final controller = await _open(tester, onSave: () => gate.future);
      controller.unlock(const _Rec(notes: 'a'));
      controller.session!.set(_notes, 'b');
      await tester.pump();
      final field = find.byKey(const ValueKey('a field'));
      await tester.tap(field);
      await tester.pump();
      bool focused() => tester
          .widget<EditableText>(
            find.descendant(of: field, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus;
      expect(focused(), isTrue);

      unawaited(controller.save());
      await tester.pump();

      expect(focused(), isFalse);
      // Nor can it be given back, by a tap or from the keyboard.
      await tester.tap(field, warnIfMissed: false);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focused(), isFalse);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a save that fails gives the page back', (tester) async {
      final page = await saving(tester, fail: true);
      page.gate.complete();
      await tester.pumpAndSettle();
      expect(page.controller.isSaving, isFalse);
      expect(page.controller.isUnlocked, isTrue);

      await tester.tap(find.text('a control'));
      await tester.pump();
      expect(_taps, 1);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
    });
  });
}
