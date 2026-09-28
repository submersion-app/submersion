import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_picker.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/services/trip_fill_saver.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// True when a cylinder can hold the mix: O2 1 to 100 percent, He 0 to 99,
/// together at most 100.
bool tripCylinderMixIsValid(double o2, double he) =>
    o2 >= 1 && o2 <= 100 && he >= 0 && he <= 99 && o2 + he <= 100;

/// The fill station the trip used last, for the sheet's default: the Bonaire
/// ritual is the same drive-through every morning.
String? lastTripFillCenter(List<TripCylinderState> slots) {
  TripCylinderEvent? latest;
  for (final s in slots) {
    final fill = s.lastFill;
    if (fill == null || fill.diveCenterId == null) continue;
    if (latest == null || fill.occurredAt.isAfter(latest.occurredAt)) {
      latest = fill;
    }
  }
  return latest?.diveCenterId;
}

/// Asks for a date, then a time, starting from [current]. Returns the
/// picked wall clock stamped UTC, the frame every dive time uses, or null
/// when the diver cancels either picker. Shared by the fill and adjust
/// sheets.
Future<DateTime?> pickTripCylinderWhen(
  BuildContext context,
  DateTime current,
) async {
  final date = await showAppDatePicker(
    context: context,
    initialDate: DateTime(current.year, current.month, current.day),
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
  );
  if (time == null) return null;
  return DateTime.utc(date.year, date.month, date.day, time.hour, time.minute);
}

/// Opens the fill sheet. With [several] every slot is listed with a
/// checkbox ([preselected] checked); otherwise only the preselected slot is
/// shown. With [editing] the sheet edits that fill in place.
Future<void> showTripCylinderFillSheet(
  BuildContext context, {
  required List<TripCylinderState> slots,
  Set<String> preselected = const {},
  bool several = false,
  TripCylinderEvent? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FillSheet(
      slots: slots,
      preselected: preselected,
      several: several && editing == null,
      editing: editing,
    ),
  );
}

class _FillSheet extends ConsumerStatefulWidget {
  final List<TripCylinderState> slots;
  final Set<String> preselected;
  final bool several;
  final TripCylinderEvent? editing;

  const _FillSheet({
    required this.slots,
    required this.preselected,
    required this.several,
    required this.editing,
  });

  @override
  ConsumerState<_FillSheet> createState() => _FillSheetState();
}

typedef _Analysis = ({double? o2, double? he});

class _FillSheetState extends ConsumerState<_FillSheet> {
  late Set<String> _selected;
  late DateTime _when;
  String? _centerId;
  late final TextEditingController _pressure;
  late final TextEditingController _o2;
  late final TextEditingController _he;
  late final TextEditingController _cost;
  late final TextEditingController _note;
  final _bottle = <String, TextEditingController>{};
  final _analyzedO2 = <String, TextEditingController>{};
  final _analyzedHe = <String, TextEditingController>{};
  late String _currency;
  bool _package = false;
  bool _saving = false;
  String? _error;

  /// Writes this sheet's fills and remembers what each attempt stored, so
  /// Save again after a failure never doubles a fill.
  late final TripFillSaver _saver;

  static String _num(double? v, int digits) =>
      v == null ? '' : formatRoundedForInput(v, digits);

