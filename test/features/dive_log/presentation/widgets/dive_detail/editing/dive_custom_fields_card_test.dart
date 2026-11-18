import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/custom_field_input_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_custom_fields_card_editor.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/test_database.dart';

/// The Custom fields card of the dive page, edited in place (issue #4527,
/// plan 6).
void main() {
  const boat = DiveCustomField(id: 'c1', key: 'Boat', value: 'Aggressor');
  const guide = DiveCustomField(
    id: 'c2',
    key: 'Guide',
    value: 'Ana',
    sortOrder: 1,
  );
  final dive = Dive(
    id: 'dive',
    dateTime: DateTime.utc(2026, 3, 9, 9),
    customFields: const [boat, guide],
  );

  group('the field', () {
    test('a row with an empty key is dropped when written', () {
      final written = diveCustomFieldsField.write(dive, const [
        boat,
        DiveCustomField(id: 'c3', key: '  ', value: 'lost'),
        guide,
      ]);
      expect(written.customFields.map((f) => f.id), ['c1', 'c2']);
    });

    test('the same rows reordered are a change; put back, none', () {
      final session = EditSession<Dive>(dive);
      addTearDown(session.dispose);

      session.set(diveCustomFieldsField, const [guide, boat]);
      expect(session.isDirty, isTrue);
      expect(session.working.customFields.map((f) => (f.id, f.sortOrder)), [
        ('c2', 0),
        ('c1', 1),
      ]);

      session.set(diveCustomFieldsField, const [boat, guide]);
      expect(session.isDirty, isFalse);
    });

    test('an added row with no key is no change', () {
      final session = EditSession<Dive>(dive);
      addTearDown(session.dispose);

      session.set(diveCustomFieldsField, const [
        boat,
        guide,
        DiveCustomField(id: 'c3', key: '', value: ''),
      ]);
      expect(session.isDirty, isFalse);
    });
  });

  group('the editor', () {
    setUp(setUpTestDatabase);
    tearDown(tearDownTestDatabase);

    Future<RecordEditController<Dive>> pumpEditor(
      WidgetTester tester,
      Dive d,
    ) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = RecordEditController<Dive>(onSave: (_) async {})
        ..unlock(d)
        ..openCard('customFields');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await getBaseOverrides(),
            validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
            customFieldKeySuggestionsProvider(
              'me',
            ).overrideWith((ref) async => const ['Boat', 'Visibility note']),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: RecordEditScope<Dive>(
                  controller: controller,
                  child: Column(
                    children: [
                      DiveCustomFieldsCardEditor(session: controller.session!),
                      const TextField(key: ValueKey('elsewhere')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // The base overrides start with no diver; the key suggestions are
      // the diver's own.
      await ProviderScope.containerOf(
        tester.element(find.byType(DiveCustomFieldsCardEditor)),
      ).read(currentDiverIdProvider.notifier).setCurrentDiver('me');
      await tester.pumpAndSettle();
      return controller;
    }

    Finder rowFields() => find.descendant(
      of: find.byType(DiveCustomFieldsCardEditor),
      matching: find.byType(EditableText),
    );

    testWidgets('opening and tapping every field leaves the sitting clean', (
      tester,
    ) async {
      final c = await pumpEditor(tester, dive);
      expect(find.byType(CustomFieldInputRow), findsNWidgets(2));
      for (var i = 0; i < rowFields().evaluate().length; i++) {
        await tester.tap(rowFields().at(i));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('elsewhere')));
      await tester.pumpAndSettle();

      expect(c.session!.isDirty, isFalse);
    });

    testWidgets('add, type a key and a value: the sitting has the row', (
      tester,
    ) async {
      final c = await pumpEditor(tester, dive);
      await tester.tap(find.text('Add Field'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomFieldInputRow), findsNWidgets(3));

      await tester.enterText(rowFields().at(4), 'Camera');
      await tester.enterText(rowFields().at(5), 'GoPro');
      await tester.pump();

      final fields = c.session!.working.customFields;
      expect(fields.map((f) => (f.key, f.value)), [
        ('Boat', 'Aggressor'),
        ('Guide', 'Ana'),
        ('Camera', 'GoPro'),
      ]);
      expect(fields.last.id, isNotEmpty);
    });

    testWidgets('an added row left empty is no change', (tester) async {
      final c = await pumpEditor(tester, dive);
      await tester.tap(find.text('Add Field'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomFieldInputRow), findsNWidgets(3));
      expect(c.session!.isDirty, isFalse);
    });

    testWidgets('a row removed is gone from the sitting', (tester) async {
      final c = await pumpEditor(tester, dive);
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      expect(find.byType(CustomFieldInputRow), findsOneWidget);
      expect(c.session!.working.customFields.map((f) => f.id), ['c2']);
    });

    testWidgets("key suggestions offer the diver's other keys", (tester) async {
      await pumpEditor(tester, dive.copyWith(customFields: const []));
      await tester.tap(find.text('Add Field'));
      await tester.pumpAndSettle();
      await tester.tap(rowFields().first);
      await tester.pumpAndSettle();

      expect(find.text('Visibility note'), findsOneWidget);
    });
  });
}
