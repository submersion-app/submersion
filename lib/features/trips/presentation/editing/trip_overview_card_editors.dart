import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/domain/entities/liveaboard_details.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_day_notes.dart';
import 'package:submersion/features/trips/presentation/editing/trip_card_ids.dart';
import 'package:submersion/features/trips/presentation/editing/trip_edit_fields.dart';
import 'package:submersion/features/trips/presentation/editing/trip_vessel_sitting.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_day_note_editing.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_day_notes_vocabulary.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_field_marks.dart';
import 'package:submersion/shared/widgets/record_editing/reveal_answering.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';

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

/// Plan: the four numbers the fill forecast and the scrubber margin plan
/// with. Blank, zero or below is none (divers sharing: one), as the form
/// stored them. Each field carries the form's label above and its hint
/// below: the labels are too long for a number row's label column.
class TripPlanCardEditor extends StatelessWidget {
  const TripPlanCardEditor({super.key, required this.session});

  final EditSession<Trip> session;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlanNumberField(
          key: const Key('trip-edit-dives-per-day'),
          session: session,
          field: tripDivesPerDayField,
          label: l10n.trips_edit_label_divesPerDay,
          hint: l10n.trips_edit_hint_divesPerDay,
          icon: Icons.today_outlined,
          autofocus: true,
        ),
        const SizedBox(height: 12),
        _PlanNumberField(
          key: const Key('trip-edit-divers-sharing'),
          session: session,
          field: tripDiversSharingField,
          label: l10n.trips_edit_label_diversSharing,
          hint: l10n.trips_edit_hint_diversSharing,
          icon: Icons.groups_outlined,
        ),
        const SizedBox(height: 12),
        _PlanNumberField(
          key: const Key('trip-edit-expected-dives'),
          session: session,
          field: tripExpectedDivesField,
          label: l10n.trips_edit_label_expectedDives,
          hint: l10n.trips_edit_hint_expectedDives,
          icon: Icons.scuba_diving,
        ),
        const SizedBox(height: 12),
        _PlanNumberField(
          key: const Key('trip-edit-expected-runtime'),
          session: session,
          field: tripExpectedRuntimeField,
          label: l10n.trips_edit_label_expectedRuntime,
          hint: l10n.trips_edit_hint_expectedRuntime,
          icon: Icons.timer_outlined,
        ),
      ],
    );
  }
}

/// One whole-number field of the Plan card. Text that is not a whole
/// number never reaches the sitting: the field says so, and the card stays
/// open and refuses the Save until it is fixed, as a number row does.
class _PlanNumberField extends StatefulWidget {
  const _PlanNumberField({
    super.key,
    required this.session,
    required this.field,
    required this.label,
    required this.hint,
    required this.icon,
    this.autofocus = false,
  });

  final EditSession<Trip> session;
  final EditField<Trip, double?> field;
  final String label;
  final String hint;
  final IconData icon;
  final bool autofocus;

  @override
  State<_PlanNumberField> createState() => _PlanNumberFieldState();
}

class _PlanNumberFieldState extends State<_PlanNumberField>
    with
        RevealAnswering<_PlanNumberField>,
        RecordFieldMarks<Trip, _PlanNumberField> {
  late final FieldTextBinding<Trip, double?> _binding =
      FieldTextBinding<Trip, double?>(
        session: widget.session,
        field: widget.field,
        format: (v) => v == null ? '' : '${v.toInt()}',
        parse: (text) => switch (readNumber(text, integer: true)) {
          NumberBlank() => const FieldValue<double?>(null),
          NumberInvalid() => const FieldUnreadable<double?>(),
          NumberValue(:final value) => FieldValue<double?>(value),
        },
        onUnreadableChanged: reportUnreadable,
      );

  @override
  String get markCardId => widget.field.cardId;

  @override
  String get markFieldId => widget.field.id;

  @override
  void dispose() {
    _binding.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _binding.controller,
      builder: (context, _) => TextField(
        controller: _binding.controller,
        autofocus: widget.autofocus,
        // The filter keeps '-', so "-3" stores none rather than 3.
        inputFormatters: numberInputFormatters(),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: Icon(widget.icon),
          helperText: widget.hint,
          helperMaxLines: 3,
          errorText: invalidNumberText(
            context,
            _binding.controller.text,
            integer: true,
          ),
        ),
      ),
    );
  }
}

/// Vessel: a liveaboard's details, held as the sitting's one row of them.
/// The vessel name is required, as the form required it.
class TripVesselCardEditor extends ConsumerStatefulWidget {
  const TripVesselCardEditor({super.key, required this.session});

  final EditSession<Trip> session;

