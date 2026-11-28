import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_record.dart';
import 'package:submersion/features/equipment/presentation/widgets/catalogue_name_field.dart';

EquipmentCatalogueRecord _r(
  String id,
  String maker,
  String model, {
  EquipmentType type = EquipmentType.computer,
}) => EquipmentCatalogueRecord(
  id: id,
  manufacturer: maker,
  model: model,
  type: type,
);

final _catalogue = EquipmentCatalogue(
  EquipmentCatalogueFile(
    format: 1,
    generatedAt: DateTime.utc(2026, 11, 27),
    records: [
      const EquipmentCatalogueRecord(
        id: 'sw-perdix-2',
        manufacturer: 'Shearwater',
        manufacturerAliases: ['Shearwater Research'],
        model: 'Perdix 2',
        type: EquipmentType.computer,
      ),
      _r('sw-perdix', 'Shearwater', 'Perdix'),
      _r('sw-teric', 'Shearwater', 'Teric'),
      _r('hw-ostc-4', 'Heinrichs Weikamp', 'OSTC 4 hwOS Sport Edition Long'),
      _r('su-d5', 'Suunto', 'D5'),
      _r('lumo-quad', 'Lumo', 'Quad', type: EquipmentType.light),
    ],
  ),
);

void main() {
  group('brandSuggestions', () {
    test("the diver's own brands come first", () {
      expect(
        brandSuggestions(_catalogue, EquipmentType.computer, [
          'Sherwood',
        ], 'sh'),
        ['Sherwood', 'Shearwater'],
      );
    });

    test('prefix matches before contains matches', () {
      expect(
        brandSuggestions(_catalogue, EquipmentType.computer, const [], 'he'),
        ['Heinrichs Weikamp', 'Shearwater'],
      );
    });

    test('one entry per name, the diver spelling wins', () {
      expect(
        brandSuggestions(_catalogue, EquipmentType.computer, [
          'shearwater',
        ], 'shear'),
        ['shearwater'],
      );
    });

    test("a maker's other name finds its own spelling", () {
      expect(
        brandSuggestions(
          _catalogue,
          EquipmentType.computer,
          const [],
          'research',
        ),
        ['Shearwater'],
      );
    });

    test('nothing for a blank field or another type', () {
      expect(
        brandSuggestions(_catalogue, EquipmentType.computer, const [], ' '),
        isEmpty,
      );
      expect(
        brandSuggestions(_catalogue, EquipmentType.light, const [], 'shear'),
        isEmpty,
      );
    });
  });

  group('modelSuggestions', () {
    test('is empty with no brand', () {
      expect(
        modelSuggestions(_catalogue, EquipmentType.computer, '', 'per'),
        isEmpty,
      );
    });

    test("lists the brand's models for the type", () {
      expect(
        modelSuggestions(
          _catalogue,
          EquipmentType.computer,
          'Shearwater',
          'per',
        ),
        ['Perdix', 'Perdix 2'],
      );
      expect(
        modelSuggestions(_catalogue, EquipmentType.light, 'Shearwater', 'per'),
        isEmpty,
      );
    });

    test('leaves out the name already typed', () {
      expect(
        modelSuggestions(
          _catalogue,
          EquipmentType.computer,
          'Shearwater',
          'perdix 2',
        ),
        isEmpty,
      );
    });
  });

  Future<TextEditingController> pump(
    WidgetTester tester, {
    double width = 800,
    List<String> Function(String typed)? suggestionsFor,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.reset);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: CatalogueNameField(
              key: const ValueKey('gear-edit-model'),
              controller: controller,
              label: 'Model',
              icon: Icons.info_outline,
              suggestionsFor:
                  suggestionsFor ??
                  (typed) => modelSuggestions(
                    _catalogue,
                    EquipmentType.computer,
                    'Shearwater',
                    typed,
                  ),
            ),
          ),
        ),
      ),
    );
    return controller;
  }

  testWidgets('picking a suggestion sets exactly the catalogue spelling', (
    tester,
  ) async {
    final controller = await pump(tester);
    await tester.enterText(find.byType(TextField), 'perdix 2x');
    await tester.enterText(find.byType(TextField), 'per');
    await tester.pumpAndSettle();
    expect(find.text('Perdix 2'), findsOneWidget);
    await tester.tap(find.text('Perdix 2'));
    await tester.pumpAndSettle();
    expect(controller.text, 'Perdix 2');
  });

  testWidgets('typing free text is kept', (tester) async {
    final controller = await pump(tester);
    await tester.enterText(find.byType(TextField), 'My own model');
    await tester.pumpAndSettle();
    expect(controller.text, 'My own model');
    expect(find.text('Perdix'), findsNothing);
  });

  testWidgets('at 360 px a long model name wraps without overflow', (
    tester,
  ) async {
    await pump(
      tester,
      width: 360,
      suggestionsFor: (typed) => modelSuggestions(
        _catalogue,
        EquipmentType.computer,
        'Heinrichs Weikamp',
        typed,
      ),
    );
    await tester.enterText(find.byType(TextField), 'ostc');
    await tester.pumpAndSettle();
    expect(find.text('OSTC 4 hwOS Sport Edition Long'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no suggestions show from an empty catalogue', (tester) async {
    await pump(
      tester,
      suggestionsFor: (typed) => modelSuggestions(
        EquipmentCatalogue.empty,
        EquipmentType.computer,
        'Shearwater',
        typed,
      ),
    );
    await tester.enterText(find.byType(TextField), 'per');
    await tester.pumpAndSettle();
    expect(find.text('Perdix'), findsNothing);
  });

  testWidgets('at most eight suggestions show', (tester) async {
    await pump(
      tester,
      suggestionsFor: (_) => [for (var i = 0; i < 20; i++) 'Model $i'],
    );
    await tester.enterText(find.byType(TextField), 'model');
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('Model 7'), findsOneWidget);
    expect(find.text('Model 8'), findsNothing);
  });
}
