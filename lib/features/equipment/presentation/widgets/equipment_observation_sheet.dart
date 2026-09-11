import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/constants/observation_tag_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/observation_tag_display.dart';
import 'package:submersion/features/media/presentation/widgets/dive_picker_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The default observed-at for a check-in on [dive]: the exit time when the
/// log has one, else the start plus the runtime, else the start.
DateTime defaultObservedAt(Dive dive) {
  final exit = dive.exitTime;
  if (exit != null) return exit;
  final runtime = dive.effectiveRuntime;
  if (runtime != null) return dive.dateTime.add(runtime);
  return dive.dateTime;
}

/// Opens the check-in sheet for [equipment]. With [dive], the sheet lists
/// and adds observations on that dive; without it (the item page) each new
/// observation may pick a dive or stay a bench note. With [editing], the
/// sheet opens straight into the editor for that observation.
Future<void> showEquipmentObservationSheet(
  BuildContext context, {
  required EquipmentItem equipment,
  Dive? dive,
  EquipmentObservation? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _ObservationSheet(equipment: equipment, dive: dive, editing: editing),
  );
}

/// Asks before deleting [observation], then deletes it. Shared by the
/// sheet's rows and the item page's check-in card.
Future<void> confirmDeleteObservation(
  BuildContext context,
  WidgetRef ref,
  EquipmentObservation observation,
) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(l10n.equipmentObservation_sheet_deleteConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.equipmentObservation_sheet_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.common_action_delete),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await ref.read(equipmentObservationRepositoryProvider).delete(observation.id);
}

class _ObservationSheet extends ConsumerStatefulWidget {
  final EquipmentItem equipment;
  final Dive? dive;
  final EquipmentObservation? editing;

  const _ObservationSheet({required this.equipment, this.dive, this.editing});

  @override
  ConsumerState<_ObservationSheet> createState() => _ObservationSheetState();
}

class _ObservationSheetState extends ConsumerState<_ObservationSheet> {
  /// Null while the list shows; a draft while the editor shows.
  _Draft? _draft;

