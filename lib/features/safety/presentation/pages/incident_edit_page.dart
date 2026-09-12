import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/features/safety/presentation/formatters/incident_labels.dart';
import 'package:submersion/features/safety/presentation/providers/incident_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

/// Create/edit form for a near-miss report. Non-punitive framing: what
/// happened, what contributed, what would help next time.
class IncidentEditPage extends ConsumerStatefulWidget {
  /// Null for a new incident.
  final String? incidentId;

  /// Optional dive to link a NEW incident to (from the dive detail overflow).
  final String? diveId;

  const IncidentEditPage({this.incidentId, this.diveId, super.key});

  @override
  ConsumerState<IncidentEditPage> createState() => _IncidentEditPageState();
}

class _IncidentEditPageState extends ConsumerState<IncidentEditPage> {
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
  // A timezone-stable wall-clock date (stored as UTC), so the chosen day does
  // not shift when the synced incident is viewed in another timezone.
  DateTime _occurredAt = _todayWallClockUtc();
  var _loaded = false;
  var _loadFailed = false;

  /// Today's wall-clock date as a UTC value (no time-of-day), matching how the
  /// date picker and storage treat [_occurredAt].
  static DateTime _todayWallClockUtc() {
    final now = DateTime.now();
    return DateTime.utc(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    if (widget.incidentId == null) {
      _loaded = true;
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
                _occurredAt = incident.occurredAt;
                _narrative.text = incident.narrative;
                _factors.text = incident.contributingFactors ?? '';
                _lessons.text = incident.lessonsLearned ?? '';
              }
              _loaded = true;
            });
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

  @override
  void dispose() {
    _narrative.dispose();
    _factors.dispose();
    _lessons.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Edit route whose record could not be loaded (read error or a
    // missing/deleted incident). Never fall through to the create form: its
    // title would read "Edit" while Save silently created a NEW record.
    if (widget.incidentId != null && _existing == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.incidentEdit_title_edit)),
        body: Center(
          child: Text(
            _loadFailed ? l10n.common_error_tryAgain : l10n.incidents_notFound,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.incidentId == null
              ? l10n.incidentEdit_title_new
              : l10n.incidentEdit_title_edit,
        ),
        actions: [
          if (_existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
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
                    onSelected: (_) => setState(() {
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
                  setState(() => _severity = selection.first),
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
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: Text(l10n.incidentEdit_save)),
          ],
        ),
      ),
    );
  }

  /// The dive's own gear first (when the incident has a dive), then the
  /// rest of the active items, so the item that was in the water is one tap
  /// away and each item is listed once.
  Future<void> _pickEquipment() async {
    final l10n = context.l10n;
    final diveId = widget.diveId ?? _existing?.diveId;
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
            _PickerHeader(l10n.incidentEdit_equipment_onThisDive),
            for (final item in onDive)
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(_EquipmentChoice(item.id)),
                child: Text(item.name),
              ),
          ],
          if (rest.isNotEmpty) ...[
            _PickerHeader(l10n.incidentEdit_equipment_allGear),
            for (final item in rest)
              SimpleDialogOption(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(_EquipmentChoice(item.id)),
                child: Text(item.name),
              ),
          ],
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _equipmentId = chosen.equipmentId;
      if (chosen.equipmentId != null && !_categoryTouched) {
        _category = IncidentCategory.equipment;
      }
    });
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
      setState(
        () => _occurredAt = DateTime.utc(picked.year, picked.month, picked.day),
      );
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = ref.read(incidentRepositoryProvider);
    final narrative = _narrative.text.trim();
    final factors = _factors.text.trim();
    final lessons = _lessons.text.trim();

    if (_existing == null) {
      await repo.createIncident(
        occurredAt: _occurredAt,
        category: _category,
        severity: _severity,
        narrative: narrative,
        contributingFactors: factors.isEmpty ? null : factors,
        lessonsLearned: lessons.isEmpty ? null : lessons,
        diveId: widget.diveId,
        // The validated id, as the gear picker and the incident list read
        // it: a stale raw id would file the report where neither looks.
        diverId: await ref.read(validatedCurrentDiverIdProvider.future),
        equipmentId: _equipmentId,
      );
    } else {
      await repo.updateIncident(
        _existing!.copyWith(
          occurredAt: _occurredAt,
          category: _category,
          severity: _severity,
          narrative: narrative,
          contributingFactors: factors.isEmpty ? null : factors,
          lessonsLearned: lessons.isEmpty ? null : lessons,
          equipmentId: _equipmentId,
          clearEquipmentId: _equipmentId == null,
        ),
      );
    }
    // The incident rule reads this item's incidents, and a moved incident
    // leaves the item it was on as well.
    final touched = {?_equipmentId, ?_existing?.equipmentId};
    if (touched.isNotEmpty) scheduleConditionFindingsRefresh(touched);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
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
    if (confirmed != true || !mounted) return;
    await ref.read(incidentRepositoryProvider).deleteIncident(_existing!.id);
    if (_existing!.equipmentId case final item?) {
      scheduleConditionFindingsRefresh([item]);
    }
    if (mounted) context.pop();
  }
}

/// A dialog result that can carry "none" (null id) as a real choice, which
/// a bare nullable String could not tell apart from a dismissed dialog.
class _EquipmentChoice {
  final String? equipmentId;
  const _EquipmentChoice(this.equipmentId);
}

class _PickerHeader extends StatelessWidget {
  final String text;
  const _PickerHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
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
