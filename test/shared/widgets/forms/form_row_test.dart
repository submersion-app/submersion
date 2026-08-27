import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Material(child: child)),
);

void main() {
  group('FormRow.text', () {
    testWidgets('resting shows label and value; tap enters inline edit', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'Blue Hole');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(FormRow.text(label: 'Name', controller: controller)),
      );
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Blue Hole'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      await tester.tap(find.text('Blue Hole'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'Great Blue Hole');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(controller.text, 'Great Blue Hole');
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Great Blue Hole'), findsOneWidget);
    });

    testWidgets('empty value shows placeholder', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          FormRow.text(
            label: 'Name',
            controller: controller,
            placeholder: 'Add name',
          ),
        ),
      );
      expect(find.text('Add name'), findsOneWidget);
    });

    testWidgets('alwaysEditing renders persistent field', (tester) async {
      final controller = TextEditingController(text: 'x');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          FormRow.text(
            label: 'Name',
            controller: controller,
            alwaysEditing: true,
          ),
        ),
      );
      expect(find.byType(TextFormField), findsOneWidget);
    });
  });

  group('FormRow.text calculate affordance', () {
    testWidgets('shows calculate icon when suggestion differs; tap fires onUse '
        'without entering edit mode', (tester) async {
      final controller = TextEditingController(text: '0.0');
      addTearDown(controller.dispose);
      var used = 0;
      await tester.pumpWidget(
        _wrap(
          FormRow.text(
            label: 'Avg depth',
            controller: controller,
            suffixText: 'm',
            profileSuggestion: ProfileSuggestion(
              value: '18.5',
              tooltip: 'Calculate from dive profile',
              onUse: () => used++,
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.calculate_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.calculate_outlined));
      await tester.pump();
      expect(used, 1);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('hides calculate icon when value already matches suggestion', (
      tester,
    ) async {
      final controller = TextEditingController(text: '18.5');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          FormRow.text(
            label: 'Avg depth',
            controller: controller,
            profileSuggestion: ProfileSuggestion(
              value: '18.5',
              tooltip: 'Calculate from dive profile',
              onUse: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.calculate_outlined), findsNothing);
    });

    testWidgets('no calculate icon without a suggestion', (tester) async {
      final controller = TextEditingController(text: '0.0');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(FormRow.text(label: 'Avg depth', controller: controller)),
      );
      expect(find.byIcon(Icons.calculate_outlined), findsNothing);
    });
  });

  group('FormRow.picker', () {
    testWidgets('shows value, chevron, and fires onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          FormRow.picker(
            label: 'Site',
            value: 'Blue Hole',
            onTap: () => taps++,
          ),
        ),
      );
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      await tester.tap(find.text('Blue Hole'));
      expect(taps, 1);
    });

    testWidgets('null value shows placeholder', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormRow.picker(
            label: 'Site',
            value: null,
            placeholder: 'Add site',
            onTap: () {},
          ),
        ),
      );
      expect(find.text('Add site'), findsOneWidget);
    });
  });

  group('other variants', () {
    testWidgets('display row is not tappable', (tester) async {
      await tester.pumpWidget(
        _wrap(const FormRow.display(label: 'Surface interval', value: '1:42')),
      );
      expect(find.text('1:42'), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('toggle row flips switch', (tester) async {
      var on = false;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => FormRow.toggle(
              label: 'Shared',
              value: on,
              onChanged: (v) => setState(() => on = v),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(on, isTrue);
    });

    testWidgets('rating row reports tapped star', (tester) async {
      int? rated;
      await tester.pumpWidget(
        _wrap(
          FormRow.rating(
            label: 'Rating',
            value: 2,
            onChanged: (v) => rated = v,
          ),
        ),
      );
      expect(find.byIcon(Icons.star), findsNWidgets(2));
      expect(find.byIcon(Icons.star_border), findsNWidgets(3));
      await tester.tap(find.byIcon(Icons.star_border).last);
      expect(rated, 5);
    });

    testWidgets('custom row hosts arbitrary child', (tester) async {
      await tester.pumpWidget(
        _wrap(const FormRow.custom(label: 'Mode', child: Text('SEGMENTED'))),
      );
      expect(find.text('Mode'), findsOneWidget);
      expect(find.text('SEGMENTED'), findsOneWidget);
    });

    testWidgets('picker clear affordance fires onClear', (tester) async {
      var cleared = 0;
      await tester.pumpWidget(
        _wrap(
          FormRow.picker(
            label: 'Site',
            value: 'Blue Hole',
            onTap: () {},
            onClear: () => cleared++,
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.clear));
      expect(cleared, 1);
    });
  });

  group('validation hardening', () {
    testWidgets('row with validator renders persistent field and validates', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          Form(
            key: formKey,
            child: FormRow.text(
              label: 'Name',
              controller: controller,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
          ),
        ),
      );
      expect(find.byType(TextFormField), findsOneWidget);
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('decoration override is honored', (tester) async {
      final controller = TextEditingController(text: 'x');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          FormRow.text(
            label: 'Country',
            controller: controller,
            alwaysEditing: true,
            decoration: const InputDecoration(
              labelText: 'Country',
              helperText: 'From Site A (1/2)',
            ),
          ),
        ),
      );
      expect(find.text('From Site A (1/2)'), findsOneWidget);
    });
  });

  group('v2 row-shaped editing', () {
    testWidgets('text row keeps its label visible while editing', (
      tester,
    ) async {
      final controller = TextEditingController(text: '42');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(FormRow.text(label: 'Max depth', controller: controller)),
      );
      await tester.tap(find.text('42'));
      await tester.pumpAndSettle();
      // Editing: label still rendered as row text, field is bare (no box).
      expect(find.text('Max depth'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      final input = tester.widget<TextField>(find.byType(TextField));
      expect(input.decoration!.border, InputBorder.none);
      expect(input.decoration!.filled, isFalse);
    });

    testWidgets('validator row stays mounted with label and bare field', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(
          Form(
            key: formKey,
            child: FormRow.text(
              label: 'Name',
              controller: controller,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
          ),
        ),
      );
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      final input = tester.widget<TextField>(find.byType(TextField));
      expect(input.decoration!.border, InputBorder.none);
      formKey.currentState!.validate();
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('rating row shows clear affordance and clears', (tester) async {
      var value = 3;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => FormRow.rating(
              label: 'Rating',
              value: value,
              onChanged: (v) => setState(() => value = v),
              onClear: () => setState(() => value = 0),
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.clear), findsOneWidget);
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      expect(value, 0);
      expect(find.byIcon(Icons.clear), findsNothing);
    });
  });
}
