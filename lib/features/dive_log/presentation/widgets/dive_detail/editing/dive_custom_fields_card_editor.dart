import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/custom_field_input_row.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const _uuid = Uuid();

/// The rows of [fields] that are written: a row with no key is not, as
/// the dive form drops it on save.
List<DiveCustomField> _kept(List<DiveCustomField> fields) => [
  for (final field in fields)
    if (field.key.trim().isNotEmpty) field,
];

bool _sameFields(List<DiveCustomField> a, List<DiveCustomField> b) {
  final left = _kept(a);
  final right = _kept(b);
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    final x = left[i];
    final y = right[i];
    if (x.id != y.id || x.key != y.key || x.value != y.value) return false;
  }
  return true;
}

/// The dive's custom fields, in their order, edited on the Custom fields
/// card. A row with an empty key is dropped when written, as the form does;
/// the rows are numbered in the order they are written. The order is part
/// of the value, so a reorder is a change.
final diveCustomFieldsField = EditField<Dive, List<DiveCustomField>>(
  id: 'customFields',
  cardId: DiveDetailSectionId.customFields.name,
  read: (dive) => dive.customFields,
  write: (dive, fields) {
    final kept = _kept(fields);
    return dive.copyWith(
      customFields: [
        for (var i = 0; i < kept.length; i++) kept[i].copyWith(sortOrder: i),
      ],
    );
  },
  equals: _sameFields,
);

/// The Custom fields card's editor: one row per field, in order, with
/// their keys suggested from the diver's other dives.
///
/// The rows are kept here as well as in the sitting, because a row still
/// without a key is no change of the dive and the sitting does not hold
/// it; it stays on screen until the diver types a key or removes it.
class DiveCustomFieldsCardEditor extends ConsumerStatefulWidget {
  const DiveCustomFieldsCardEditor({super.key, required this.session});

  final EditSession<Dive> session;

  @override
  ConsumerState<DiveCustomFieldsCardEditor> createState() =>
      _DiveCustomFieldsCardEditorState();
}

class _DiveCustomFieldsCardEditorState
    extends ConsumerState<DiveCustomFieldsCardEditor> {
  late List<DiveCustomField> _rows = widget.session.valueOf(
    diveCustomFieldsField,
  );

  /// Moves when the rows are replaced from outside (the stored dive changed
  /// underneath), so each row is built again with the text it now holds.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_follow);
  }

  @override
  void didUpdateWidget(DiveCustomFieldsCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session == widget.session) return;
    oldWidget.session.removeListener(_follow);
    widget.session.addListener(_follow);
    _follow();
  }

  @override
  void dispose() {
    widget.session.removeListener(_follow);
    super.dispose();
  }

  /// The rows follow the sitting when it holds something else than they
  /// do: only when the stored dive changed under rows the diver has not
  /// touched.
  void _follow() {
    if (!mounted) return;
    final value = widget.session.valueOf(diveCustomFieldsField);
    if (_sameFields(value, _rows)) return;
    setState(() {
      _rows = value;
      _generation++;
    });
  }

  void _set(List<DiveCustomField> rows) {
    setState(() => _rows = List.unmodifiable(rows));
    widget.session.set(diveCustomFieldsField, _rows);
  }

  @override
  Widget build(BuildContext context) {
    final diverId = ref.watch(currentDiverIdProvider);
    final suggestions = diverId == null
        ? const <String>[]
        : ref.watch(customFieldKeySuggestionsProvider(diverId)).valueOrNull ??
              const <String>[];
    final rows = _rows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rows.isNotEmpty)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: rows.length,
            onReorderItem: (oldIndex, newIndex) {
              final next = [..._rows];
              next.insert(newIndex, next.removeAt(oldIndex));
              _set(next);
            },
            itemBuilder: (context, index) {
              final field = rows[index];
              return CustomFieldInputRow(
                key: ValueKey('${field.id}#$_generation'),
                index: index,
                field: field,
                keySuggestions: suggestions,
                // The rows as they are now, not as they were built: two
                // keystrokes can arrive before the next build.
                onChanged: (updated) => _set([..._rows]..[index] = updated),
                onDelete: () => _set([..._rows]..removeAt(index)),
              );
            },
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _set([
            ..._rows,
            DiveCustomField(
              id: _uuid.v4(),
              key: '',
              value: '',
              sortOrder: _rows.length,
            ),
          ]),
          icon: const Icon(Icons.add),
          label: Text(context.l10n.diveLog_edit_addCustomField),
        ),
      ],
    );
  }
}