  @override
  ConsumerState<TripVesselCardEditor> createState() =>
      _TripVesselCardEditorState();
}

class _TripVesselCardEditorState extends ConsumerState<TripVesselCardEditor> {
  static const _capacityId = 'capacity';

  late final _list = tripVesselDetails(
    ref.read(liveaboardDetailsRepositoryProvider),
  );
  late final Listenable _changes = _list.changes(widget.session);

  final _name = TextEditingController();
  final _operator = TextEditingController();
  final _cabin = TextEditingController();
  final _capacity = TextEditingController();
  final _embark = TextEditingController();
  final _disembark = TextEditingController();

  /// Whether the controllers hold the sitting's row yet.
  bool _filled = false;

  /// The page's controller, told when the capacity cannot be read, kept so
  /// the mark can be withdrawn when this editor goes away (the trip made a
  /// resort trip, say), or it would refuse every Save for a card no longer
  /// on the page.
  RecordEditController<Trip>? _marks;
  bool _capacityMarked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _marks = RecordEditScope.maybeOf<Trip>(context);
  }

  void _markCapacity(bool unreadable) {
    if (unreadable == _capacityMarked) return;
    _capacityMarked = unreadable;
    _marks?.setFieldInvalid(
      TripCardId.vessel.name,
      _capacityId,
      invalid: unreadable,
    );
  }

  @override
  void initState() {
    super.initState();
    _changes.addListener(_onChanged);
    _list.load(widget.session);
    _fill();
  }

  @override
  void dispose() {
    _markCapacity(false);
    _changes.removeListener(_onChanged);
    for (final c in [
      _name,
      _operator,
      _cabin,
      _capacity,
      _embark,
      _disembark,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    _fill();
    setState(() {});
  }

  /// Puts the sitting's row into the fields once it has been read.
  void _fill() {
    if (_filled || _list.current(widget.session) == null) return;
    final row = _row;
    _filled = true;
    _name.text = row.vesselName;
    _operator.text = row.operatorName ?? '';
    _cabin.text = row.cabinType ?? '';
    _capacity.text = row.capacity?.toString() ?? '';
    _embark.text = row.embarkPort ?? '';
    _disembark.text = row.disembarkPort ?? '';
  }

  /// The row the sitting holds, or a new one for a liveaboard with none.
  LiveaboardDetails get _row =>
      tripVesselInSitting(_list, widget.session) ??
      tripVesselDraft(widget.session.stored.id);

  void _set(LiveaboardDetails next) => _list.set(widget.session, [next]);

  /// Blank stores none, as the form stored it.
  static String? _text(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _onCapacity(String text) {
    final read = readNumber(text, integer: true);
    _markCapacity(read is NumberInvalid);
    switch (read) {
      case NumberValue(:final value):
        // Zero or below is no capacity, as the form stored it.
        _set(_row.copyWith(capacity: tripPositiveOrNull(value)));
      case NumberBlank():
        _set(_row.copyWith(capacity: null));
      case NumberInvalid():
        setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_list.current(widget.session) == null) {
      // A read that failed says so and offers another; the Save waits for
      // one still running.
      if (_list.failed(widget.session)) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(child: Text(l10n.common_error_tryAgain)),
              TextButton(
                onPressed: () {
                  _list.load(widget.session);
                  setState(() {});
                },
                child: Text(l10n.common_action_retry),
              ),
            ],
          ),
        );
      }
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    final row = _row;
    final nameBlank = row.vesselName.trim().isEmpty;
    final capacityError = invalidNumberText(
      context,
      _capacity.text,
      integer: true,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('trip-edit-vessel-name'),
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => _set(_row.copyWith(vesselName: v.trim())),
          decoration: InputDecoration(
            labelText: l10n.trips_edit_label_vesselName,
            prefixIcon: const Icon(Icons.directions_boat),
            hintText: l10n.trips_edit_hint_vesselName,
            errorText: nameBlank
                ? l10n.trips_edit_validation_vesselRequired
                : null,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('trip-edit-vessel-operator'),
          controller: _operator,
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => _set(_row.copyWith(operatorName: _text(v))),
          decoration: InputDecoration(
            labelText: l10n.trips_edit_label_operatorName,
            prefixIcon: const Icon(Icons.business),
            hintText: l10n.trips_edit_hint_operatorName,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: const Key('trip-edit-vessel-type'),
          initialValue: row.vesselType,
          decoration: InputDecoration(
            labelText: l10n.trips_edit_label_vesselType,
            prefixIcon: const Icon(Icons.category),
          ),
          items: [
            DropdownMenuItem(
              value: 'catamaran',
              child: Text(l10n.trips_vesselType_catamaran),
            ),
            DropdownMenuItem(
              value: 'motorYacht',
              child: Text(l10n.trips_vesselType_motorYacht),
            ),
            DropdownMenuItem(
              value: 'sailingYacht',
              child: Text(l10n.trips_vesselType_sailingYacht),
            ),
            DropdownMenuItem(
              value: 'other',
              child: Text(l10n.trips_vesselType_other),
            ),
          ],
          onChanged: (v) => _set(_row.copyWith(vesselType: v)),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('trip-edit-vessel-cabin'),
          controller: _cabin,
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => _set(_row.copyWith(cabinType: _text(v))),
          decoration: InputDecoration(
            labelText: l10n.trips_edit_label_cabinType,
            prefixIcon: const Icon(Icons.bed),
            hintText: l10n.trips_edit_hint_cabinType,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('trip-edit-vessel-capacity'),
          controller: _capacity,
          // The filter keeps '-', so "-3" stores none rather than 3.
          inputFormatters: numberInputFormatters(),
          keyboardType: TextInputType.number,
          onChanged: _onCapacity,
          decoration: InputDecoration(
            labelText: l10n.trips_edit_label_capacity,
            prefixIcon: const Icon(Icons.people),
            errorText: capacityError,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('trip-edit-vessel-embark'),
          controller: _embark,
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => _set(_row.copyWith(embarkPort: _text(v))),
          decoration: InputDecoration(
            labelText: l10n.trips_edit_label_embarkPort,
            prefixIcon: const Icon(Icons.login),
            hintText: l10n.trips_edit_hint_embarkPort,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('trip-edit-vessel-disembark'),
          controller: _disembark,
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => _set(_row.copyWith(disembarkPort: _text(v))),
          decoration: InputDecoration(
            labelText: l10n.trips_edit_label_disembarkPort,
            prefixIcon: const Icon(Icons.logout),
            hintText: l10n.trips_edit_hint_disembarkPort,
          ),
        ),
      ],
    );
  }
}

/// Day plan, on a day of the trip's story: that day's passage of the
/// Notes, alone. It is the Notes card there: what it writes is the notes,
/// under the day's heading, placed as the form placed it, and an added
/// heading with nothing under it is no change.
class TripDayPlanCardEditor extends StatefulWidget {
  const TripDayPlanCardEditor({
    super.key,
    required this.session,
    required this.day,
  });

  final EditSession<Trip> session;
  final TripNoteDay day;

  @override
  State<TripDayPlanCardEditor> createState() => _TripDayPlanCardEditorState();
}

class _TripDayPlanCardEditorState extends State<TripDayPlanCardEditor> {
  /// Where the day's passage is in the notes the editor last placed it in.
  late DayNotePlacement _placement;
  late DayPassage _parts;
  final TextEditingController _controller = TextEditingController();

  /// The notes as the sitting had them when this editor last placed the
  /// passage or wrote it. Notes changed otherwise (another card, or the
  /// stored trip followed while they are untouched) are placed again, so a
  /// keystroke here never writes back notes from before that change.
  String? _seen;

  /// Whether this editor is writing the notes, so its own change is not
  /// taken for one made elsewhere.
  bool _writing = false;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seen == null) _place();
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    _controller.dispose();
    super.dispose();
  }

  /// Finds the day's passage in the sitting's notes, and shows it.
  void _place() {
    final l10n = context.l10n;
    final notes = widget.session.valueOf(tripNotesField);
    _seen = notes;
    _placement = placeDayNoteIn(notes, widget.day, l10n);
    _parts = dayPassageOf(
      _placement,
      widget.day,
      tripDayNotesVocabularyFor(l10n),
    );
    if (_controller.text == _parts.passage) return;
    _controller.value = TextEditingValue(
      text: _parts.passage,
      selection: TextSelection.collapsed(offset: _parts.passage.length),
    );
  }

  void _onSession() {
    if (_writing || !mounted || widget.session.isDisposed) return;
    if (widget.session.valueOf(tripNotesField) == _seen) return;
    _place();
  }

  void _onChanged(String passage) {
    final session = widget.session;
    _writing = true;
    try {
      session.set(tripNotesField, withDayPassage(_placement, _parts, passage));
    } finally {
      _writing = false;
    }
    _seen = session.valueOf(tripNotesField);
  }

  @override
  Widget build(BuildContext context) => MarkdownNotesField(
    key: const Key('trip-edit-day-note'),
    controller: _controller,
    autofocus: true,
    onChanged: _onChanged,
    decoration: InputDecoration(
      labelText: context.l10n.trips_story_dayLabel(widget.day.dayNumber),
      prefixIcon: const Icon(Icons.edit_note),
      alignLabelWithHint: true,
    ),
    maxLines: 4,
  );
}
