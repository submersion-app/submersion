import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_observation_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_status_indicator.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/features/safety/presentation/formatters/incident_labels.dart';
import 'package:submersion/features/safety/presentation/pages/incident_draft.dart';
import 'package:submersion/features/safety/presentation/providers/incident_providers.dart';
import 'package:submersion/features/safety/presentation/widgets/incident_check_in_picker.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';
import 'package:submersion/shared/widgets/record_editing/record_editor_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

/// Create/edit form for a near-miss report. Non-punitive framing: what
/// happened, what contributed, what would help next time.
///
/// Edited on the shared Cancel and Save bar (issue #4527, phase 4): Save is
/// one transaction and one History entry, Delete is in the bar's menu, and
/// leaving with unsaved changes asks first.
class IncidentEditPage extends ConsumerStatefulWidget {
  /// Null for a new incident.
  final String? incidentId;

  /// Optional dive to link a NEW incident to (from the dive detail overflow).
  final String? diveId;

  /// Optional check-in a NEW incident starts from (from a check-in row): the
  /// form opens filled in from it, linked to it.
  final String? observationId;

  const IncidentEditPage({
    this.incidentId,
    this.diveId,
    this.observationId,
    super.key,
  });

  @override
  ConsumerState<IncidentEditPage> createState() => _IncidentEditPageState();
}

