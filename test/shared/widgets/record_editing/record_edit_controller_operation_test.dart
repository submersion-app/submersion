import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_leave_guard.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';

@immutable
class _Rec {
  const _Rec(this.notes);

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
  write: (r, v) => _Rec(v),
);

RecordEditController<_Rec> _controller({
  Future<_Rec?> Function(_Rec stored)? reread,
  List<EditSession<_Rec>>? started,
  Future<void> Function(EditSession<_Rec> session)? onSave,
}) {
  final controller = RecordEditController<_Rec>(
    onSave: onSave ?? (_) async {},
    reread: reread ?? (_) async => const _Rec('fresh'),
    onStart: started?.add,
  );
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  test('refused while locked, dirty, saving or running one', () async {
    var ran = 0;
    Future<bool> op() async {
      ran++;
      return true;
    }

    final locked = _controller();
    expect(await locked.runOperation(op), isFalse);

    final dirty = _controller()..unlock(const _Rec('a'));
    dirty.session!.set(_notes, 'b');
    expect(await dirty.runOperation(op), isFalse);

    final saving = Completer<void>();
    final duringSave = _controller(onSave: (_) => saving.future)
      ..unlock(const _Rec('a'));
    duringSave.session!.set(_notes, 'b');
    final save = duringSave.save();
    expect(await duringSave.runOperation(op), isFalse);
    saving.complete();
    await save;

    final running = Completer<bool>();
    final twice = _controller()..unlock(const _Rec('a'));
    final first = twice.runOperation(() => running.future);
    expect(await twice.runOperation(op), isFalse);
    running.complete(false);
    await first;

    expect(ran, 0);
  });

  test(
    'a completed operation starts a fresh sitting on the record read again',
    () async {
      final started = <EditSession<_Rec>>[];
      final reread = <_Rec>[];
      final controller = _controller(
        started: started,
        reread: (stored) async {
          reread.add(stored);
          return const _Rec('fresh');
        },
      )..unlock(const _Rec('a'));
      controller.openCard('notes');
      controller.addCard('tags');
      final before = controller.session;

      expect(await controller.runOperation(() async => true), isTrue);

      expect(reread, [const _Rec('a')]);
      expect(controller.isUnlocked, isTrue);
      expect(controller.isDirty, isFalse);
      expect(controller.isOperating, isFalse);
      expect(controller.session, isNot(same(before)));
      expect(controller.session!.stored, const _Rec('fresh'));
      expect(before!.isDisposed, isTrue);
      expect(started, hasLength(2));
      expect(started.last, same(controller.session));
      expect(controller.openCardIds, isEmpty);
      expect(controller.addedCardIds, isEmpty);
      expect(controller.layoutRecord, isNull);
    },
  );

  test(
    'the page is never told it locked while the sitting starts again',
    () async {
      final controller = _controller()..unlock(const _Rec('a'));
      final seen = <bool>[];
      controller.addListener(() => seen.add(controller.isUnlocked));

      await controller.runOperation(() async => true);

      expect(seen, isNotEmpty);
      expect(seen, everyElement(isTrue));
    },
  );

  test('the sitting is frozen while the operation runs', () async {
    final controller = _controller()..unlock(const _Rec('a'));
    final session = controller.session!;
    late bool frozen;
    late bool busy;
    late bool operating;

    await controller.runOperation(() async {
      frozen = session.isFrozen;
      busy = controller.isBusy;
      operating = controller.isOperating;
      session.set(_notes, 'typed');
      controller.openCard('notes');
      return false;
    });

    expect(frozen, isTrue);
    expect(busy, isTrue);
    expect(operating, isTrue);
    expect(session.isDirty, isFalse);
    expect(controller.openCardIds, isEmpty);
    expect(session.isFrozen, isFalse);
    expect(controller.isBusy, isFalse);
  });

  test('an operation that changed nothing keeps the sitting', () async {
    var reads = 0;
    final controller = _controller(
      reread: (_) async {
        reads++;
        return const _Rec('fresh');
      },
    )..unlock(const _Rec('a'));
    controller.openCard('notes');
    final before = controller.session;

    expect(await controller.runOperation(() async => false), isTrue);

    expect(reads, 0);
    expect(controller.session, same(before));
    expect(controller.openCardIds, {'notes'});
  });

  test('a record that no longer exists locks the page', () async {
    final controller = _controller(reread: (_) async => null)
      ..unlock(const _Rec('a'));

    await controller.runOperation(() async => true);

    expect(controller.isUnlocked, isFalse);
    expect(controller.isOperating, isFalse);
  });

  test('an operation that throws keeps the sitting and rethrows', () async {
    final controller = _controller()..unlock(const _Rec('a'));
    final before = controller.session;

    await expectLater(
      controller.runOperation(() async => throw StateError('no')),
      throwsStateError,
    );

    expect(controller.session, same(before));
    expect(before!.isFrozen, isFalse);
    expect(controller.isOperating, isFalse);
  });

  test('a failed read after a write locks the page and rethrows', () async {
    // The record changed underneath the sitting, and what it is now is
    // unknown: a Save from the old copy would write the change back over.
    final controller = _controller(
      reread: (_) async => throw StateError('closed'),
    )..unlock(const _Rec('a'));

    await expectLater(
      controller.runOperation(() async => true),
      throwsStateError,
    );

    expect(controller.isUnlocked, isFalse);
    expect(controller.isOperating, isFalse);
  });

  test('a controller disposed while an operation runs reads nothing', () async {
    var reads = 0;
    final controller = RecordEditController<_Rec>(
      onSave: (_) async {},
      reread: (_) async {
        reads++;
        return const _Rec('fresh');
      },
    )..unlock(const _Rec('a'));
    final running = Completer<bool>();
    final done = controller.runOperation(() => running.future);
    controller.dispose();
    running.complete(true);

    expect(await done, isFalse);
    expect(reads, 0);
  });

  test('a lock during an operation leaves the next sitting free', () async {
    var reads = 0;
    final controller = _controller(
      reread: (_) async {
        reads++;
        return const _Rec('fresh');
      },
    )..unlock(const _Rec('a'));
    final running = Completer<bool>();
    final done = controller.runOperation(() => running.future);
    controller.lock();

    expect(controller.isOperating, isFalse);
    expect(controller.isBusy, isFalse);
    controller.unlock(const _Rec('b'));
    final next = controller.session!;
    expect(next.isFrozen, isFalse);
    next.set(_notes, 'typed');
    expect(next.isDirty, isTrue);

    running.complete(true);
    await done;
    expect(controller.session, same(next));
    expect(next.isFrozen, isFalse);
    expect(controller.isOperating, isFalse);
    expect(reads, 0);
  });

  test('retake is refused with unsaved changes', () {
    final controller = _controller()..unlock(const _Rec('a'));
    final before = controller.session!..set(_notes, 'b');

    controller.retake(const _Rec('fresh'));

    expect(controller.session, same(before));
    expect(before.working, const _Rec('b'));
  });

  testWidgets('the leave guard refuses Back while an operation runs', (
    tester,
  ) async {
    final controller = _controller()..unlock(const _Rec('a'));
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('under')),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => RecordEditLeaveGuard<_Rec>(
          controller: controller,
          child: const Scaffold(body: Text('page')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final running = Completer<bool>();
    final done = controller.runOperation(() => running.future);
    await tester.pump();

    await navigator.currentState!.maybePop();
    await tester.pumpAndSettle();

    expect(find.text('page'), findsOneWidget);
    running.complete(false);
    await done;
  });

  testWidgets('the bar disables Cancel and Save while busy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: RecordEditBar(
            title: 'Editing',
            canSave: true,
            isSaving: false,
            isBusy: true,
            onCancel: () {},
            onSave: () {},
          ),
        ),
      ),
    );

    final actions = tester
        .widgetList<AppBarTextAction>(find.byType(AppBarTextAction))
        .toList();
    expect(actions, hasLength(2));
    for (final action in actions) {
      expect(action.onPressed, isNull);
      expect(action.busy, isFalse);
    }
  });
}
