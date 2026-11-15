import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/text/blank_text.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/courses/presentation/widgets/course_picker.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_text_suggestion_field.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_mode_label.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_details_derived_rows.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_trip_rows.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_visibility_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_site_assignment.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_multi_select_field.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/suggested_text_row.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row_group.dart';
import 'package:submersion/shared/widgets/forms/enum_picker_row.dart';
import 'package:submersion/shared/widgets/forms/form_overline.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

/// The inset of a picker that is not a form row, matching the dive form.
const _pickerPadding = EdgeInsets.fromLTRB(14, 10, 14, 10);

/// The Details card's editor. Rows keep the order the read card shows them
/// in.
///
/// It edits the dive's types, trip, dive center, operator, boat, captain,
/// courses, visibility and water type, and the two statistics switches.
/// The rows the card shows without owning stay where the read card has
/// them, as rows that cannot be typed in, so nothing the card showed
/// disappears when it opens: dive mode (edited with the tanks), average
/// depth (edited with the dive's times and depths), and everything that is
/// calculated or imported.
class DiveDetailsCardEditor extends ConsumerStatefulWidget {
  const DiveDetailsCardEditor({super.key, required this.session});

  final EditSession<Dive> session;

  @override
  ConsumerState<DiveDetailsCardEditor> createState() =>
      _DiveDetailsCardEditorState();
}

class _DiveDetailsCardEditorState extends ConsumerState<DiveDetailsCardEditor> {
  // The text bindings, each made when its row first needs it. Never made on
  // the way out: an editor that goes before it has built must not start
  // listening to a sitting that may already have ended.
  FieldTextBinding<Dive, String?>? _operatorBound;
  FieldTextBinding<Dive, String?>? _boatBound;
  FieldTextBinding<Dive, String?>? _captainBound;

  FieldTextBinding<Dive, String?> get _operator =>
      _operatorBound ??= _words(diveOperatorField);
  FieldTextBinding<Dive, String?> get _boat =>
      _boatBound ??= _words(diveBoatNameField);
  FieldTextBinding<Dive, String?> get _captain =>
      _captainBound ??= _words(diveBoatCaptainField);

  /// A free-text row: blank is no value.
  FieldTextBinding<Dive, String?> _words(EditField<Dive, String?> field) {
    return FieldTextBinding<Dive, String?>(
      session: widget.session,
      field: field,
      format: (value) => value ?? '',
      parse: (text) => FieldValue(trimmedOrNull(text)),
    );
  }

  void _disposeBindings() {
    _operatorBound?.dispose();
    _boatBound?.dispose();
    _captainBound?.dispose();
    _operatorBound = _boatBound = _captainBound = null;
  }

  @override
  void didUpdateWidget(DiveDetailsCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another sitting: the rows bind to it as they are next built.
    if (oldWidget.session != widget.session) _disposeBindings();
  }

  @override
  void dispose() {
    _disposeBindings();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final session = widget.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final dive = session.working;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: _pickerPadding,
              child: DiveTypeMultiSelectField(
                selectedTypeIds: session.valueOf(diveTypeIdsField),
                // The types the dive is stored with are offered even when
                // hidden (issue #401), so unticking one can be undone.
                keepTypeIds: session.stored.diveTypeIds,
                onChanged: (ids) {
                  // A type a site added that the diver unticks is theirs.
                  diveTypesEditedByHand(session, ids);
                  session.set(diveTypeIdsField, ids);
                },
              ),
            ),
            FormRow.display(
              label: l10n.diveLog_diveMode_title,
              value: diveModeLabel(l10n, dive.diveMode),
            ),
            DiveTripRow(session: session),
            DiveCenterRow(session: session),
            ..._logisticsRows(l10n),
            Padding(
              padding: _pickerPadding,
              child: CourseMultiSelectField(
                selectedCourseIds: session.valueOf(diveCourseIdsField),
                labelText: l10n.diveLog_edit_section_trainingCourses,
                onChanged: (ids) => session.set(diveCourseIdsField, ids),
              ),
            ),
            DiveVisibilityRow(session: session),
            if (dive.avgDepth != null)
              FormRow.display(
                label: l10n.diveLog_detail_label_avgDepth,
                value: units.formatDepth(dive.avgDepth),
              ),
            EnumPickerRow<WaterType>(
              label: l10n.diveLog_edit_label_waterType,
              value: session.valueOf(diveWaterTypeField),
              values: WaterType.values,
              displayName: (value) => value.localizedName(l10n),
              // A dive with no water type of its own shows its site's.
              hint: dive.site?.waterType?.localizedName(l10n),
              onChanged: (value) => session.set(diveWaterTypeField, value),
            ),
            // Inset like the form rows above, so the labels line up, and
            // in a group of their own, so their values share one column as
            // they do on the read card.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: DetailRowGroup(child: DiveDetailsDerivedRows(dive: dive)),
            ),
            FormOverline(label: l10n.diveLog_edit_group_statistics),
            ..._statisticsRows(l10n),
          ],
        );
      },
    );
  }

  List<Widget> _logisticsRows(AppLocalizations l10n) {
    return [
      SuggestedTextRow(
        label: l10n.diveLog_edit_row_diveOperator,
        controller: _operator.controller,
        field: DiveTextSuggestionField.diveOperator,
      ),
      SuggestedTextRow(
        label: l10n.diveLog_edit_row_boatName,
        controller: _boat.controller,
        field: DiveTextSuggestionField.boatName,
      ),
      SuggestedTextRow(
        label: l10n.diveLog_edit_row_boatCaptain,
        controller: _captain.controller,
        field: DiveTextSuggestionField.boatCaptain,
      ),
    ];
  }

  /// The two statistics switches, as the dive form draws them (#526,
  /// #1272). They are held apart: the master one implies the gas one, so
  /// the gas switch shows on and cannot be changed while it is set, and
  /// switching it off again gives back the diver's own gas-only choice.
  List<Widget> _statisticsRows(AppLocalizations l10n) {
    final session = widget.session;
    final excluded = session.valueOf(diveExcludedFromStatsField);
    final gasExcluded = session.valueOf(diveExcludedFromGasStatsField);
    return [
      FormRow.toggle(
        key: const Key('dive-edit-exclude-from-stats'),
        label: l10n.diveLog_edit_excludeFromStats,
        value: excluded,
        onChanged: (value) => session.set(diveExcludedFromStatsField, value),
        helpText: l10n.diveLog_edit_excludeFromStatsHelp,
      ),
      FormRow.toggle(
        key: const Key('dive-edit-exclude-from-gas-stats'),
        label: l10n.diveLog_edit_excludeFromGasStats,
        value: excluded || gasExcluded,
        onChanged: (value) => session.set(diveExcludedFromGasStatsField, value),
        enabled: !excluded,
        helpText: l10n.diveLog_edit_excludeFromGasStatsHelp,
      ),
    ];
  }
}
