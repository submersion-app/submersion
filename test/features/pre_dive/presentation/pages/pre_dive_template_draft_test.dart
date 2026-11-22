import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_editable_item.dart';
import 'package:submersion/features/pre_dive/presentation/pages/pre_dive_template_draft.dart';

EditablePreDiveItem _item(
  String id, {
  double? valueMin,
  String? sourceItemId,
  DateTime? updatedAt,
}) => EditablePreDiveItem(
  id: id,
  title: 'Cell 1',
  itemType: PreDiveItemType.value,
  valueMin: valueMin,
  sourceItemId: sourceItemId,
  createdAt: DateTime(2026),
  updatedAt: updatedAt ?? DateTime(2026),
);

PreDiveTemplateDraft _draft({
  bool strictOrder = false,
  List<EditablePreDiveItem> items = const [],
}) => preDiveTemplateDraft(
  name: 'Twinset',
  description: '',
  category: '',
  strictOrder: strictOrder,
  sections: const [],
  itemsInDisplayOrder: items,
);

void main() {
  test('items differing only in their stamps are equal', () {
    expect(
      _draft(items: [_item('a', updatedAt: DateTime(2026, 1, 1, 0, 0, 1))]),
      _draft(items: [_item('a')]),
    );
  });

  test('a threshold of 0.30000000000000004 and one of 0.3 draft alike', () {
    expect(
      _draft(items: [_item('a', valueMin: 0.1 + 0.2)]),
      _draft(items: [_item('a', valueMin: 0.3)]),
    );
  });

  test('a threshold drafts alike whatever the number locale', () {
    final item = _item('a', valueMin: 0.5);
    expect(
      Intl.withLocale('de', () => _draft(items: [item])),
      Intl.withLocale('en', () => _draft(items: [item])),
    );
  });

  EditablePreDiveItem plain(
    String id, {
    PreDiveItemType type = PreDiveItemType.check,
    String title = 'Air on',
    String notes = '',
    String? sectionId,
    String? valueLabel,
    String? valueUnit,
    double? valueMin,
    String? equipmentId,
    String? sourceItemId,
  }) => EditablePreDiveItem(
    id: id,
    title: title,
    notes: notes,
    sectionId: sectionId,
    itemType: type,
    valueLabel: valueLabel,
    valueUnit: valueUnit,
    valueMin: valueMin,
    equipmentId: equipmentId,
    sourceItemId: sourceItemId,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('an item drafts as its dialog writes it: title and notes trimmed', () {
    expect(
      _draft(
        items: [plain('a', title: 'Air on ', notes: ' slowly')],
      ),
      _draft(items: [plain('a', notes: 'slowly')]),
    );
  });

  test('a check item drafts no value fields, equipment or source', () {
    expect(
      _draft(
        items: [
          plain(
            'a',
            valueLabel: 'Pressure',
            valueUnit: 'bar',
            valueMin: 3,
            equipmentId: 'eq-1',
            sourceItemId: 'b',
          ),
          plain('b', type: PreDiveItemType.value),
        ],
      ),
      _draft(
        items: [
          plain('a'),
          plain('b', type: PreDiveItemType.value),
        ],
      ),
    );
  });

  test('a blank value label drafts as none', () {
    expect(
      _draft(
        items: [plain('a', type: PreDiveItemType.value, valueLabel: ' ')],
      ),
      _draft(items: [plain('a', type: PreDiveItemType.value)]),
    );
  });

  test('a source link to no value item drafts as none', () {
    PreDiveTemplateDraft linked(String? source) => _draft(
      items: [
        plain(
          'cell',
          type: PreDiveItemType.cellLinearity,
          sourceItemId: source,
        ),
        plain('check'),
      ],
    );
    expect(linked('gone'), linked(null));
    expect(linked('check'), linked(null));
    expect(linked('cell'), linked(null));
  });

  test('a source link to a value item is kept', () {
    PreDiveTemplateDraft linked(String? source) => _draft(
      items: [
        plain(
          'cell',
          type: PreDiveItemType.cellLinearity,
          sourceItemId: source,
        ),
        plain('air', type: PreDiveItemType.value),
      ],
    );
    expect(linked('air'), isNot(linked(null)));
  });

  test('an item naming a section the form lacks drafts as unsectioned', () {
    expect(
      _draft(items: [plain('a', sectionId: 'gone')]),
      _draft(items: [plain('a')]),
    );
  });

  test('a changed threshold is a change', () {
    expect(
      _draft(items: [_item('a', valueMin: 0.4)]),
      isNot(_draft(items: [_item('a', valueMin: 0.3)])),
    );
  });

  test('turning strict order on is a change', () {
    expect(_draft(strictOrder: true), isNot(_draft()));
  });

  test('a cleared source link is a change', () {
    // A cell linearity item reading the value item 'air'.
    EditablePreDiveItem cell(String? source) => EditablePreDiveItem(
      id: 'cell',
      title: 'Cell 1',
      itemType: PreDiveItemType.cellLinearity,
      sourceItemId: source,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final air = _item('air');
    expect(
      _draft(items: [cell(null), air]),
      isNot(_draft(items: [cell('air'), air])),
    );
  });

  test('equal drafts share a hash code', () {
    expect(
      _draft(items: [_item('a', valueMin: 1)]).hashCode,
      _draft(items: [_item('a', valueMin: 1)]).hashCode,
    );
  });
}
