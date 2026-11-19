import 'package:flutter/material.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/widgets/instructor_picker_field.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

/// An instructor as a record keeps one (issue #4527, phase 3): the buddy
/// picked, and the name and number written down. One value, so a pick that
/// fills all three is one change.
typedef InstructorValue = ({String? id, String? name, String? number});

/// The instructor after a pick from the instructor picker: a buddy fills
/// the name and the number from their certification, overwriting both, so
/// a buddy with no card number clears a stale one; clearing the pick keeps
/// the text as it is, as the forms do.
InstructorValue instructorPicked(
  Buddy? buddy,
  Certification? instructorCert,
  InstructorValue previous,
) => buddy == null
    ? (id: null, name: previous.name, number: previous.number)
    : (id: buddy.id, name: buddy.name, number: instructorCert?.cardNumber);

/// The Instructor card's editor of any record with an instructor (a
/// certification, a course): the buddy picker, then the name and number,
/// all one [field].
class InstructorCardEditor<T> extends StatefulWidget {
  const InstructorCardEditor({
    super.key,
    required this.session,
    required this.field,
    required this.nameLabel,
    this.nameHint,
    required this.numberLabel,
    this.numberHint,
    required this.keyPrefix,
  });

  final EditSession<T> session;
  final EditField<T, InstructorValue> field;
  final String nameLabel;
  final String? nameHint;
  final String numberLabel;
  final String? numberHint;

  /// The text fields' keys are `'<keyPrefix>-instructor-name'` and
  /// `'<keyPrefix>-instructor-number'`.
  final String keyPrefix;

  @override
  State<InstructorCardEditor<T>> createState() =>
      _InstructorCardEditorState<T>();
}

class _InstructorCardEditorState<T> extends State<InstructorCardEditor<T>> {
  EditSession<T> get _session => widget.session;

  late final _name = FieldTextBinding<T, InstructorValue>(
    session: _session,
    field: widget.field,
    format: (v) => v.name ?? '',
    parse: (text) {
      final v = _session.valueOf(widget.field);
      return FieldValue((id: v.id, name: text, number: v.number));
    },
  );
  late final _number = FieldTextBinding<T, InstructorValue>(
    session: _session,
    field: widget.field,
    format: (v) => v.number ?? '',
    parse: (text) {
      final v = _session.valueOf(widget.field);
      return FieldValue((id: v.id, name: v.name, number: text));
    },
  );

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InstructorPickerField(
            instructorId: _session.valueOf(widget.field).id,
            onSelected: (buddy, instructorCert) {
              if (_session.isDisposed) return;
              _session.set(
                widget.field,
                instructorPicked(
                  buddy,
                  instructorCert,
                  _session.valueOf(widget.field),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          TextField(
            key: ValueKey('${widget.keyPrefix}-instructor-name'),
            controller: _name.controller,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: widget.nameLabel,
              prefixIcon: const Icon(Icons.person),
              hintText: widget.nameHint,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: ValueKey('${widget.keyPrefix}-instructor-number'),
            controller: _number.controller,
            decoration: InputDecoration(
              labelText: widget.numberLabel,
              prefixIcon: const Icon(Icons.badge),
              hintText: widget.numberHint,
            ),
          ),
        ],
      ),
    );
  }
}
