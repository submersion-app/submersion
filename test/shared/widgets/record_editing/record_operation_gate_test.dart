import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';

final _notes = EditField<String, String>(
  id: 'notes',
  cardId: 'notes',
  read: (r) => r,
  write: (r, v) => v,
);

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('no controller: not offered, no reason', () {
    expect(recordOperationBlockOf(null), isNull);
    expect(recordOperationReason(l10n, null), isNull);
    expect(recordOperationReason(l10n, RecordOperationBlock.none), isNull);
  });

  test('locked, then unlocked and clean, then dirty', () {
    final c = RecordEditController<String>(onSave: (_) async {});
    addTearDown(c.dispose);

    expect(recordOperationBlockOf(c), RecordOperationBlock.locked);
    expect(
      recordOperationReason(l10n, RecordOperationBlock.locked, plural: true),
      'Unlock to use these',
    );
    expect(
      recordOperationReason(l10n, RecordOperationBlock.locked),
      'Unlock to use this',
    );

    c.unlock('a');
    expect(recordOperationBlockOf(c), RecordOperationBlock.none);

    c.session!.set(_notes, 'b');
    expect(recordOperationBlockOf(c), RecordOperationBlock.unsaved);
    expect(
      recordOperationReason(l10n, RecordOperationBlock.unsaved),
      'Save or cancel your changes first',
    );
    expect(
      recordOperationReason(l10n, RecordOperationBlock.unsaved, plural: true),
      'Save or cancel your changes first',
    );
  });

  testWidgets('a blocked button is disabled with its reason as tooltip', (
    tester,
  ) async {
    var pressed = 0;
    await tester.pumpWidget(
      _app(
        RecordOperationButton(
          reason: 'Unlock to use this',
          onPressed: () => pressed++,
          builder: (onPressed) =>
              TextButton(onPressed: onPressed, child: const Text('Go')),
        ),
      ),
    );

    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
    expect(find.byTooltip('Unlock to use this'), findsOneWidget);
    await tester.tap(find.text('Go'), warnIfMissed: false);
    expect(pressed, 0);
  });

  testWidgets('a free button presses, with no tooltip of its own', (
    tester,
  ) async {
    var pressed = 0;
    await tester.pumpWidget(
      _app(
        RecordOperationButton(
          reason: null,
          onPressed: () => pressed++,
          builder: (onPressed) =>
              TextButton(onPressed: onPressed, child: const Text('Go')),
        ),
      ),
    );

    expect(find.byType(Tooltip), findsNothing);
    await tester.tap(find.text('Go'));
    expect(pressed, 1);
  });

  testWidgets('the caption item cannot be chosen', (tester) async {
    String? chosen;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => PopupMenuButton<String>(
            onSelected: (v) => chosen = v,
            itemBuilder: (context) => [
              recordOperationCaption<String>(context, 'Unlock to use these'),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    final caption = tester.widget<PopupMenuItem<String>>(
      find.byKey(const ValueKey('recordOperationCaption')),
    );
    expect(caption.enabled, isFalse);
    await tester.tap(find.text('Unlock to use these'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(chosen, isNull);
  });
  test('available and the menu caption follow the controller', () {
    expect(recordOperationsAvailable(null), isTrue);
    final c = RecordEditController<String>(onSave: (_) async {});
    addTearDown(c.dispose);
    expect(recordOperationsAvailable(c), isFalse);
    c.unlock('Calm');
    expect(recordOperationsAvailable(c), isTrue);
    c.session!.set(_notes, 'Surge');
    expect(recordOperationsAvailable(c), isFalse);
  });

  testWidgets('the menu caption is there only while blocked', (tester) async {
    final c = RecordEditController<String>(onSave: (_) async {});
    addTearDown(c.dispose);
    late List<PopupMenuEntry<String>> locked;
    late List<PopupMenuEntry<String>> free;
    late List<PopupMenuEntry<String>> none;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            locked = recordOperationMenuCaption<String>(context, c);
            none = recordOperationMenuCaption<String>(context, null);
            return const SizedBox();
          },
        ),
      ),
    );
    c.unlock('Calm');
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            free = recordOperationMenuCaption<String>(context, c);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(locked, hasLength(1));
    expect(
      ((locked.single as PopupMenuItem<String>).child! as Text).data,
      'Unlock to use these',
    );
    expect(free, isEmpty);
    expect(none, isEmpty);
  });
}