  /// True from the first Save tap until the write finishes, so a second
  /// tap cannot write the check-in twice.
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.editing case final existing?) {
      _draft = _Draft.fromExisting(existing);
    }
  }

  @override
  void dispose() {
    _draft?.note.dispose();
    super.dispose();
  }

  void _openEditor(_Draft draft) {
    _draft?.note.dispose();
    setState(() => _draft = draft);
  }

  void _closeEditor() {
    _draft?.note.dispose();
    setState(() => _draft = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dive = widget.dive;
    final observationsAsync = dive == null
        ? ref.watch(observationsForEquipmentProvider(widget.equipment.id))
        : ref.watch(observationsForDiveProvider(dive.id));
    final observations = [
      for (final o in observationsAsync.value ?? const <EquipmentObservation>[])
        if (o.equipmentId == widget.equipment.id) o,
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.equipmentObservation_sheet_title(widget.equipment.name),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          // The editor scrolls: an issue shows its tag chips and, off a
          // dive, the dive and date pickers too, which outgrows a short
          // window.
          if (_draft case final draft?)
            Flexible(
              child: SingleChildScrollView(
                child: _Editor(
                  draft: draft,
                  equipment: widget.equipment,
                  hasDive: dive != null,
                  onCancel: _closeEditor,
                  onSave: _saving ? null : () => _save(draft),
                ),
              ),
            )
          else ...[
            if (observations.isEmpty)
              Text(
                dive == null
                    ? l10n.equipmentObservation_sheet_emptyBench
                    : l10n.equipmentObservation_sheet_empty,
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final o in observations)
                      _ObservationTile(
                        observation: o,
                        onEdit: () => _openEditor(_Draft.fromExisting(o)),
                        onDelete: () => _delete(o),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _openEditor(
                _Draft.fresh(
                  observedAt: dive == null
                      ? DateTime.now().toUtc()
                      : defaultObservedAt(dive),
                  diveId: dive?.id,
                ),
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.equipmentObservation_sheet_add),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save(_Draft draft) async {
    if (_saving) return;
    final l10n = context.l10n;
    // A newer peer's tags cannot be shown, but they are still the row's
    // tags: only an issue with none at all is refused.
    if (draft.status == ObservationStatus.issue &&
        draft.tags.isEmpty &&
        (draft.existing?.unrecognizedTags.isEmpty ?? true)) {
      setState(() => draft.error = l10n.equipmentObservation_sheet_tagRequired);
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(equipmentObservationRepositoryProvider);
      final tags = draft.status == ObservationStatus.issue
          ? draft.tags.toList()
          : const <ObservationTag>[];
      final note = draft.note.text.trim();
      final existing = draft.existing;
      if (existing == null) {
        await repo.create(
          equipmentId: widget.equipment.id,
          diveId: draft.diveId,
          // The validated id, as every diver-scoped read uses: a stale raw
          // id would file the check-in under a diver nobody reads.
          diverId: await ref.read(validatedCurrentDiverIdProvider.future),
          observedAt: draft.observedAt,
          status: draft.status,
          issueTags: tags,
          note: note,
        );
      } else {
        await repo.update(
          existing.copyWith(
            diveId: draft.diveId,
            clearDiveId: draft.diveId == null,
            observedAt: draft.observedAt,
            status: draft.status,
            issueTags: tags,
            note: note,
          ),
        );
      }
      if (!mounted) return;
      _closeEditor();
    } catch (_) {
      // A concurrent sync can delete the item or dive mid-save. Say the
      // check-in was not saved and keep the editor open to try again.
      if (mounted) setState(() => draft.error = l10n.common_error_tryAgain);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(EquipmentObservation observation) =>
      confirmDeleteObservation(context, ref, observation);
}

/// The editor's working copy. Mutable on purpose: it lives only while the
/// editor is open and is discarded on Save or Cancel.
class _Draft {
  final EquipmentObservation? existing;
  ObservationStatus status;
  final Set<ObservationTag> tags;
  final TextEditingController note;
  DateTime observedAt;
  String? diveId;
  String? error;

  _Draft({
    this.existing,
    required this.status,
    required this.tags,
    required this.note,
    required this.observedAt,
    this.diveId,
  });

  factory _Draft.fresh({required DateTime observedAt, String? diveId}) =>
      _Draft(
        status: ObservationStatus.ok,
        tags: {},
        note: TextEditingController(),
        observedAt: observedAt,
        diveId: diveId,
      );

  factory _Draft.fromExisting(EquipmentObservation o) => _Draft(
    existing: o,
    status: o.status,
    tags: o.issueTags.toSet(),
    note: TextEditingController(text: o.note),
    observedAt: o.observedAt,
    diveId: o.diveId,
  );
}

class _Editor extends ConsumerStatefulWidget {
  final _Draft draft;
  final EquipmentItem equipment;
  final bool hasDive;
  final VoidCallback onCancel;

  /// Null while a save is in flight, which disables the button.
  final VoidCallback? onSave;

  const _Editor({
    required this.draft,
    required this.equipment,
    required this.hasDive,
    required this.onCancel,
    required this.onSave,
  });

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  Future<void> _pickDive() async {
    final picked = await showDivePickerSheet(context);
    if (picked == null || !mounted) return;
    final dive = await ref.read(diveProvider(picked).future);
    if (!mounted) return;
    setState(() {
      widget.draft.diveId = picked;
      if (dive != null) widget.draft.observedAt = defaultObservedAt(dive);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final draft = widget.draft;
    final units = UnitFormatter(ref.watch(settingsProvider));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<ObservationStatus>(
          segments: [
            for (final s in ObservationStatus.values)
              ButtonSegment(value: s, label: Text(s.localizedName(l10n))),
          ],
          selected: {draft.status},
          onSelectionChanged: (sel) => setState(() {
            draft.status = sel.first;
            draft.error = null;
          }),
        ),
        if (draft.status == ObservationStatus.issue) ...[
          const SizedBox(height: 12),
          Text(
            l10n.equipmentObservation_sheet_tagsLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final tag in observationTagsFor(widget.equipment.type))
                FilterChip(
                  label: Text(tag.localizedName(l10n)),
                  selected: draft.tags.contains(tag),
                  onSelected: (on) => setState(() {
                    if (on) {
                      draft.tags.add(tag);
                    } else {
                      draft.tags.remove(tag);
                    }
                    draft.error = null;
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: draft.note,
          decoration: InputDecoration(
            labelText: l10n.equipmentObservation_sheet_noteLabel,
          ),
          maxLines: 3,
        ),
        if (!widget.hasDive)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.scuba_diving),
            title: Text(l10n.equipmentObservation_sheet_diveLabel),
            subtitle: draft.diveId == null
                ? Text(l10n.equipmentObservation_sheet_noDive)
                : _DiveLabel(diveId: draft.diveId!),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The picker's dismissal keeps the current dive, so going
                // back to a bench note needs its own control.
                if (draft.diveId != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.equipmentObservation_sheet_noDive,
                    onPressed: () => setState(() => draft.diveId = null),
                  ),
                TextButton(
                  onPressed: _pickDive,
                  child: Text(l10n.equipmentObservation_sheet_pickDive),
                ),
              ],
            ),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: Text(l10n.equipmentObservation_sheet_dateLabel),
          subtitle: Text(units.formatDateTime(draft.observedAt, l10n: l10n)),
        ),
        if (draft.error case final error?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.onCancel,
              child: Text(l10n.equipmentObservation_sheet_cancel),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: widget.onSave,
              child: Text(l10n.equipmentObservation_sheet_save),
            ),
          ],
        ),
      ],
    );
  }
}

/// "Dive #n" for a picked dive, or the plain "Dive" label while it loads
/// (the id is internal and never shown).
class _DiveLabel extends ConsumerWidget {
  final String diveId;

  const _DiveLabel({required this.diveId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dive = ref.watch(diveProvider(diveId)).value;
    final number = dive?.diveNumber;
    // Until the dive resolves, a plain label: the id is internal.
    return Text(
      number == null
          ? context.l10n.equipmentObservation_sheet_diveLabel
          : context.l10n.equipmentObservation_card_onDive(number),
    );
  }
}

class _ObservationTile extends ConsumerWidget {
  final EquipmentObservation observation;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ObservationTile({
    required this.observation,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final scheme = Theme.of(context).colorScheme;
    final title = observation.displayTitle(l10n);
    final note = observation.noteSummary;
    final when = units.formatDateTime(observation.observedAt, l10n: l10n);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        observation.isIssue ? Icons.warning_amber : Icons.check_circle_outline,
        color: observation.isIssue ? scheme.error : scheme.tertiary,
      ),
      title: Text(title),
      subtitle: note.isEmpty
          ? Text(when)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(note, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(when),
              ],
            ),
      isThreeLine: note.isNotEmpty,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.equipmentObservation_sheet_edit,
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.equipmentObservation_sheet_delete,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
