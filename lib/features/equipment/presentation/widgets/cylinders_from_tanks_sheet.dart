import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/services/cylinder_from_tank_service.dart';
import 'package:submersion/features/equipment/domain/services/tank_cylinder_matching.dart';
import 'package:submersion/features/equipment/presentation/helpers/tank_volume_input.dart';
import 'package:submersion/features/equipment/presentation/providers/cylinder_proposal_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Lets the diver review cylinders made from dive tanks and add them to
/// their gear (issue #4494). Resolves to how many items were created, or null
/// when dismissed; on success a SnackBar says so.
Future<int?> showCylindersFromTanksSheet(
  BuildContext context,
  List<CylinderProposal> proposals,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = context.l10n;
  final created = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CylindersFromTanksSheet(proposals: proposals),
  );
  if (created != null && created > 0) {
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.cylindersFromTanks_added(created))),
    );
  }
  return created;
}

class CylindersFromTanksSheet extends ConsumerStatefulWidget {
  const CylindersFromTanksSheet({super.key, required this.proposals});

  final List<CylinderProposal> proposals;

  @override
  ConsumerState<CylindersFromTanksSheet> createState() =>
      _CylindersFromTanksSheetState();
}

/// One row's edits. Volume and pressure fields start in the diver's units;
/// text left as it started reads back as the logged metric value exactly.
class _RowEdit {
  _RowEdit(this.proposal, UnitFormatter units, String name)
    : name = TextEditingController(text: name),
      material = proposal.material,
      volumeText = tankVolumeInputText(
        proposal.volumeL,
        proposal.workingPressureBar,
        units.settings.volumeUnit,
      ),
      pressureText = proposal.workingPressureBar == null
          ? ''
          : formatRoundedForInput(
              units.convertPressure(proposal.workingPressureBar!),
              0,
            ) {
    volume = TextEditingController(text: volumeText);
    pressure = TextEditingController(text: pressureText);
    _volumeInCuft =
        units.settings.volumeUnit == VolumeUnit.cubicFeet &&
        proposal.workingPressureBar != null;
  }

  final CylinderProposal proposal;
  final TextEditingController name;
  late final TextEditingController volume;
  late final TextEditingController pressure;
  final String volumeText;
  final String pressureText;
  TankMaterial? material;
  bool include = true;

  /// Whether the pressure field holds a number or nothing: a mistyped one
  /// must not save as "no working pressure" onto the cylinder and its tanks.
  /// Blank (no rating) or a positive figure. Zero is no rating a cylinder
  /// has, and a cubic feet volume cannot be read at it.
  bool get pressureReadable =>
      switch (readNumber(pressure.text, allowNegative: false)) {
        NumberBlank() => true,
        NumberValue(:final value) => value > 0,
        NumberInvalid() => false,
      };

  double? pressureBar(UnitFormatter units) {
    if (pressure.text.trim() == pressureText.trim()) {
      return proposal.workingPressureBar;
    }
    final read = readNumber(pressure.text, allowNegative: false);
    return read is NumberValue && read.value > 0
        ? units.pressureToBar(read.value)
        : null;
  }

  /// Whether the volume field is in cubic feet. Fixed when the row opens,
  /// as [tankVolumeInputText] chose it: cubic feet only when a working
  /// pressure made the conversion possible. A field that opened in liters
  /// stays in liters when a pressure is typed later, so its figure is never
  /// reread in another unit.
  bool get volumeInCuft => _volumeInCuft;
  late final bool _volumeInCuft;

  /// In cubic feet the figure depends on the working pressure, so once the
  /// pressure changes the shown figure is read again at the new one; with
  /// the pressure cleared it cannot be read at all.
  double? volumeL(UnitFormatter units) {
    if (!volumeInCuft) {
      return tankVolumeFromInput(
        volume.text,
        initialText: volumeText,
        initialLiters: proposal.volumeL,
        workingPressureBar: null,
        unit: VolumeUnit.liters,
      );
    }
    final bar = pressureBar(units);
    if (bar == null) return null;
    return tankVolumeFromInput(
      volume.text,
      initialText: pressure.text.trim() == pressureText.trim()
          ? volumeText
          : '',
      initialLiters: proposal.volumeL,
      workingPressureBar: bar,
      unit: VolumeUnit.cubicFeet,
    );
  }

  void dispose() {
    name.dispose();
    volume.dispose();
    pressure.dispose();
  }
}

