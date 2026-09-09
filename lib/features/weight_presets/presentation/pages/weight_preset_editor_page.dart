import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/weight_enum_display.dart';
import 'package:submersion/features/weight_presets/domain/entities/weight_preset.dart';
import 'package:submersion/features/weight_presets/presentation/providers/weight_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';

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

class _Row {
  WeightType type;
  final TextEditingController amount;
  _Row(this.type, this.amount);
}

class _WeightPresetEditorPageState
    extends ConsumerState<WeightPresetEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rows = <_Row>[];

  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _load();
    } else {
      _rows.add(_Row(WeightType.belt, TextEditingController()));
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final preset = await ref
        .read(weightPresetRepositoryProvider)
        .getPresetById(widget.presetId!);
    if (!mounted) return;

    // A stale deep link or a preset deleted on another device: there is
    // nothing to edit, so bounce back to the list rather than sit in a
    // broken "edit" state whose Save would fail.
    if (preset == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.weightPresets_editor_notFound)),
      );
      if (context.canPop()) context.pop();
      return;
    }

    final units = UnitFormatter(ref.read(settingsProvider));
    setState(() {
      _loading = false;
      _nameController.text = preset.displayName;
      for (final r in _rows) {
        r.amount.dispose();
      }
      _rows
        ..clear()
        ..addAll(
          preset.entries.map(
            (e) => _Row(
              e.weightType,
              TextEditingController(
                text: formatRoundedForInput(units.convertWeight(e.amountKg), 3),
              ),
            ),
          ),
        );
      if (_rows.isEmpty) {
        _rows.add(_Row(WeightType.belt, TextEditingController()));
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final r in _rows) {
      r.amount.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final units = UnitFormatter(ref.read(settingsProvider));
    final entries = <WeightEntryDraft>[
      for (final r in _rows)
        if ((parseUserDecimal(r.amount.text) ?? 0) > 0)
          (
            weightType: r.type,
            amountKg: units.weightToKg(parseUserDecimal(r.amount.text) ?? 0),
            notes: '',
          ),
    ];
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.weightPresets_editor_needWeight)),
      );
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(weightPresetRepositoryProvider);
    final name = _nameController.text.trim();
    try {
      if (widget.isEditing) {
        await repo.updatePreset(
          id: widget.presetId!,
          displayName: name,
          entries: entries,
        );
      } else {
        final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
        if (diverId == null) {
          if (mounted) setState(() => _saving = false);
          return;
        }
        await repo.createPreset(
          diverId: diverId,
          displayName: name,
          entries: entries,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l10n.common_label_error}: $e')),
        );
      }
      return;
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? l10n.weightPresets_edit_title
              : l10n.weightPresets_new_title,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
          tooltip: l10n.common_action_cancel,
        ),
        actions: [
          AppBarTextAction(
            label: l10n.common_action_save,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
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
                      onPressed: () => setState(
                        () => _rows.add(
                          _Row(WeightType.belt, TextEditingController()),
                        ),
                      ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
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
                if (v != null) setState(() => row.type = v);
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
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.diveLog_edit_tooltip_removeWeight,
            onPressed: _rows.length == 1
                ? null
                : () => setState(() {
                    _rows.removeAt(index).amount.dispose();
                  }),
          ),
        ],
      ),
    );
  }
}
