import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import 'components_card_harness.dart';

void main() {
  group('part of', () {
    const cold = EquipmentItem(
      id: 'cold',
      name: 'Cold water reg',
      type: EquipmentType.regulator,
    );
    const travel = EquipmentItem(
      id: 'travel',
      name: 'Travel reg',
      type: EquipmentType.regulator,
    );
    const old = EquipmentItem(
      id: 'old',
      name: 'Old reg',
      type: EquipmentType.regulator,
      status: EquipmentStatus.retired,
      isActive: false,
    );

    testWidgets('an item that is part of nothing keeps the plain card', (
      tester,
    ) async {
      await tester.pumpWidget(build(const [], FakeComponentRepository()));
      await tester.pumpAndSettle();
      expect(find.text('Part of'), findsNothing);
      expect(find.text('Contains'), findsNothing);
      expect(find.textContaining('No components'), findsOneWidget);
    });

    testWidgets('lists each parent with its role and every rig above it', (
      tester,
    ) async {
      await tester.pumpWidget(
        build(
          [part('c1', first, role: 'Primary')],
          FakeComponentRepository(),
          partOf: [
            parentEntry(cold),
            parentEntry(
              travel,
              role: 'Octopus',
              rigs: ['Backmount rig', 'Sidemount rig'],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Part of'), findsOneWidget);
      expect(find.text('Contains'), findsOneWidget);
      expect(find.text('Cold water reg'), findsOneWidget);
      // No role falls back to the parent's type; a top-level parent has no
      // rig line.
      expect(find.text('Regulator'), findsOneWidget);
      expect(
        find.text('Octopus, in Backmount rig, Sidemount rig'),
        findsOneWidget,
      );
      // The item's own parts still follow under Contains.
      expect(find.text('DGX first stage'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Travel reg')).dy,
        lessThan(tester.getTopLeft(find.text('Contains')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Contains')).dy,
        lessThan(tester.getTopLeft(find.text('DGX first stage')).dy),
      );
    });

    testWidgets('a retired parent is listed with its status', (tester) async {
      await tester.pumpWidget(
        build(
          const [],
          FakeComponentRepository(),
          partOf: [parentEntry(old, role: 'Octopus')],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Old reg'), findsOneWidget);
      expect(find.text('Retired'), findsOneWidget);
    });

    testWidgets('a sold parent keeps its Sold status, not Retired', (
      tester,
    ) async {
      const sold = EquipmentItem(
        id: 'sold',
        name: 'Sold reg',
        type: EquipmentType.regulator,
        status: EquipmentStatus.sold,
        isActive: false,
      );
      await tester.pumpWidget(
        build(
          const [],
          FakeComponentRepository(),
          partOf: [parentEntry(sold, role: 'Octopus')],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sold'), findsOneWidget);
      expect(find.text('Retired'), findsNothing);
    });

    testWidgets('a part with nothing of its own says so, not "no components"', (
      tester,
    ) async {
      // In the open card, which offers to add one.
      await tester.pumpWidget(
        build(
          const [],
          FakeComponentRepository(),
          partOf: [parentEntry(cold)],
          home: openCard(sittingWith(const [])),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No parts of its own'), findsOneWidget);
      expect(find.textContaining('No components'), findsNothing);
      expect(find.text('Add component'), findsOneWidget);
    });

    testWidgets('a parent row opens that assembly and has no edit actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        build(
          const [],
          FakeComponentRepository(),
          partOf: [parentEntry(travel, role: 'Octopus')],
          routed: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      await tester.tap(find.text('Travel reg'));
      await tester.pumpAndSettle();
      expect(find.text('Detail travel'), findsOneWidget);
    });

    testWidgets('a failed upward read is shown, and the parts still render', (
      tester,
    ) async {
      await tester.pumpWidget(
        build(
          [part('c1', first)],
          FakeComponentRepository(),
          partOfError: StateError('no database'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Something went wrong'), findsOneWidget);
      expect(find.text('DGX first stage'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('row labels (#2791)', () {
    /// An item that may carry an identifier, brand and model, or a serial.
    EquipmentItem gear(
      String id,
      String name,
      EquipmentType type, {
      String? identifier,
      String? brand,
      String? model,
      String? serial,
    }) => EquipmentItem(
      id: id,
      name: name,
      type: type,
      brand: brand,
      model: model,
      serialNumber: serial,
      attributes: [
        if (identifier != null)
          EquipmentAttribute.curated(
            equipmentId: id,
            key: EquipmentAttrKeys.identifier,
            valueText: identifier,
          ),
      ],
    );

    testWidgets('a part shows its identifier after its role', (tester) async {
      await tester.pumpWidget(
        build([
          part(
            'c1',
            gear(
              'z1',
              'HOG Zenith',
              EquipmentType.secondStage,
              identifier: 'Necklace',
            ),
            role: 'Second Stage',
          ),
          part(
            'c2',
            gear(
              'z2',
              'HOG Zenith',
              EquipmentType.secondStage,
              identifier: 'Primary',
            ),
            role: 'Second Stage',
            order: 1,
          ),
        ], FakeComponentRepository()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Second Stage · ID Necklace'), findsOneWidget);
      expect(find.text('Second Stage · ID Primary'), findsOneWidget);
    });

    testWidgets(
      'the label wraps rather than hiding the identifier on a phone',
      (tester) async {
        final rows = [
          part(
            'c1',
            gear(
              'z1',
              'HOG Zenith',
              EquipmentType.secondStage,
              brand: 'Halcyon',
              model: 'Zenith Pro',
              identifier: 'Necklace left',
            ),
            role: 'Second Stage',
          ),
        ];
        tester.view.devicePixelRatio = 1.0;
        // About 320 px of label beside the action icons. The label below
        // needs more than one line there whether the test font (every glyph
        // a full em wide) or a real one loaded by another bundled test file
        // draws it, so a one-line label always fails this.
        tester.view.physicalSize = const Size(600, 800);
        addTearDown(tester.view.reset);
        // In the open card, where the action icons take their room.
        await tester.pumpWidget(
          build(
            rows,
            FakeComponentRepository(),
            home: openCard(sittingWith(rows)),
          ),
        );
        await tester.pumpAndSettle();
        // find.text matches an ellipsized line too, so ask the paragraph
        // whether it had to cut the label short.
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text('Second Stage · Halcyon Zenith Pro · ID Necklace left'),
        );
        expect(paragraph.didExceedMaxLines, isFalse);
      },
    );

    testWidgets('a part with no role shows its type, then its identifier', (
      tester,
    ) async {
      await tester.pumpWidget(
        build([
          part(
            'c1',
            gear('sw', 'Swift', EquipmentType.transmitter, identifier: 'Bill'),
          ),
        ], FakeComponentRepository()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Transmitter · ID Bill'), findsOneWidget);
    });

    testWidgets('brand and model show when they differ from the name', (
      tester,
    ) async {
      await tester.pumpWidget(
        build([
          part(
            'c1',
            gear(
              'd3',
              'Yoke first',
              EquipmentType.firstStage,
              brand: 'HOG',
              model: 'D3',
              identifier: 'YOKE',
            ),
            role: 'First Stage',
          ),
        ], FakeComponentRepository()),
      );
      await tester.pumpAndSettle();
      expect(find.text('First Stage · HOG D3 · ID YOKE'), findsOneWidget);
    });

    testWidgets('identical parts are told apart by their serials', (
      tester,
    ) async {
      await tester.pumpWidget(
        build([
          part(
            'c1',
            gear('h1', 'MP hose', EquipmentType.hose, serial: 'A1'),
            role: 'Hose',
          ),
          part(
            'c2',
            gear('h2', 'MP hose', EquipmentType.hose, serial: 'B2'),
            role: 'Hose',
            order: 1,
          ),
        ], FakeComponentRepository()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hose · S/N A1'), findsOneWidget);
      expect(find.text('Hose · S/N B2'), findsOneWidget);
    });

    testWidgets('parts already told apart by their roles get no tie-break', (
      tester,
    ) async {
      await tester.pumpWidget(
        build([
          part(
            'c1',
            gear('z1', 'HOG Zenith', EquipmentType.secondStage, serial: 'A1'),
            role: 'Primary',
          ),
          part(
            'c2',
            gear('z2', 'HOG Zenith', EquipmentType.secondStage, serial: 'B2'),
            role: 'Octopus',
            order: 1,
          ),
        ], FakeComponentRepository()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Primary'), findsOneWidget);
      expect(find.text('Octopus'), findsOneWidget);
      expect(find.textContaining('S/N'), findsNothing);
    });

    testWidgets('a departed part keeps its badge beside the label', (
      tester,
    ) async {
      await tester.pumpWidget(
        build([
          part(
            'c1',
            EquipmentItem(
              id: 'old',
              name: 'Old hose',
              type: EquipmentType.hose,
              status: EquipmentStatus.retired,
              isActive: false,
              attributes: [
                EquipmentAttribute.curated(
                  equipmentId: 'old',
                  key: EquipmentAttrKeys.identifier,
                  valueText: 'H1',
                ),
              ],
            ),
          ),
        ], FakeComponentRepository()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hose · ID H1'), findsOneWidget);
      expect(find.text('Retired'), findsOneWidget);
    });

    testWidgets('parents already told apart by their rigs get no tie-break', (
      tester,
    ) async {
      await tester.pumpWidget(
        build(
          const [],
          FakeComponentRepository(),
          partOf: [
            parentEntry(
              gear(
                'ra1',
                'Regulator Assembly',
                EquipmentType.regulator,
                serial: 'R1',
              ),
              role: 'Second Stage',
              rigs: ['Backmount rig'],
            ),
            parentEntry(
              gear(
                'ra2',
                'Regulator Assembly',
                EquipmentType.regulator,
                serial: 'R2',
              ),
              role: 'Second Stage',
              rigs: ['Sidemount rig'],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Second Stage, in Backmount rig'), findsOneWidget);
      expect(find.text('Second Stage, in Sidemount rig'), findsOneWidget);
      expect(find.textContaining('S/N'), findsNothing);
    });

    testWidgets('a parent assembly shows its identifier too', (tester) async {
      await tester.pumpWidget(
        build(
          const [],
          FakeComponentRepository(),
          partOf: [
            parentEntry(
              gear(
                'ra1',
                'Regulator Assembly',
                EquipmentType.regulator,
                identifier: 'Yoke',
              ),
              role: 'Second Stage',
            ),
            parentEntry(
              gear(
                'ra2',
                'Regulator Assembly',
                EquipmentType.regulator,
                identifier: 'DIN',
              ),
              role: 'Second Stage',
              rigs: ['Sidemount rig'],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Second Stage · ID Yoke'), findsOneWidget);
      expect(
        find.text('Second Stage, in Sidemount rig · ID DIN'),
        findsOneWidget,
      );
    });
  });
}
