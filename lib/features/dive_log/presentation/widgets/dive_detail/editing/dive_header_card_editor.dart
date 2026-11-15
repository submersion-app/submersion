import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/text/blank_text.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_mode_label.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_time_rows.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_site_row.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';
import 'package:submersion/shared/widgets/record_editing/record_number_row.dart';

/// The header block as a card of the dive page (issue #4527). It is never
/// absent, and it is not a section the diver can hide or move, so the Add
/// strip never offers it.
final diveHeaderCard = EditCard<Dive>(
  id: diveHeaderCardId,
  title: (context) => context.l10n.diveLog_detail_section_header,
  isEmpty: (_) => false,
  editorBuilder: (context, session) => DiveHeaderCardEditor(session: session),
);

/// The header block's editor, in the order the hero reads: number, name,
/// site, entry, exit, rating, the mode and types it shows but does not own,
/// the depths and times with their profile suggestions, water temperature,
/// favourite, and the planned switch.
class DiveHeaderCardEditor extends ConsumerStatefulWidget {
  const DiveHeaderCardEditor({super.key, required this.session});

  final EditSession<Dive> session;

  @override
  ConsumerState<DiveHeaderCardEditor> createState() =>
      _DiveHeaderCardEditorState();
}

class _DiveHeaderCardEditorState extends ConsumerState<DiveHeaderCardEditor> {
  /// Made on first use and disposed only if made, so an editor that goes
  /// before it builds leaves nothing behind.
  FieldTextBinding<Dive, String?>? _name;

  FieldTextBinding<Dive, String?> get _nameBinding =>
      _name ??= FieldTextBinding<Dive, String?>(
        session: widget.session,
        field: diveNameField,
        format: (value) => value ?? '',
        parse: (text) => FieldValue(trimmedOrNull(text)),
      );