class _IncidentEditPageState extends ConsumerState<IncidentEditPage>
    with RecordEditorHost<IncidentEditPage, IncidentDraft> {
  static final _log = LoggerService.forClass(IncidentEditPage);

  final _formKey = GlobalKey<FormState>();
  final _narrative = TextEditingController();
  final _factors = TextEditingController();
  final _lessons = TextEditingController();

  Incident? _existing;
  var _category = IncidentCategory.other;
  var _severity = IncidentSeverity.minor;

  /// The item involved, when the diver names one. Choosing an item while the
  /// category is still the untouched default flips it to `equipment`; a
  /// category picked by hand, or one loaded from a saved incident, is never
  /// overridden, hence the flag.
  String? _equipmentId;
  var _categoryTouched = false;

  /// The check-in behind the report, on [_equipmentId]. Null until the diver
  /// names one, or one matches.
  String? _observationId;

  /// The report's own dive. The form shows no dive field, so a dive that only
  /// came from a chosen check-in stays apart in [_checkInDiveId]: it must go
  /// when that check-in does, with no way for the diver to see it otherwise.
  String? _diveId;
  String? _checkInDiveId;

  /// The dive the report saves with: its own, else the chosen check-in's.
  String? get _effectiveDiveId => _diveId ?? _checkInDiveId;
  // A timezone-stable wall-clock date (stored as UTC), so the chosen day does
  // not shift when the synced incident is viewed in another timezone.
  DateTime _occurredAt = _todayWallClockUtc();

  /// The date a new report returns to when a chosen check-in goes: today, or
  /// the day of the check-in the report started from.
  DateTime _defaultDate = _todayWallClockUtc();

  /// Whether the diver has picked a date. A check-in moves only the default.
  var _dateTouched = false;

  /// The blank form a new report opens its sitting on: what a dive or a
  /// check-in filled in is a change (a seed). Dated as the form is, before
  /// anything is awaited.
  late final IncidentDraft _blank;

  /// The items a committed Save touched, for the findings refresh after it.
  Set<String> _touched = const {};
  var _loaded = false;
  var _loadFailed = false;

  /// Today's wall-clock date as a UTC value (no time-of-day), matching how the
  /// date picker and storage treat [_occurredAt].
  static DateTime _todayWallClockUtc() {
    final now = DateTime.now();
    return DateTime.utc(now.year, now.month, now.day);
  }

  /// The day [checkIn] was made, in [_occurredAt]'s form. Never past today,
  /// which the date picker refuses and a dive's own clock can read.
  static DateTime _dayOf(EquipmentObservation checkIn) {
    final at = checkIn.observedAt;
    final day = DateTime.utc(at.year, at.month, at.day);
    final today = _todayWallClockUtc();
    return day.isAfter(today) ? today : day;
  }

  @override
  void initState() {
    super.initState();
    _blank = blankIncidentDraft(_occurredAt);
    for (final text in [_narrative, _factors, _lessons]) {
      text.addListener(editorChanged);
    }
    _diveId = widget.diveId;
    if (widget.incidentId == null) {
      if (widget.observationId case final id?) {
        _startFromCheckIn(id);
      } else {
        _loaded = true;
        // A dive the report was opened from is a seed.
        openEditor(from: _blank);
      }
    } else {
      ref
          .read(incidentRepositoryProvider)
          .getIncidentById(widget.incidentId!)
          .then((incident) {
            if (!mounted) return;
            setState(() {
              _existing = incident;
              if (incident != null) {
                _category = incident.category;
                // The saved category was chosen when it was saved.
                _categoryTouched = true;
                _severity = incident.severity;
                _equipmentId = incident.equipmentId;
                _observationId = incident.observationId;
                _diveId = incident.diveId;
                _occurredAt = incident.occurredAt;
                _narrative.text = incident.narrative;
                _factors.text = incident.contributingFactors ?? '';
                _lessons.text = incident.lessonsLearned ?? '';
              }
              _loaded = true;
            });
            // A report that will not load keeps its error page, with no
            // sitting.
            if (incident != null) openEditor();
          })
          .catchError((Object _) {
            if (!mounted) return;
            setState(() {
              _loadFailed = true;
              _loaded = true;
            });
          });
    }
  }

  /// Fills the new form from check-in [id]. One deleted since the row was
  /// drawn, or unreadable, leaves a plain new form.
  Future<void> _startFromCheckIn(String id) async {
    EquipmentObservation? checkIn;
    String? diveId;
    try {
      checkIn = await ref
          .read(equipmentObservationRepositoryProvider)
          .getById(id);
      if (checkIn != null) diveId = await _fillableDiveOf(checkIn);
    } catch (_) {
      checkIn = null;
    }
    if (!mounted) return;
    setState(() {
      if (checkIn case final found?) {
        _equipmentId = found.equipmentId;
        _category = IncidentCategory.equipment;
        _narrative.text = found.note;
        // The report starts on this dive and day, whatever becomes of the link.
        _diveId ??= diveId;
        _defaultDate = _dayOf(found);
        _adoptCheckIn(found, diveId);
      }
      _loaded = true;
    });
    // What the check-in filled in is a seed; a check-in that has gone
    // leaves a plain new form, unchanged.
    openEditor(from: _blank);
  }

  /// [checkIn]'s dive, for this report to fill in. On shared gear the check-in
  /// can be another profile's, and a report on their dive would show there, so
  /// it stays off. Owners compare as in [nearMissesByCheckInProvider].
  Future<String?> _fillableDiveOf(EquipmentObservation checkIn) async {
    final owner = checkIn.diverId;
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    return diverId != null && owner != null && owner != diverId
        ? null
        : checkIn.diveId;
  }

  /// Links [checkIn], with [diveId] from [_fillableDiveOf]. Fills what the
  /// report lacks and overwrites nothing the diver or a saved report has set.
  void _adoptCheckIn(EquipmentObservation checkIn, String? diveId) {
    _observationId = checkIn.id;
    _checkInDiveId = diveId;
    if (_existing == null && !_dateTouched) _occurredAt = _dayOf(checkIn);
  }

  void _clearCheckIn() {
    _observationId = null;
    _checkInDiveId = null;
    if (_existing == null && !_dateTouched) _occurredAt = _defaultDate;
  }

  @override
  void dispose() {
    disposeEditor();
    _narrative.dispose();
    _factors.dispose();
    _lessons.dispose();
    super.dispose();
  }

  /// Applies a change to the form and hands the form to the sitting.
  void _change(VoidCallback change) {
    setState(change);
    editorChanged();
  }

  @override
  String get editorTable => 'incidents';

  @override
  String? get editorStoredId => widget.incidentId;

  @override
  String? get editorLeaveLocation => '/incidents';

  @override
  String editorTitle(BuildContext context) => widget.incidentId == null
      ? context.l10n.incidentEdit_title_new
      : context.l10n.incidentEdit_title_edit;

  @override
  IncidentDraft readEditorDraft() => (
    category: _category,
    severity: _severity,
    occurredAt: _occurredAt,
    equipmentId: _equipmentId,
    observationId: _observationId,
    diveId: _diveId,
    checkInDiveId: _checkInDiveId,
    narrative: _narrative.text,
    factors: _factors.text,
    lessons: _lessons.text,
  );

  @override
  bool validateEditor() => _formKey.currentState?.validate() ?? false;

  @override
  Future<void> writeEditor(String recordId) async {
    // Everything from the page before anything slow: the diver can leave
    // while this runs, and the report still has to land.
    final repo = ref.read(incidentRepositoryProvider);
    final checkIns = ref.read(equipmentObservationRepositoryProvider);
    final draft = readEditorDraft();
    final start = editorStartDraft;
    final diverId = editorDiverId;
    final linkable = await _linkableObservationId(
      checkIns,
      draft.observationId,
    );
    if (editorCreating) {
      // The validated diver, as the gear picker and the incident list read
      // it. None (no diver set up) files a report every diver's log lists.
      await repo.createIncident(
        id: recordId,
        occurredAt: draft.occurredAt,
        category: draft.category,
        severity: draft.severity,
        narrative: draft.narrative.trim(),
        contributingFactors: incidentOptionalText(draft.factors),
        lessonsLearned: incidentOptionalText(draft.lessons),
        diveId: incidentSavedDiveId(draft, linkable),
        diverId: diverId,
        equipmentId: draft.equipmentId,
        observationId: linkable,
      );
      _touched = {?draft.equipmentId};
      return;
    }
    final stored = await repo.getIncidentById(recordId);
    final changes = incidentChanges(
      draft: draft,
      start: start!,
      linkable: linkable,
    );
    if (stored == null || !await repo.applyIncidentChanges(recordId, changes)) {
      throw RecordSittingRefusal((l10n) => l10n.incidents_notFound);
    }
    // The incident rule reads each item's incidents, and a moved incident
    // leaves the item it was on as well.
    final written = changes.equipmentId == null
        ? stored.equipmentId
        : changes.equipmentId!.value;
    _touched = {?written, ?stored.equipmentId};
  }

  @override
  bool editorSaveFailed(Object error) {
    // The host says so in a snackbar; the log keeps why. A refusal (the
    // report was deleted elsewhere) is no fault, and the diver is told.
    if (error is! RecordSittingRefusal) {
      _log.error('Could not save a near-miss', error: error);
    }
    return false;
  }

  @override
  void afterEditorSaved(ScaffoldMessengerState messenger) {
    if (_touched.isNotEmpty) scheduleConditionFindingsRefresh(_touched);
  }

  @override
  List<RecordEditorOperation> editorOperations(BuildContext context) => [
    RecordEditorOperation(
      key: const ValueKey('incident_delete'),
      icon: Icons.delete_outline,
      label: context.l10n.common_action_delete,
      destructive: true,
      run: _delete,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final Widget body;
    if (!_loaded) {
      body = const Center(child: CircularProgressIndicator());
    } else if (widget.incidentId != null && _existing == null) {
      // Edit route whose record could not be loaded (read error or a
      // missing/deleted incident). Never fall through to the create form:
      // its title would read "Edit" while Save silently created a NEW
      // record.
      body = Center(
        child: Text(
          _loadFailed ? l10n.common_error_tryAgain : l10n.incidents_notFound,
        ),
      );
    } else {
      body = _form(context, units);
    }
    return editorScaffold(context, body: body);
  }

  Widget _form(BuildContext context, UnitFormatter units) {
    final l10n = context.l10n;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.incidentEdit_category,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in IncidentCategory.values)
                ChoiceChip(
                  label: Text(incidentCategoryLabel(l10n, category)),
                  selected: _category == category,
                  onSelected: (_) => _change(() {
                    _category = category;
                    _categoryTouched = true;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l10n.incidentEdit_severity,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<IncidentSeverity>(
            segments: [
              for (final severity in IncidentSeverity.values)
                ButtonSegment(
                  value: severity,
                  label: Text(incidentSeverityLabel(l10n, severity)),
                ),
            ],
            selected: {_severity},
            onSelectionChanged: (selection) =>
                _change(() => _severity = selection.first),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(l10n.incidentEdit_date),
            // Format the wall-clock UTC components directly (no toLocal), so
            // the shown day is identical on every synced device.
            subtitle: Text(units.formatDate(_occurredAt)),
            onTap: _pickDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.backpack_outlined),
            title: Text(l10n.incidentEdit_equipment),
            subtitle: _EquipmentName(
              equipmentId: _equipmentId,
              none: l10n.incidentEdit_equipment_none,
            ),
            onTap: _pickEquipment,
          ),
          if (_equipmentId != null)
            IncidentCheckInRow(
              observationId: _observationId,
              onTap: _pickCheckIn,
            ),
          TextFormField(
            controller: _narrative,
            decoration: InputDecoration(
              labelText: l10n.incidentEdit_narrative,
              hintText: l10n.incidentEdit_narrative_hint,
            ),
            maxLines: 5,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? l10n.incidentEdit_narrative_required
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _factors,
            decoration: InputDecoration(
              labelText: l10n.incidentEdit_contributingFactors,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _lessons,
            decoration: InputDecoration(
              labelText: l10n.incidentEdit_lessonsLearned,
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.incidentEdit_privacyNote,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// The dive's own gear first (when the incident has a dive), then the
  /// rest of the active items, so the item that was in the water is one tap
  /// away and each item is listed once.
  Future<void> _pickEquipment() async {
    final l10n = context.l10n;
    final diveId = _effectiveDiveId;
    final dive = diveId == null
        ? null
        : await ref.read(diveProvider(diveId).future);
    final onDive = await _gearOnDive(dive);
    final active = await ref.read(activeEquipmentProvider.future);
    if (!mounted) return;
    final onDiveIds = {for (final item in onDive) item.id};
    final rest = [
      for (final item in active)
        if (!onDiveIds.contains(item.id)) item,
    ];
    final chosen = await showDialog<_EquipmentChoice>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.incidentEdit_equipment),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.of(dialogContext).pop(const _EquipmentChoice(null)),
            child: Text(l10n.incidentEdit_equipment_none),
          ),
          if (onDive.isNotEmpty) ...[
            IncidentPickerHeader(l10n.incidentEdit_equipment_onThisDive),
            for (final item in onDive)
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(_EquipmentChoice(item.id)),
                child: _GearOption(item: item),
              ),
          ],
          if (rest.isNotEmpty) ...[
            IncidentPickerHeader(l10n.incidentEdit_equipment_allGear),
            for (final item in rest)
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(_EquipmentChoice(item.id)),
                child: _GearOption(item: item),
              ),
          ],
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    final changed = chosen.equipmentId != _equipmentId;
    _change(() {
      _equipmentId = chosen.equipmentId;
      // A check-in belongs to one item, so it cannot follow the report.
      if (changed) _clearCheckIn();
      if (chosen.equipmentId != null && !_categoryTouched) {
        _category = IncidentCategory.equipment;
      }
    });
    if (changed) await _matchCheckIn();
  }

  /// Selects the item's check-in on this dive when it can only be that one:
  /// exactly one issue. Two means two faults, and picking is the diver's call.
  Future<void> _matchCheckIn() async {
    final equipmentId = _equipmentId;
    final diveId = _effectiveDiveId;
    if (equipmentId == null || diveId == null) return;
    final onDive = await ref
        .read(equipmentObservationRepositoryProvider)
        .getForEquipmentOnDive(equipmentId, diveId);
    final issues = onDive.where((o) => o.isIssue).toList();
    if (issues.length != 1 || !mounted) return;
    // The diver may have moved on while the query ran.
    if (_equipmentId != equipmentId || _observationId != null) return;
    _change(() => _adoptCheckIn(issues.single, diveId));
  }

  Future<List<EquipmentObservation>> _issuesOn(String equipmentId) async {
    final all = await ref
        .read(equipmentObservationRepositoryProvider)
        .getForEquipment(equipmentId);
    return all.where((o) => o.isIssue).toList();
  }

  Future<void> _pickCheckIn() async {
    final equipmentId = _equipmentId;
    if (equipmentId == null) return;
    final issues = await _issuesOn(equipmentId);
    if (!mounted) return;
    final chosen = await showIncidentCheckInPicker(
      context,
      checkIns: issues,
      diveId: _effectiveDiveId,
    );
    if (!mounted) return;
    switch (chosen) {
      case null:
        return;
      case IncidentCheckInNone():
        _change(_clearCheckIn);
      case IncidentCheckInPicked(:final observation):
        final diveId = await _fillableDiveOf(observation);
        if (mounted) _change(() => _adoptCheckIn(observation, diveId));
      case IncidentCheckInAddNew():
        await _addCheckIn(equipmentId, known: issues);
    }
  }

  /// Opens the check-in sheet for the item and, when the diver leaves it
  /// having added one issue, selects that issue.
  Future<void> _addCheckIn(
    String equipmentId, {
    required List<EquipmentObservation> known,
  }) async {
    final item = await ref.read(equipmentItemProvider(equipmentId).future);
    if (item == null || !mounted) return;
    final diveId = _effectiveDiveId;
    final dive = diveId == null
        ? null
        : await ref.read(diveProvider(diveId).future);
    if (!mounted) return;
    await showEquipmentObservationSheet(
      context,
      equipment: item,
      dive: dive,
      offerNearMiss: false,
    );
    if (!mounted) return;
    final knownIds = {for (final o in known) o.id};
    final added = [
      for (final o in await _issuesOn(equipmentId))
        if (!knownIds.contains(o.id)) o,
    ];
    if (added.length != 1 || !mounted) return;
    final addedDiveId = await _fillableDiveOf(added.single);
    if (mounted) _change(() => _adoptCheckIn(added.single, addedDiveId));
  }

  /// The dive's gear junction, then the items its cylinders are linked to:
  /// the transmitter registry writes that link on the tank, not in the
  /// junction, and the item may be retired and so absent from the active
  /// list. Each item once, in that order.
  Future<List<EquipmentItem>> _gearOnDive(Dive? dive) async {
    if (dive == null) return const [];
    final items = [...dive.equipment];
    final seen = {for (final item in items) item.id};
    for (final tank in dive.tanks) {
      final id = tank.equipmentId;
      if (id == null || !seen.add(id)) continue;
      final item = await ref.read(equipmentItemProvider(id).future);
      if (item != null) items.add(item);
    }
    return items;
  }

  /// The chosen check-in, if it can still be linked. It may have changed since
  /// it was chosen: the sheet this form opens can delete it or save it as OK,
  /// and a sync can delete it, so saving the old id would fail on the foreign
  /// key or link an OK check.
  Future<String?> _linkableObservationId(
    EquipmentObservationRepository checkIns,
    String? id,
  ) async {
    if (id == null) return null;
    final checkIn = await checkIns.getById(id);
    return checkIn != null && checkIn.isIssue ? id : null;
  }

  Future<void> _pickDate() async {
    // Drive the picker in local calendar days (its native mode), seeding it
    // from _occurredAt's wall-clock Y/M/D, then normalize the chosen day back
    // to a timezone-stable UTC wall-clock date.
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: DateTime(
        _occurredAt.year,
        _occurredAt.month,
        _occurredAt.day,
      ),
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked != null && mounted) {
      _change(() {
        _occurredAt = DateTime.utc(picked.year, picked.month, picked.day);
        _dateTouched = true;
      });
    }
  }

  /// The bar menu's Delete: asks, then removes the report in its own
  /// History entry and refreshes its item's findings. Answers whether it
  /// deleted, so the page leaves.
  Future<bool> _delete() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.incidents_delete_confirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;
    final repo = ref.read(incidentRepositoryProvider);
    final id = editorRecordId;
    final stored = await repo.getIncidentById(id);
    await repo.deleteIncident(id);
    if ((stored ?? _existing)?.equipmentId case final item?) {
      scheduleConditionFindingsRefresh([item]);
    }
    return true;
  }
}

/// A dialog result that can carry "none" (null id) as a real choice, which
/// a bare nullable String could not tell apart from a dismissed dialog.
class _EquipmentChoice {
  final String? equipmentId;
  const _EquipmentChoice(this.equipmentId);
}

/// One row of the gear picker: the item's name with its service status, so
/// a diver linking an incident sees whether that gear is also overdue.
class _GearOption extends StatelessWidget {
  final EquipmentItem item;
  const _GearOption({required this.item});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Flexible(child: Text(item.name)),
      const SizedBox(width: 8),
      ServiceStatusIndicatorFor(
        equipmentId: item.id,
        density: ServiceIndicatorDensity.dot,
      ),
    ],
  );
}

/// The chosen item's name, or [none]; resolves the name through the item
/// provider so the form never blocks on it.
class _EquipmentName extends ConsumerWidget {
  final String? equipmentId;
  final String none;
  const _EquipmentName({required this.equipmentId, required this.none});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = equipmentId;
    if (id == null) return Text(none);
    final item = ref.watch(equipmentItemProvider(id)).value;
    return Text(item?.name ?? id);
  }
}
