import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_leave_guard.dart';

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

/// A home page that pushes the guarded record page.
Widget _app(RecordEditController<_Rec> controller) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RecordEditLeaveGuard<_Rec>(
                controller: controller,
                child: Scaffold(
                  appBar: AppBar(title: const Text('Record')),
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () async {
                        _cancelResult = await cancelSitting(
                          context,
                          controller,
                        );
                      },
                      child: const Text('cancel sitting'),
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

Future<RecordEditController<_Rec>> _open(WidgetTester tester) async {
  final controller = RecordEditController<_Rec>(onSave: (_) async {});
  addTearDown(controller.dispose);
  await tester.pumpWidget(_app(controller));
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
}
