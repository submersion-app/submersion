import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';
import 'package:submersion/features/safety/presentation/formatters/incident_labels.dart';
import 'package:submersion/features/safety/presentation/providers/incident_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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
                _severity = incident.severity;
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
                    onSelected: (_) => setState(() => _category = category),
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
              subtitle: Text(DateFormat.yMMMd().format(_occurredAt)),
              onTap: _pickDate,
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

  Future<void> _pickDate() async {
    // Drive the picker in local calendar days (its native mode), seeding it
    // from _occurredAt's wall-clock Y/M/D, then normalize the chosen day back
    // to a timezone-stable UTC wall-clock date.
    final now = DateTime.now();
    final picked = await showDatePicker(
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
        diverId: ref.read(currentDiverIdProvider),
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
        ),
      );
    }
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
    if (mounted) context.pop();
  }
}
