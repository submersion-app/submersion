import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Opens the sheet that adds cylinder slots to a trip: a number of rental
/// slots of one preset, or cylinders from the diver's own equipment that
/// are not on the trip yet. [existing] is the trip's current slots, so new
/// rental labels and board positions continue after them.
Future<void> showAddTripCylindersSheet(
  BuildContext context, {
  required String tripId,
  required List<TripCylinder> existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddTripCylindersSheet(tripId: tripId, existing: existing),
  );
}

enum _AddMode { rental, owned }

/// The largest batch one save adds: a truck, not a fill station's stock.
const int _maxRentalCount = 20;

/// Labels for [count] new rental slots named [prefix]. Numbering continues
/// after the slots already on the trip and past the highest number [prefix]
/// already carries, so a deleted slot never makes a new one repeat a label
/// still on the board.
List<String> tripRentalLabels(
  String prefix,
  int count,
  List<String> existingLabels,
) {
  // At most nine digits, so the match always fits an int.
  final numbered = RegExp(
    prefix.isEmpty ? r'^(\d{1,9})$' : '^${RegExp.escape(prefix)} (\\d{1,9})\$',
  );
  var highest = existingLabels.length;
  for (final label in existingLabels) {
    final digits = numbered.firstMatch(label.trim())?.group(1);
    if (digits == null) continue;
    final n = int.parse(digits);
    if (n > highest) highest = n;
  }
  return [
    for (var n = highest + 1; n <= highest + count; n++)
      prefix.isEmpty ? '$n' : '$prefix $n',
  ];
}

class _AddTripCylindersSheet extends ConsumerStatefulWidget {
  final String tripId;
  final List<TripCylinder> existing;

  const _AddTripCylindersSheet({required this.tripId, required this.existing});

  @override
  ConsumerState<_AddTripCylindersSheet> createState() =>
      _AddTripCylindersSheetState();
}

class _AddTripCylindersSheetState
    extends ConsumerState<_AddTripCylindersSheet> {
  _AddMode _mode = _AddMode.rental;
  final _count = TextEditingController(text: '4');
  final _prefix = TextEditingController();
  bool _prefixSeeded = false;
  String? _presetName = 'al80';
  final Set<String> _owned = {};
  bool _saving = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The default prefix is a translated word, so it waits for context.
    if (!_prefixSeeded) {
      _prefix.text = context.l10n.trips_cylinders_add_prefixDefault;
      _prefixSeeded = true;
    }
  }

  @override
  void dispose() {
    _count.dispose();
    _prefix.dispose();
    super.dispose();
  }

  List<EquipmentItem> _ownedCandidates(List<EquipmentItem> equipment) {
    final taken = {
      for (final c in widget.existing)
        if (c.equipmentId != null) c.equipmentId!,
    };
    return [
      for (final e in equipment)
        if (e.type == EquipmentType.tank && !taken.contains(e.id)) e,
    ];
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = context.l10n;
    final start = widget.existing.length;
    final now = DateTime.now().toUtc();
    final drafts = <TripCylinder>[];
    if (_mode == _AddMode.rental) {
      final count = switch (readNumber(_count.text, integer: true)) {
        NumberValue(:final value) => value.toInt(),
        NumberBlank() || NumberInvalid() => null,
      };
      if (count == null || count < 1 || count > _maxRentalCount) {
        setState(() => _error = l10n.trips_cylinders_add_errorCount);
        return;
      }
      final presets = ref.read(tankPresetsProvider).value ?? const [];
      final preset = presets.where((p) => p.name == _presetName).firstOrNull;
      final labels = tripRentalLabels(_prefix.text.trim(), count, [
        for (final c in widget.existing) c.label,
      ]);
      for (var i = 0; i < count; i++) {
        drafts.add(
          TripCylinder(
            id: '',
            tripId: widget.tripId,
            label: labels[i],
            volume: preset?.volumeLiters,
            workingPressure: preset?.workingPressureBar,
            material: preset?.material,
            presetName: preset?.name,
            sortOrder: start + i,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    } else {
      final equipment = ref.read(activeEquipmentProvider).value ?? const [];
      final picks = _ownedCandidates(
        equipment,
      ).where((e) => _owned.contains(e.id)).toList();
      if (picks.isEmpty) {
        setState(() => _error = l10n.trips_cylinders_fill_errorNoSlot);
        return;
      }
      for (var i = 0; i < picks.length; i++) {
        final e = picks[i];
        final mark = e.identifier?.trim() ?? '';
        drafts.add(
          TripCylinder(
            id: '',
            tripId: widget.tripId,
            equipmentId: e.id,
            label: mark.isEmpty ? e.name : mark,
            volume: e.volumeL,
            workingPressure: e.workingPressureBar,
            material: e.tankMaterial,
            sortOrder: start + i,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // One transaction: a failure part way adds nothing, so Save again
      // never doubles the batch.
      await ref.read(tripCylinderRepositoryProvider).createCylinders(drafts);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = l10n.common_error_tryAgain);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final presets = ref.watch(tankPresetsProvider).value ?? const [];
    final candidates = _ownedCandidates(
      ref.watch(activeEquipmentProvider).value ?? const [],
    );
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.trips_cylinders_action_add,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SegmentedButton<_AddMode>(
              segments: [
                ButtonSegment(
                  value: _AddMode.rental,
                  label: Text(l10n.trips_cylinders_add_tabRental),
                ),
                ButtonSegment(
                  value: _AddMode.owned,
                  label: Text(l10n.trips_cylinders_add_tabOwned),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() {
                _mode = s.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 12),
            if (_mode == _AddMode.rental) ...[
              TextField(
                controller: _count,
                decoration: InputDecoration(
                  labelText: l10n.trips_cylinders_add_count,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: presets.any((p) => p.name == _presetName)
                    ? _presetName
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.trips_cylinders_add_preset,
                ),
                items: [
                  for (final p in presets)
                    DropdownMenuItem<String?>(
                      value: p.name,
                      child: Text(p.displayName),
                    ),
                ],
                onChanged: (v) => setState(() => _presetName = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _prefix,
                decoration: InputDecoration(
                  labelText: l10n.trips_cylinders_add_prefix,
                ),
              ),
            ] else if (candidates.isEmpty)
              Text(l10n.trips_cylinders_add_noOwned)
            else
              for (final e in candidates)
                CheckboxListTile(
                  key: Key('owned-${e.id}'),
                  value: _owned.contains(e.id),
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.name),
                  subtitle: e.volumeL == null
                      ? null
                      : Text(
                          units.formatTankVolume(
                            e.volumeL,
                            e.workingPressureBar,
                          ),
                        ),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _owned.add(e.id);
                    } else {
                      _owned.remove(e.id);
                    }
                  }),
                ),
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.common_action_cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(l10n.common_action_save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
