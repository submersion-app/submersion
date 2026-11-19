import 'package:flutter/material.dart';

import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_fields.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

/// The editors of the trip Overview's cards (issue #4527, phase 3).

/// Notes: the trip's notes, day passages and all, as the form edited them.
class TripNotesCardEditor extends StatefulWidget {
  const TripNotesCardEditor({super.key, required this.session});

  final EditSession<Trip> session;

  @override
  State<TripNotesCardEditor> createState() => _TripNotesCardEditorState();
}

class _TripNotesCardEditorState extends State<TripNotesCardEditor> {
  late final _binding = FieldTextBinding<Trip, String>.plain(
    session: widget.session,
    field: tripNotesField,
    format: (v) => v,
  );

  @override
  void dispose() {
    _binding.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MarkdownNotesField(
    key: const Key('trip-edit-notes'),
    controller: _binding.controller,
    autofocus: true,
    decoration: InputDecoration(
      labelText: context.l10n.trips_edit_label_notes,
      prefixIcon: const Icon(Icons.notes),
      hintText: context.l10n.trips_edit_hint_notes,
      alignLabelWithHint: true,
    ),
    maxLines: 4,
  );
}