  @override
  void initState() {
    super.initState();
    _saver = TripFillSaver(
      repository: ref.read(tripCylinderRepositoryProvider),
      copier: ref.read(tripFillPassportCopierProvider),
    );
    final e = widget.editing;
    final units = UnitFormatter(ref.read(settingsProvider));
    _selected = e != null ? {e.tripCylinderId} : {...widget.preselected};
    _when = e?.occurredAt ?? tripCylinderWallClock(DateTime.now());
    _centerId = e != null ? e.diveCenterId : lastTripFillCenter(widget.slots);
    GasMix? firstMix;
    for (final s in widget.slots) {
      if (_selected.contains(s.cylinder.id)) {
        firstMix = s.mix;
        break;
      }
    }
    final he = e?.hePercent ?? firstMix?.he;
    _pressure = TextEditingController(
      text: e?.pressure == null
          ? ''
          : _num(units.convertPressure(e!.pressure!), 0),
    );
    _o2 = TextEditingController(
      text: _num(e?.o2Percent ?? firstMix?.o2 ?? 21, 1),
    );
    _he = TextEditingController(text: he == null || he == 0 ? '' : _num(he, 1));
    for (final s in widget.slots) {
      final id = s.cylinder.id;
      final mine = e != null && e.tripCylinderId == id;
      _bottle[id] = TextEditingController(
        text: mine ? (e.bottleLabel ?? '') : '',
      );
      _analyzedO2[id] = TextEditingController(
        text: mine ? _num(e.analyzedO2, 1) : '',
      );
      _analyzedHe[id] = TextEditingController(
        text: mine ? _num(e.analyzedHe, 1) : '',
      );
    }
    _cost = TextEditingController(text: _num(e?.cost, 2));
    // Read on its own line: inside `?? ...` the generic read infers String?
    // from the left operand and the result would be nullable.
    final String fallbackCurrency = ref.read(defaultCurrencyProvider);
    final code = (e?.currency ?? fallbackCurrency).trim().toUpperCase();
    _currency = code.isEmpty ? 'USD' : code;
    _package = e?.isPackage ?? false;
    _note = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _pressure,
      _o2,
      _he,
      _cost,
      _note,
      ..._bottle.values,
      ..._analyzedO2.values,
      ..._analyzedHe.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Null for a blank field; NaN for text that is not a number.
  static double? _read(TextEditingController c) => switch (readNumber(c.text)) {
    NumberValue(:final value) => value,
    NumberBlank() => null,
    NumberInvalid() => double.nan,
  };

  static String? _text(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  /// A new fill on slot [id]; [_save] fills in the fields from the form.
  static TripCylinderEvent _blankFill(String id, DateTime now) =>
      TripCylinderEvent(
        id: '',
        tripCylinderId: id,
        kind: TripCylinderEventKind.fill,
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      );

  Future<void> _pickWhen() async {
    final picked = await pickTripCylinderWhen(context, _when);
    if (picked != null && mounted) setState(() => _when = picked);
  }

  Future<void> _pickCenter(List<DiveCenter> centers) async {
    final current = centers.where((c) => c.id == _centerId).firstOrNull;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => DiveCenterPickerSheet(
          scrollController: scrollController,
          selectedCenter: current,
          onCenterSelected: (center) {
            Navigator.of(sheetContext).pop();
            setState(() => _centerId = center.id);
          },
          // Creating a center is the dive editor's flow; here the picker
          // only chooses among existing ones.
          onCreateNewCenter: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = context.l10n;
    final units = UnitFormatter(ref.read(settingsProvider));
    final ids = [
      for (final s in widget.slots)
        if (_selected.contains(s.cylinder.id)) s.cylinder.id,
    ];
    if (ids.isEmpty) {
      setState(() => _error = l10n.trips_cylinders_fill_errorNoSlot);
      return;
    }
    final pressure = _read(_pressure);
    final o2 = _read(_o2);
    final he = _read(_he);
    final cost = _read(_cost);
    final analysis = <String, _Analysis>{
      for (final id in ids)
        id: (o2: _read(_analyzedO2[id]!), he: _read(_analyzedHe[id]!)),
    };
    final fields = [
      _pressure,
      _o2,
      _he,
      _cost,
      for (final id in ids) ...[_analyzedO2[id]!, _analyzedHe[id]!],
    ];
    final invalid = fields
        .map((c) => invalidNumberText(context, c.text, allowNegative: false))
        .nonNulls
        .firstOrNull;
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    // A fill leaves pressure in the cylinder; zero would read as "Full".
    if (pressure != null && pressure < 1) {
      setState(() => _error = l10n.numberInput_atLeastOne);
      return;
    }
    final orderedO2 = o2 ?? 21.0;
    final orderedHe = he ?? 0.0;
    bool badAnalysis(_Analysis a) =>
        a.o2 == null ? a.he != null : !tripCylinderMixIsValid(a.o2!, a.he ?? 0);
    if (!tripCylinderMixIsValid(orderedO2, orderedHe) ||
        analysis.values.any(badAnalysis)) {
      setState(() => _error = l10n.trips_cylinders_fill_errorMix);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final bar = pressure == null ? null : units.pressureToBar(pressure);
      final currency = cost == null ? null : _currency;
      // The form's values on [base], a new fill or the one being edited.
      TripCylinderEvent withForm(TripCylinderEvent base) {
        final id = base.tripCylinderId;
        final a = analysis[id]!;
        return base.copyWith(
          occurredAt: _when,
          bottleLabel: _text(_bottle[id]!),
          pressure: bar,
          o2Percent: orderedO2,
          hePercent: orderedHe,
          analyzedO2: a.o2,
          analyzedHe: a.he,
          diveCenterId: _centerId,
          cost: cost,
          currency: currency,
          isPackage: _package,
          note: _note.text,
        );
      }

      final e = widget.editing;
      final now = DateTime.now().toUtc();
      final saved = e != null
          ? [await _saver.writeEdit(withForm(e))]
          : await _saver.writeFills([
              for (final id in ids) withForm(_blankFill(id, now)),
            ]);
      // A fill on one of the diver's own cylinders is also written to its
      // passport, and an edit updates that copy (Task 6). Wait for the
      // centers rather than reading a list still loading, or the copy would
      // lose its station name.
      var centers = const <DiveCenter>[];
      var stationResolved = true;
      if (_centerId != null) {
        try {
          centers = await ref.read(allDiveCentersProvider.future);
        } catch (_) {
          // The fills are saved; without the list a new passport copy has
          // no station name and an existing one keeps the name it had. That
          // must not fail the whole save.
          stationResolved = false;
        }
      }
      await _saver.copyToPassports(
        saved,
        {for (final s in widget.slots) s.cylinder.id: s.cylinder},
        diverId: ref.read(currentDiverIdProvider),
        stationName: centers.where((c) => c.id == _centerId).firstOrNull?.name,
        stationResolved: stationResolved,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = l10n.common_error_tryAgain);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _slotFields(String id) {
    final l10n = context.l10n;
    InputDecoration dense(String label) =>
        InputDecoration(labelText: label, isDense: true);
    const decimal = TextInputType.numberWithOptions(decimal: true);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: Key('fill-bottle-$id'),
              controller: _bottle[id],
              decoration: dense(l10n.trips_cylinders_fill_bottle),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: Key('fill-aO2-$id'),
              controller: _analyzedO2[id],
              decoration: dense(l10n.trips_cylinders_fill_analyzedO2),
              keyboardType: decimal,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: Key('fill-aHe-$id'),
              controller: _analyzedHe[id],
              decoration: dense(l10n.trips_cylinders_fill_analyzedHe),
              keyboardType: decimal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final centers =
        ref.watch(allDiveCentersProvider).value ?? const <DiveCenter>[];
    final centerName = centers
        .where((c) => c.id == _centerId)
        .firstOrNull
        ?.name;
    const decimal = TextInputType.numberWithOptions(decimal: true);
    final title = widget.editing != null
        ? l10n.trips_cylinders_fill_titleEdit
        : widget.several
        ? l10n.trips_cylinders_action_fillSeveral
        : l10n.trips_cylinders_action_fill;
    final quickMixes = <(String, double)>[
      (tripCylinderMixLabel(l10n, const GasMix()), 21),
      ('EAN32', 32),
      ('EAN36', 36),
    ];
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
            Text(title, style: theme.textTheme.titleMedium),
            ListTile(
              key: const Key('fill-when'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.trips_cylinders_fill_when),
              subtitle: Text(units.formatDateTime(_when, l10n: l10n)),
              trailing: const Icon(Icons.schedule),
              onTap: _pickWhen,
            ),
            ListTile(
              key: const Key('fill-where'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.trips_cylinders_fill_where),
              subtitle: Text(centerName ?? l10n.trips_cylinders_fill_whereNone),
              trailing: _centerId == null
                  ? const Icon(Icons.chevron_right)
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: l10n.common_action_remove,
                      onPressed: () => setState(() => _centerId = null),
                    ),
              onTap: () => _pickCenter(centers),
            ),
            TextField(
              key: const Key('fill-pressure'),
              controller: _pressure,
              decoration: InputDecoration(
                labelText: l10n.trips_cylinders_fill_pressure(
                  units.pressureSymbol,
                ),
              ),
              keyboardType: decimal,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('fill-o2'),
                    controller: _o2,
                    decoration: InputDecoration(
                      labelText: l10n.trips_cylinders_fill_o2,
                    ),
                    keyboardType: decimal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('fill-he'),
                    controller: _he,
                    decoration: InputDecoration(
                      labelText: l10n.trips_cylinders_fill_he,
                    ),
                    keyboardType: decimal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final (label, o2) in quickMixes)
                  ActionChip(
                    label: Text(label),
                    onPressed: () => setState(() {
                      _o2.text = _num(o2, 1);
                      _he.text = '';
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.several)
              Text(
                l10n.trips_cylinders_fill_slots,
                style: theme.textTheme.titleSmall,
              ),
            for (final s in widget.slots)
              if (widget.several) ...[
                CheckboxListTile(
                  key: Key('fill-slot-${s.cylinder.id}'),
                  value: _selected.contains(s.cylinder.id),
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.cylinder.label),
                  onChanged: (v) => setState(() {
                    final id = s.cylinder.id;
                    _selected = v == true
                        ? {..._selected, id}
                        : {
                            for (final x in _selected)
                              if (x != id) x,
                          };
                  }),
                ),
                if (_selected.contains(s.cylinder.id))
                  _slotFields(s.cylinder.id),
              ] else if (_selected.contains(s.cylinder.id)) ...[
                Text(s.cylinder.label, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                _slotFields(s.cylinder.id),
              ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('fill-cost'),
                    controller: _cost,
                    decoration: InputDecoration(
                      // Several slots each store this cost, so say so.
                      labelText: widget.several
                          ? l10n.trips_cylinders_fill_costEach
                          : l10n.trips_cylinders_fill_cost,
                    ),
                    keyboardType: decimal,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<String>(
                    key: const Key('fill-currency'),
                    initialValue: _currency,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.trips_cylinders_fill_currency,
                    ),
                    items: [
                      for (final code in currencyCodesWith(_currency))
                        DropdownMenuItem(value: code, child: Text(code)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _currency = v);
                    },
                  ),
                ),
              ],
            ),
            SwitchListTile(
              key: const Key('fill-package'),
              contentPadding: EdgeInsets.zero,
              value: _package,
              title: Text(l10n.trips_cylinders_fill_package),
              onChanged: (v) => setState(() => _package = v),
            ),
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
