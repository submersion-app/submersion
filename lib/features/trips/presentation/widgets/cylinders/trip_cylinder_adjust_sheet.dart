import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Opens the adjustment sheet for one slot: a gauge reading, "mark empty",
/// or a re-analyzed mix. With [editing] it edits that adjustment in place.
Future<void> showTripCylinderAdjustSheet(
  BuildContext context, {
  required TripCylinder cylinder,
  TripCylinderEvent? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AdjustSheet(cylinder: cylinder, editing: editing),
  );
}

class _AdjustSheet extends ConsumerStatefulWidget {
  final TripCylinder cylinder;
  final TripCylinderEvent? editing;

  const _AdjustSheet({required this.cylinder, required this.editing});

  @override
  ConsumerState<_AdjustSheet> createState() => _AdjustSheetState();
}

class _AdjustSheetState extends ConsumerState<_AdjustSheet> {
  late DateTime _when;
  late final TextEditingController _pressure;
  late final TextEditingController _o2;
  late final TextEditingController _he;
  late final TextEditingController _note;
  bool _saving = false;
  String? _error;

  static String _num(double? v, int digits) =>
      v == null ? '' : formatRoundedForInput(v, digits);

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    final units = UnitFormatter(ref.read(settingsProvider));
    _when = e?.occurredAt ?? tripCylinderWallClock(DateTime.now());
    _pressure = TextEditingController(
      text: e?.pressure == null
          ? ''
          : _num(units.convertPressure(e!.pressure!), 0),
    );
    _o2 = TextEditingController(text: _num(e?.o2Percent, 1));
    final he = e?.hePercent;
    _he = TextEditingController(text: he == null || he == 0 ? '' : _num(he, 1));
    _note = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _pressure.dispose();
    _o2.dispose();
    _he.dispose();
    _note.dispose();
    super.dispose();
  }

  static double? _read(TextEditingController c) => switch (readNumber(c.text)) {
    NumberValue(:final value) => value,
    NumberBlank() => null,
    NumberInvalid() => double.nan,
  };

  Future<void> _pickWhen() async {
    final picked = await pickTripCylinderWhen(context, _when);
    if (picked != null && mounted) setState(() => _when = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = context.l10n;
    final units = UnitFormatter(ref.read(settingsProvider));
    final pressure = _read(_pressure);
    final o2 = _read(_o2);
    final he = _read(_he);
    if ([pressure, o2, he].any((v) => v != null && (v.isNaN || v < 0))) {
      setState(() => _error = tripCylinderInvalidNumber(l10n));
      return;
    }
    final badMix = o2 == null
        ? he != null
        : !tripCylinderMixIsValid(o2, he ?? 0);
    if (badMix) {
      setState(() => _error = l10n.trips_cylinders_fill_errorMix);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(tripCylinderRepositoryProvider);
      final bar = pressure == null ? null : units.pressureToBar(pressure);
      final hePercent = o2 == null ? null : (he ?? 0.0);
      final e = widget.editing;
      if (e != null) {
        await repo.updateEvent(
          e.copyWith(
            occurredAt: _when,
            pressure: bar,
            o2Percent: o2,
            hePercent: hePercent,
            note: _note.text,
          ),
        );
      } else {
        final now = DateTime.now().toUtc();
        await repo.createEvent(
          TripCylinderEvent(
            id: '',
            tripCylinderId: widget.cylinder.id,
            kind: TripCylinderEventKind.adjustment,
            occurredAt: _when,
            pressure: bar,
            o2Percent: o2,
            hePercent: hePercent,
            note: _note.text,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
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
    const decimal = TextInputType.numberWithOptions(decimal: true);
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
              widget.editing == null
                  ? l10n.trips_cylinders_action_adjust
                  : l10n.trips_cylinders_adjust_titleEdit,
              style: theme.textTheme.titleMedium,
            ),
            Text(widget.cylinder.label, style: theme.textTheme.bodyMedium),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.trips_cylinders_fill_when),
              subtitle: Text(units.formatDateTime(_when, l10n: l10n)),
              trailing: const Icon(Icons.schedule),
              onTap: _pickWhen,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('adjust-pressure'),
                    controller: _pressure,
                    decoration: InputDecoration(
                      labelText: l10n.trips_cylinders_adjust_pressure(
                        units.pressureSymbol,
                      ),
                    ),
                    keyboardType: decimal,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  key: const Key('adjust-mark-empty'),
                  onPressed: () => setState(() => _pressure.text = '0'),
                  child: Text(l10n.trips_cylinders_adjust_markEmpty),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('adjust-o2'),
                    controller: _o2,
                    decoration: InputDecoration(
                      labelText: l10n.trips_cylinders_fill_analyzedO2,
                    ),
                    keyboardType: decimal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('adjust-he'),
                    controller: _he,
                    decoration: InputDecoration(
                      labelText: l10n.trips_cylinders_fill_analyzedHe,
                    ),
                    keyboardType: decimal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: l10n.trips_cylinders_note),
              maxLines: 2,
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
