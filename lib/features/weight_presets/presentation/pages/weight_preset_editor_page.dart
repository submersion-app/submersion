import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/weight_label_field.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/weight_enum_display.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';
import 'package:submersion/features/weight_presets/presentation/providers/weight_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';
import 'package:submersion/shared/widgets/record_editing/record_editor_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

/// Create or edit a weighting rig from Settings → Management → Weight Presets
/// (issue #1663). Editing a preset never touches dives that already used it --
/// applying a preset copies its rows into the dive.
class WeightPresetEditorPage extends ConsumerStatefulWidget {
  final String? presetId;

  const WeightPresetEditorPage({super.key, this.presetId});

  bool get isEditing => presetId != null;

  @override
  ConsumerState<WeightPresetEditorPage> createState() =>
      _WeightPresetEditorPageState();
}

/// One weight row as the editor shows it.
typedef WeightRowDraft = ({WeightType type, String amount, String label});

/// What the weight preset editor's form shows, as the diver sees it: the
/// sitting's draft (issue #4527, phase 4). Text as shown, so a weight in
/// pounds that would not convert back exactly never reads as a change.
@immutable
class WeightPresetDraft {
  const WeightPresetDraft({required this.name, required this.rows});

  final String name;
  final List<WeightRowDraft> rows;

  @override
  bool operator ==(Object other) =>
      other is WeightPresetDraft &&
      other.name == name &&
      listEquals(other.rows, rows);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(rows));
}

class _Row {
  WeightType type;
  final TextEditingController amount;

  /// The entry's optional name (issue #956).
  final TextEditingController label;

  /// The stored entry the row was loaded from, and the amount text it was
  /// shown as; null for a row the diver added. A field the diver left alone
  /// is written as that entry is stored at Save, never as it was loaded
  /// (a sync may have changed it since) and never from its display text
  /// (rounded to three decimals of a pound).
  final WeightPresetEntry? loaded;
  final String? loadedText;

  _Row(this.type, this.amount, this.label, {this.loaded, this.loadedText});

  /// The row as it would be stored, its untouched fields taken from
  /// [stored], the entry as stored now (the loaded entry when it is gone).
  /// [convertedKg] is the amount shown, in kilograms.
  WeightEntryDraft draft({
    required double convertedKg,
    WeightPresetEntry? stored,
  }) {
    final origin = loaded;
    final base = stored ?? origin;
    final amountUntouched = origin != null && amount.text == loadedText;
    return (
      weightType: origin != null && type == origin.weightType && base != null
          ? base.weightType
          : type,
      amountKg: amountUntouched && base != null ? base.amountKg : convertedKg,
      notes: '',
      label: origin != null && label.text == origin.label && base != null
          ? base.label
          : label.text,
    );
  }

  void dispose() {
    amount.dispose();
    label.dispose();
  }
}

