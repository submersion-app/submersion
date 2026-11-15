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

  group('pairLabelColumns', () {
    // A full set: enough items that the old pills, placed beside each
    // anchor, lay across the body and the gear drawn on it (issue #4553).
    final full = composeFigure([
      item('mask', EquipmentType.mask),
      item('reg', EquipmentType.regulator),
      item('octo', EquipmentType.secondStage),
      item('bcd', EquipmentType.bcd),
      item('suit', EquipmentType.wetsuit),
      item('hood', EquipmentType.hood),
      item('gloves', EquipmentType.gloves),
      item('boots', EquipmentType.boots),
      item('computer', EquipmentType.computer),
      item('compass', EquipmentType.compass),
      item('light', EquipmentType.light),
      item('knife', EquipmentType.knife),
      item('weights', EquipmentType.weights),
      item('fins', EquipmentType.fins),
      item('tank', EquipmentType.tank),
      item('smb', EquipmentType.smb),
      item('reel', EquipmentType.reel),
    ]);

    for (final width in const [600.0, 700.0, 900.0, 1400.0]) {
      test('at $width pt no label covers either figure', () {
        final layout = FigureLayout.forPair(
          Size(width, FigureLayout.maxHeight),
        );
        final slots = pairLabelColumns(
          model: full,
          layout: layout,
          width: width,
        );
        expect(slots.length, full.placed.length);
        expectNoOverlaps(slots);
        for (final s in slots) {
          final id = s.item.item.id;
          expect(s.rect.overlaps(layout.front), isFalse, reason: id);
          expect(s.rect.overlaps(layout.back), isFalse, reason: id);
        }
      });

      test('at $width pt each label stays in its own figure\'s half', () {
        final layout = FigureLayout.forPair(
          Size(width, FigureLayout.maxHeight),
        );
        for (final s in pairLabelColumns(
          model: full,
          layout: layout,
          width: width,
        )) {
          final front = s.item.zone!.view == FigureView.front;
          final halfLeft = front ? 0.0 : width / 2;
          final id = s.item.item.id;
          expect(
            s.rect.left,
            greaterThanOrEqualTo(halfLeft - 0.001),
            reason: id,
          );
          expect(
            s.rect.right,
            lessThanOrEqualTo(halfLeft + width / 2 + 0.001),
            reason: id,
          );
        }
      });
    }

    test('each label is level with its anchor when nothing is in the way', () {
      final layout = FigureLayout.forPair(const Size(900, 360));
      final slots = pairLabelColumns(
        model: composeFigure([
          item('computer', EquipmentType.computer),
          item('tank', EquipmentType.tank),
        ]),
        layout: layout,
        width: 900,
      );
      for (final s in slots) {
        expect(s.rect.center.dy, closeTo(s.anchor.dy, 0.001));
      }
    });
  });

  test('labelColumns keeps its columns inside the span it is given', () {
    // The back figure of a 900 pt pair, laid out in the right half.
    final layout = FigureLayout.forPair(const Size(900, 360));
    final slots = labelColumns(
      model: composeFigure([
        item('tank', EquipmentType.tank),
        item('smb', EquipmentType.smb),
        item('reel', EquipmentType.reel),
      ]),
      view: FigureView.back,
      layout: layout,
      left: 450,
      width: 450,
    );
    expect(slots, isNotEmpty);
    for (final s in slots) {
      expect(s.rect.left, greaterThanOrEqualTo(450));
      expect(s.rect.right, lessThanOrEqualTo(900.001));
      expect(s.rect.overlaps(layout.back), isFalse);
    }
  });
}