class _CylindersFromTanksSheetState
    extends ConsumerState<CylindersFromTanksSheet> {
  late final UnitFormatter _units;
  List<_RowEdit> _rows = const [];
  bool _saving = false;

  /// Shown in the sheet itself: a SnackBar would land on the page beneath.
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _units = UnitFormatter(ref.read(settingsProvider));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The names need the localizations, which initState cannot read.
    if (_rows.isEmpty) {
      _rows = [
        for (final p in widget.proposals) _RowEdit(p, _units, _fallbackName(p)),
      ];
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  /// The proposal's own name, else its size and material ("11.1 L Steel").
  String _fallbackName(CylinderProposal p) {
    final suggested = p.suggestedName;
    if (suggested != null) return suggested;
    return context.l10n
        .cylindersFromTanks_sizeName(
          _units.formatTankVolume(p.volumeL, p.workingPressureBar),
          p.material?.localizedName(context.l10n) ?? '',
        )
        .trim();
  }

  int get _cylinderCount => [
    for (final row in _rows)
      if (row.include) row.proposal.cylinderCount,
  ].fold(0, (a, b) => a + b);

  bool get _canSave =>
      !_saving &&
      _cylinderCount > 0 &&
      _rows.every(
        (r) =>
            !r.include || ((r.volumeL(_units) ?? 0) > 0 && r.pressureReadable),
      );

  Future<void> _save() async {
    // A repeated activation can reach this before the disabled button is
    // rebuilt; one save only.
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    final drafts = [
      for (final row in _rows)
        if (row.include)
          CylinderDraft(
            proposal: row.proposal,
            name: row.name.text.trim().isEmpty
                ? _fallbackName(row.proposal)
                : row.name.text.trim(),
            volumeL: row.volumeL(_units)!,
            workingPressureBar: row.pressureBar(_units),
            material: row.material,
          ),
    ];
    try {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      final created = await ref
          .read(cylinderFromTankServiceProvider)
          .create(drafts, diverId: diverId);
      if (mounted) Navigator.of(context).pop(created.length);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text(
              l10n.cylindersFromTanks_title,
              style: theme.textTheme.titleLarge,
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _rows.length,
              separatorBuilder: (_, _) => const Divider(height: 24),
              itemBuilder: (context, i) => _rowView(context, _rows[i], i),
            ),
          ),
          if (_failed)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                l10n.cylindersFromTanks_failed,
                key: const Key('cylinders-from-tanks-failed'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    MaterialLocalizations.of(context).cancelButtonLabel,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('cylinders-from-tanks-add'),
                  onPressed: _canSave ? _save : null,
                  child: Text(l10n.cylindersFromTanks_add(_cylinderCount)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowView(BuildContext context, _RowEdit row, int index) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final p = row.proposal;
    final cuft = row.volumeInCuft;
    final details = [
      if (p.cylinderCount > 1) l10n.cylindersFromTanks_makes(p.cylinderCount),
      l10n.cylindersFromTanks_onDives(p.diveCount),
    ].join(' · ');
    void changed() => setState(() {});
    return Column(
      key: Key('cylinders-from-tanks-row-$index'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: row.include,
          onChanged: (v) => setState(() => row.include = v ?? false),
          title: Text(_fallbackName(p)),
          subtitle: Text(
            details,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextField(
          controller: row.name,
          enabled: row.include,
          decoration: InputDecoration(
            labelText: l10n.cylindersFromTanks_name,
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: NumberField(
                controller: row.volume,
                enabled: row.include,
                onChanged: (_) => changed(),
                decoration: InputDecoration(
                  labelText: l10n.diveLog_tank_label_volume,
                  suffixText: cuft
                      ? _units.volumeSymbol
                      : VolumeUnit.liters.symbol,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<TankMaterial?>(
                initialValue: row.material,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.diveLog_tank_label_material,
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem<TankMaterial?>(
                    value: null,
                    child: Text(l10n.diveLog_edit_notSpecified),
                  ),
                  for (final m in TankMaterial.values)
                    DropdownMenuItem(
                      value: m,
                      child: Text(m.localizedName(l10n)),
                    ),
                ],
                onChanged: row.include
                    ? (v) => setState(() => row.material = v)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NumberField(
                controller: row.pressure,
                enabled: row.include,
                onChanged: (_) => changed(),
                decoration: InputDecoration(
                  labelText: l10n.diveLog_tank_label_workingPressure,
                  suffixText: _units.pressureSymbol,
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