  @override
  void didUpdateWidget(DiveHeaderCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session == widget.session) return;
    _name?.dispose();
    _name = null;
  }

  @override
  void dispose() {
    _name?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final session = widget.session;
    // Null while the sources load, which offers no planned switch.
    final hasPrimarySource = ref
        .watch(
          diveDataSourcesProvider(
            session.stored.id,
          ).select((sources) => sources.valueOrNull),
        )
        ?.any((source) => source.isPrimary);
    final typesById = {
      for (final type
          in ref.watch(diveTypesProvider).value ?? const <DiveTypeEntity>[])
        type.id: type,
    };
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._identity(l10n, units),
          ..._shownElsewhere(l10n, typesById),
          ..._numbers(l10n, units),
          ..._flags(l10n, hasPrimarySource),
        ],
      ),
    );
  }

  /// Number, name, site, entry, exit and rating.
  List<Widget> _identity(AppLocalizations l10n, UnitFormatter units) {
    final session = widget.session;
    final working = session.working;
    final entry = session.valueOf(diveEntryField);
    final exit = session.valueOf(diveExitField);
    final entryDay = DateTime(entry.year, entry.month, entry.day);
    final exitDay = exit == null
        ? entryDay
        : DateTime(exit.year, exit.month, exit.day);
    final rating = session.valueOf(diveRatingField) ?? 0;
    return [
      // A planned dive, or a draft, holds no number until it is logged.
      if (!working.isPlanned && !working.isDraft)
        RecordNumberRow<Dive>(
          session: session,
          field: diveNumberField,
          label: l10n.diveLog_edit_label_diveNumber,
          placeholder: l10n.diveLog_edit_row_notSet,
          integer: true,
          allowNegative: false,
        ),
      FormRow.text(
        label: l10n.diveLog_edit_label_diveName,
        controller: _nameBinding.controller,
        placeholder: l10n.diveLog_edit_diveNamePlaceholder,
      ),
      DiveSiteRow(session: session),
      DiveTimeRow(
        label: l10n.diveLog_edit_row_entry,
        value: entry,
        stored: diveEntryField.read(session.stored),
        onPicked: (time) => setEntryTime(session, time),
        firstDate: DateTime(1950),
        // As the form, up to tomorrow; a planned dive further ahead keeps
        // its own day.
        lastDate: _later(DateTime.now().add(const Duration(days: 1)), entryDay),
      ),
      DiveTimeRow(
        label: l10n.diveLog_edit_row_exit,
        value: exit,
        hint: estimatedExit(working),
        stored: session.stored.exitTime,
        onPicked: (time) => setExitTime(session, time),
        onClear: () => setExitTime(session, null),
        // As the form: from the earlier of the two days, to a day after
        // the entry. A dive spanning more is not one a diver logs.
        firstDate: exitDay.isBefore(entryDay) ? exitDay : entryDay,
        lastDate: entryDay.add(const Duration(days: 1)),
      ),
      FormRow.rating(
        label: l10n.diveLog_edit_section_rating,
        value: rating,
        onChanged: (value) =>
            session.set(diveRatingField, value == 0 ? null : value),
      ),
    ];
  }

  static DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  /// The dive mode (edited on the Tanks card) and the dive types (edited
  /// on Details): the hero shows both, so the open card keeps them.
  List<Widget> _shownElsewhere(
    AppLocalizations l10n,
    Map<String, DiveTypeEntity> typesById,
  ) {
    final working = widget.session.working;
    return [
      FormRow.display(
        label: l10n.diveLog_diveMode_title,
        value: diveModeLabel(l10n, working.diveMode),
      ),
      if (working.diveTypeIds.isNotEmpty)
        FormRow.display(
          label: l10n.diveLog_edit_label_diveTypes,
          value: [
            for (final id in working.diveTypeIds)
              diveTypeShortLabel(l10n, id, typesById: typesById),
          ].join(', '),
        ),
    ];
  }

  /// Depths, times and water temperature, each with what the profile
  /// offers in its place.
  List<Widget> _numbers(AppLocalizations l10n, UnitFormatter units) {
    final session = widget.session;
    // The sitting does not edit the profile: what it offers comes from the
    // dive as stored.
    final stored = session.stored;
    final hasProfile = stored.profile.isNotEmpty;
    final tooltip = l10n.diveLog_edit_tooltip_calculateFromProfile;
    ProfileSuggestion? depth(double? meters, EditField<Dive, double?> field) =>
        !hasProfile || meters == null
        ? null
        : ProfileSuggestion(
            value: formatFixedForInput(units.convertDepth(meters), 1),
            onUse: () => session.set(field, meters),
            tooltip: tooltip,
          );
    ProfileSuggestion? minutes(Duration? span, void Function(Duration) use) =>
        !hasProfile || span == null
        ? null
        : ProfileSuggestion(
            value: formatFixedForInput((span.inSeconds ~/ 60).toDouble(), 0),
            onUse: () => use(span),
            tooltip: tooltip,
          );
    // Whole minutes, cut rather than rounded, as the hero and the dive form
    // show them: 43 min 40 s reads 43 everywhere.
    double toMinutes(double seconds) => (seconds / 60).floorToDouble();
    double toSeconds(double minutes) => minutes * 60;
    return [
      RecordNumberRow<Dive>(
        session: session,
        field: diveMaxDepthField,
        label: l10n.diveLog_edit_label_maxDepth,
        suffixText: units.depthSymbol,
        toDisplay: units.convertDepth,
        fromDisplay: units.depthToMeters,
        fractionDigits: 1,
        allowNegative: false,
        suggestion: depth(
          stored.calculateMaxDepthFromProfile(),
          diveMaxDepthField,
        ),
      ),
      RecordNumberRow<Dive>(
        session: session,
        field: diveAvgDepthField,
        label: l10n.diveLog_edit_label_avgDepth,
        suffixText: units.depthSymbol,
        toDisplay: units.convertDepth,
        fromDisplay: units.depthToMeters,
        fractionDigits: 1,
        allowNegative: false,
        suggestion: depth(
          stored.calculateAvgDepthFromProfile(),
          diveAvgDepthField,
        ),
      ),
      RecordNumberRow<Dive>(
        session: session,
        field: diveRuntimeField,
        label: l10n.diveLog_edit_label_runtime,
        suffixText: 'min',
        placeholder: l10n.diveLog_edit_row_notSet,
        toDisplay: toMinutes,
        fromDisplay: toSeconds,
        integer: true,
        allowNegative: false,
        // A runtime moves a recorded exit (issue #241).
        apply: (seconds) => setRuntime(
          session,
          seconds == null ? null : Duration(seconds: seconds.round()),
        ),
        suggestion: minutes(
          stored.calculateRuntimeFromProfile(),
          (span) => setRuntime(session, span),
        ),
      ),
      RecordNumberRow<Dive>(
        session: session,
        field: diveBottomTimeField,
        label: l10n.diveLog_edit_label_bottomTime,
        suffixText: 'min',
        toDisplay: toMinutes,
        fromDisplay: toSeconds,
        integer: true,
        allowNegative: false,
        suggestion: minutes(
          stored.calculateBottomTimeFromProfile(),
          (span) => session.set(diveBottomTimeField, span.inSeconds.toDouble()),
        ),
      ),
      RecordNumberRow<Dive>(
        session: session,
        field: diveWaterTempField,
        label: l10n.diveLog_edit_label_waterTemp,
        suffixText: units.temperatureSymbol,
        toDisplay: units.convertTemperature,
        fromDisplay: units.temperatureToCelsius,
        fractionDigits: 1,
        trimZeros: true,
      ),
    ];
  }

  /// Favourite, and the planned switch where the dive can take it.
  List<Widget> _flags(AppLocalizations l10n, bool? hasPrimarySource) {
    final session = widget.session;
    return [
      FormRow.toggle(
        label: l10n.diveLog_bulkEdit_fieldFavorite,
        value: session.valueOf(diveFavoriteField),
        onChanged: (value) => session.set(diveFavoriteField, value),
      ),
      if (plannedSwitchOffered(
        session.stored,
        hasPrimarySource: hasPrimarySource,
      ))
        FormRow.toggle(
          key: const Key('dive_edit_planned_switch'),
          label: l10n.diveLog_edit_planned_switch,
          helpText: l10n.diveLog_edit_planned_switchSubtitle,
          value: session.valueOf(divePlannedField),
          onChanged: (planned) =>
              setPlanned(session, planned, nextNumber: _nextNumber),
        )
      else if (session.stored.isPlanned)
        // A plan is logged with "Mark as logged", which numbers it.
        FormRow.display(
          label: l10n.diveLog_edit_planned_switch,
          value: l10n.diveLog_edit_planned_switchSubtitle,
        ),
    ];
  }

  /// The next number in the diver's log. Read before it waits: the editor
  /// may have closed by the time it answers.
  Future<int?> _nextNumber() async {
    final dives = ref.read(diveRepositoryProvider);
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    return dives.getNextDiveNumber(diverId: diverId);
  }
}