class _WeightPresetEditorPageState extends ConsumerState<WeightPresetEditorPage>
    with RecordEditorHost<WeightPresetEditorPage, WeightPresetDraft> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rows = <_Row>[];

  bool _loading = false;

  /// A row whose fields tell the sitting of each change.
  _Row _newRow(
    WeightType type, {
    String amount = '',
    String label = '',
    WeightPresetEntry? loaded,
  }) => _Row(
    type,
    TextEditingController(text: amount)..addListener(editorChanged),
    TextEditingController(text: label)..addListener(editorChanged),
    loaded: loaded,
    loadedText: loaded == null ? null : amount,
  );

  @override
  void initState() {
    super.initState();
    _nameController.addListener(editorChanged);
    if (widget.isEditing) {
      _load();
    } else {
      // A new preset starts with one blank belt row: a default, not a
      // change, so the sitting opens on it.
      _rows.add(_newRow(WeightType.belt));
      openEditor();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final WeightPreset? read;
    try {
      read = await ref
          .read(weightPresetRepositoryProvider)
          .getPresetById(widget.presetId!);
    } catch (e) {
      // A read that fails leaves nothing to edit: say so and go back to the
      // list, rather than spin with no way to save.
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.l10n.common_label_error}: $e')),
      );
      leaveEditor();
      return;
    }
    if (!mounted) return;
    final preset = read;

    // A stale deep link or a preset deleted on another device: there is
    // nothing to edit, so bounce back to the list rather than sit in a
    // broken "edit" state whose Save would fail.
    if (preset == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.weightPresets_editor_notFound)),
      );
      leaveEditor();
      return;
    }

    final units = UnitFormatter(ref.read(settingsProvider));
    setState(() {
      _loading = false;
      _nameController.text = preset.displayName;
      for (final r in _rows) {
        r.dispose();
      }
      _rows
        ..clear()
        ..addAll(
          preset.entries.map(
            (e) => _newRow(
              e.weightType,
              amount: formatRoundedForInput(units.convertWeight(e.amountKg), 3),
              label: e.label,
              loaded: e,
            ),
          ),
        );
      if (_rows.isEmpty) _rows.add(_newRow(WeightType.belt));
    });
    openEditor();
  }

  @override
  void dispose() {
    disposeEditor();
    _nameController.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  static double _amount(_Row row) => switch (readNumber(row.amount.text)) {
    NumberValue(:final value) => value,
    NumberBlank() => 0,
    NumberInvalid() => 0, // unreachable: validate() ran first
  };

  /// The rows as they would be stored: a blank or zero row is left out,
  /// as before. validateEditor() has already stopped unreadable text, which
  /// used to drop its row silently (#1900).
  ///
  /// [stored] is the preset's entries as stored now, by id: a field of a
  /// loaded row the diver left alone is written as stored there.
  List<WeightEntryDraft> _entries({
    Map<String, WeightPresetEntry> stored = const {},
  }) {
    final units = UnitFormatter(ref.read(settingsProvider));
    return [
      for (final r in _rows)
        if (_amount(r) case final amount when amount > 0)
          r.draft(
            convertedKg: units.weightToKg(amount),
            stored: stored[r.loaded?.id],
          ),
    ];
  }

  // The editor's sitting (issue #4527, phase 4).

  @override
  String get editorTable => 'weight_presets';

  @override
  String get editorLeaveLocation => '/weight-presets';

  @override
  String? get editorStoredId => widget.presetId;

  @override
  String editorTitle(BuildContext context) => widget.isEditing
      ? context.l10n.weightPresets_edit_title
      : context.l10n.weightPresets_new_title;

  @override
  WeightPresetDraft readEditorDraft() => WeightPresetDraft(
    name: _nameController.text,
    rows: [
      for (final r in _rows)
        (type: r.type, amount: r.amount.text, label: r.label.text),
    ],
  );

  @override
  bool validateEditor() {
    if (!_formKey.currentState!.validate()) return false;
    if (_entries().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.weightPresets_editor_needWeight)),
      );
      return false;
    }
    return true;
  }

  @override
  Future<void> writeEditor(String recordId) async {
    final repo = ref.read(weightPresetRepositoryProvider);
    final name = _nameController.text.trim();
    final start = editorStartDraft;
    final draft = readEditorDraft();
    if (widget.isEditing) {
      final stored = await repo.getPresetById(recordId);
      // Deleted elsewhere while it was edited (a sync from another device):
      // its weights would have no preset to belong to.
      if (stored == null) {
        throw RecordSittingRefusal(
          (l10n) => l10n.weightPresets_editor_notFound,
        );
      }
      // Only what the diver changed is written, on top of the preset as
      // stored now: a weight or a name synced in meanwhile is not written
      // back over by the copy the page loaded.
      final nameChanged = start == null || draft.name != start.name;
      final rowsChanged = start == null || !listEquals(draft.rows, start.rows);
      if (!rowsChanged) {
        await repo.renamePreset(id: recordId, displayName: name);
        return;
      }
      await repo.updatePreset(
        id: recordId,
        displayName: nameChanged ? name : stored.displayName,
        // The page takes no input while Save writes, so the rows read now
        // are the rows the diver saved.
        entries: _entries(stored: {for (final e in stored.entries) e.id: e}),
      );
      return;
    }
    final diverId = editorDiverId;
    if (diverId == null) {
      throw StateError('A new weight preset needs an active diver');
    }
    await repo.createPreset(
      id: recordId,
      diverId: diverId,
      displayName: name,
      entries: _entries(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);

    return editorScaffold(
      context,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: l10n.diveLog_edit_weightPreset_nameLabel,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.weightPresets_editor_needName
                        : null,
                  ),
                  const SizedBox(height: 20),
                  for (var i = 0; i < _rows.length; i++)
                    _buildRow(i, units, l10n),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() => _rows.add(_newRow(WeightType.belt)));
                        editorChanged();
                      },
                      icon: const Icon(Icons.add),
                      label: Text(l10n.weightPresets_editor_addWeight),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildRow(int index, UnitFormatter units, AppLocalizations l10n) {
    final row = _rows[index];
    // Keyed by the row, so removing one above does not hand its dropdown's
    // state to the next row.
    return Padding(
      key: ObjectKey(row),
      // A row's name sits closer to its own row than to the next.
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<WeightType>(
                  initialValue: row.type,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.diveLog_edit_label_type,
                    isDense: true,
                  ),
                  items: [
                    for (final t in WeightType.values)
                      DropdownMenuItem(
                        value: t,
                        child: Text(t.localizedName(l10n)),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => row.type = v);
                    editorChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: row.amount,
                  decoration: InputDecoration(
                    labelText: units.weightSymbol,
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: numberInputFormatters(),
                  validator: numberValidator(context),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.diveLog_edit_tooltip_removeWeight,
                onPressed: _rows.length == 1
                    ? null
                    : () {
                        setState(() => _rows.removeAt(index).dispose());
                        editorChanged();
                      },
              ),
            ],
          ),
          const SizedBox(height: 8),
          WeightLabelField(controller: row.label),
        ],
      ),
    );
  }
}
