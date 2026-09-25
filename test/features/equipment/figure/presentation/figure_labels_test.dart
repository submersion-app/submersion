import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_labels.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_layout.dart';

/// Labels are what make the figure readable at a glance, so where they go
/// is pinned here without widgets: which side, never overlapping, level with
/// their gear when there is room, and inside the box.
void main() {
  FigureItemInput item(String id, EquipmentType type) =>
      FigureItemInput(id: id, type: type, name: id);

  void expectNoOverlaps(List<FigureLabelSlot> slots) {
    for (var i = 0; i < slots.length; i++) {
      for (var j = i + 1; j < slots.length; j++) {
        expect(
          slots[i].rect.overlaps(slots[j].rect),
          isFalse,
          reason: '${slots[i].item.item.id} overlaps ${slots[j].item.item.id}',
        );
      }
    }
  }

  group('labelColumns', () {
    final layout = FigureLayout.forSingle(const Size(360, 420));
    final figure = layout.front;

    test('sides follow the anchor, centre anchors balance in number order', () {
      final model = composeFigure([
        item('mask', EquipmentType.mask), // face, centre
        item('reg', EquipmentType.regulator), // mouth, centre
        item('computer', EquipmentType.computer), // left wrist
        item('light', EquipmentType.light), // left hand
        item('fins', EquipmentType.fins), // centre
      ]);
      final slots = labelColumns(
        model: model,
        view: FigureView.front,
        layout: layout,
        width: 360,
      );
      final side = {for (final s in slots) s.item.item.id: s.onLeft};
      expect(side, {
        'mask': true,
        'reg': false,
        'computer': true,
        'light': true,
        'fins': false,
      });
      for (final s in slots) {
        if (s.onLeft) {
          expect(s.rect.right, lessThanOrEqualTo(figure.left));
        } else {
          expect(s.rect.left, greaterThanOrEqualTo(figure.right));
        }
      }
    });

    test('a phone column leaves room for a name', () {
      // 326 pt is the set page's figure box on a 390 pt phone.
      final phone = FigureLayout.forSingle(const Size(326, 420));
      final slots = labelColumns(
        model: composeFigure([
          item('mask', EquipmentType.mask),
          item('reg', EquipmentType.regulator),
        ]),
        view: FigureView.front,
        layout: phone,
        width: 326,
      );
      for (final s in slots) {
        expect(s.rect.width, greaterThanOrEqualTo(96));
      }
    });

    test('only the chosen view is labelled', () {
      final model = composeFigure([
        item('mask', EquipmentType.mask),
        item('tank', EquipmentType.tank),
      ]);
      final back = labelColumns(
        model: model,
        view: FigureView.back,
        layout: layout,
        width: 360,
      );
      expect(back.map((s) => s.item.item.id), ['tank']);
    });

    test('a lone label sits level with its anchor', () {
      final model = composeFigure([item('computer', EquipmentType.computer)]);
      final slot = labelColumns(
        model: model,
        view: FigureView.front,
        layout: layout,
        width: 360,
      ).single;
      expect(slot.rect.center.dy, closeTo(slot.anchor.dy, 0.001));
    });

    test(
      'a crowded column stacks without overlap and never rises above its anchor',
      () {
        final model = composeFigure([
          item('mask', EquipmentType.mask),
          item('reg', EquipmentType.regulator),
          item('snorkel', EquipmentType.snorkel),
          item('octo', EquipmentType.secondStage),
          item('computer', EquipmentType.computer),
          item('compass', EquipmentType.compass),
          item('light', EquipmentType.light),
          item('camera', EquipmentType.camera),
          item('weights', EquipmentType.weights),
          item('knife', EquipmentType.knife),
          item('fins', EquipmentType.fins),
        ]);
        final slots = labelColumns(
          model: model,
          view: FigureView.front,
          layout: layout,
          width: 360,
        );
        expect(slots.length, model.placed.length);
        expectNoOverlaps(slots);
        for (final s in slots) {
          expect(
            s.rect.top,
            greaterThanOrEqualTo(s.anchor.dy - kFigureLabelHeight / 2 - 0.001),
          );
          expect(s.rect.height, closeTo(kFigureLabelHeight, 1e-9));
        }
      },
    );
  });

  group('labelPills', () {
    final layout = FigureLayout.forSize(const Size(900, 360));

    List<FigureLabelSlot> pills(FigureModel model, {double natural = 120}) =>
        labelPills(
          model: model,
          layout: layout,
          width: 900,
          maxWidth: 900 / 4,
          widthOf: (_) => natural,
        );

    test('a pill sits on the outward side of its anchor', () {
      final model = composeFigure([
        item('computer', EquipmentType.computer), // left of centre
        item('tank', EquipmentType.tank), // back, centre
      ]);
      final byId = {for (final s in pills(model)) s.item.item.id: s};
      expect(byId['computer']!.onLeft, isTrue);
      expect(
        byId['computer']!.rect.right,
        lessThanOrEqualTo(byId['computer']!.anchor.dx),
      );
      expect(byId['tank']!.onLeft, isFalse);
      expect(
        byId['tank']!.rect.left,
        greaterThanOrEqualTo(byId['tank']!.anchor.dx),
      );
    });

    test('pills are capped at a quarter of the width and stay in the box', () {
      final model = composeFigure([
        item('computer', EquipmentType.computer),
        item('light', EquipmentType.light),
        item('reel', EquipmentType.reel),
      ]);
      for (final s in pills(model, natural: 5000)) {
        expect(s.rect.width, lessThanOrEqualTo(900 / 4 + 0.001));
        expect(s.rect.left, greaterThanOrEqualTo(0));
        expect(s.rect.right, lessThanOrEqualTo(900.001));
      }
    });

    test('a pill never crosses into the other figure', () {
      // Worst case: the default narrow gutter and names far too long.
      final tight = FigureLayout.forSize(const Size(900, 360));
      final model = composeFigure([
        item('mask', EquipmentType.mask),
        item('reg', EquipmentType.regulator),
        item('compass', EquipmentType.compass),
        item('fins', EquipmentType.fins),
        item('tank', EquipmentType.tank),
        item('trim', EquipmentType.weights),
      ]);
      final slots = labelPills(
        model: model,
        layout: tight,
        width: 900,
        maxWidth: 900 / 4,
        widthOf: (_) => 5000,
      );
      for (final s in slots) {
        final other = s.item.zone!.view == FigureView.front
            ? tight.back
            : tight.front;
        expect(
          s.rect.overlaps(other),
          isFalse,
          reason: '${s.item.item.id} crosses the other figure',
        );
      }
    });

    test('crowded pills step down until none overlap', () {
      final model = composeFigure([
        item('mask', EquipmentType.mask),
        item('reg', EquipmentType.regulator),
        item('octo', EquipmentType.secondStage),
        item('bcd', EquipmentType.bcd),
        item('computer', EquipmentType.computer),
        item('compass', EquipmentType.compass),
        item('light', EquipmentType.light),
        item('weights', EquipmentType.weights),
        item('reel', EquipmentType.reel),
        item('fins', EquipmentType.fins),
        item('tank', EquipmentType.tank),
        item('smb', EquipmentType.smb),
      ]);
      final slots = pills(model);
      expect(slots.length, model.placed.length);
      expectNoOverlaps(slots);
    });
  });
}
