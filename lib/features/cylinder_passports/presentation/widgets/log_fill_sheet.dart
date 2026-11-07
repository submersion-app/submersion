import 'package:flutter/material.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_pairing.dart';
import 'package:submersion/features/cylinder_passports/domain/services/pairing_rules.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_pairing_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/tied_fill_dialogs.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// A number typed by a diver, read in the active locale: grouping is honoured
/// (3,000 psi is three thousand in English), a mistyped decimal separator is
/// corrected where that is unambiguous, and blanks, letters and non-finite
/// values are not numbers.
double? parseDecimal(String text) => switch (readNumber(text)) {
  NumberValue(:final value) => value,
  NumberBlank() || NumberInvalid() => null,
};

/// What the fill sheet saved: the fill on this cylinder and, for a twin set
/// fill (issue #4242), the same fill on its partner.
class LoggedFill {
  const LoggedFill({required this.fill, this.partnerFill});

  final CylinderFill fill;
  final CylinderFill? partnerFill;
}

/// Opens the manual fill sheet. Resolves with what was saved, or null when
/// the diver backed out. The initial values prefill a planned fill, such as
/// a blend; with [mixFromPlan] the sheet asks for the analysed mix instead.
/// With [editing] the sheet edits that fill rather than logging a new one.
Future<LoggedFill?> showLogFillSheet(
  BuildContext context, {
  required String passportId,
  required String equipmentId,
  GasMix? initialMix,
  double? initialPressureBar,
  double? initialTemperatureC,
  bool mixFromPlan = false,
  CylinderFill? editing,
}) => showModalBottomSheet<LoggedFill>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: LogFillSheet(
      passportId: passportId,
      equipmentId: equipmentId,
      initialMix: initialMix,
      initialPressureBar: initialPressureBar,
      initialTemperatureC: initialTemperatureC,
      mixFromPlan: mixFromPlan,
      editing: editing,
    ),
  ),
);

class LogFillSheet extends ConsumerStatefulWidget {
  const LogFillSheet({
    super.key,
    required this.passportId,
    required this.equipmentId,
    this.initialMix,
    this.initialPressureBar,
    this.initialTemperatureC,
    this.mixFromPlan = false,
    this.editing,
    this.initialFilledAt,
  });

  final String passportId;
  final String equipmentId;
  final GasMix? initialMix;
  final double? initialPressureBar;
  final double? initialTemperatureC;

  /// The mix came from a plan, not an analyser, so the diver is asked to
  /// enter what they analysed.
  final bool mixFromPlan;

  /// The fill being edited, prefilled; null to log a new fill.
  final CylinderFill? editing;

  /// When a new fill happened, for a caller that knows; now otherwise.
  final DateTime? initialFilledAt;

  @override
  ConsumerState<LogFillSheet> createState() => _LogFillSheetState();
}

class _LogFillSheetState extends ConsumerState<LogFillSheet> {
  late DateTime _filledAt =
      widget.editing?.filledAt ?? widget.initialFilledAt ?? DateTime.now();

  /// The diver's twin switch choice, and the partner it was made for: a
  /// date change that lands on another partner starts from that partner's
  /// default again.
  bool? _twinChoice;
  String? _twinChoicePartnerId;

  /// The pressure and temperature text an edit opened with: a field the
  /// diver left alone keeps the stored value rather than its rounded
  /// display (3191 psi reads back as 220.01 bar).
  String? _prefilledPressure;
  String? _prefilledTemperature;
  final _o2 = TextEditingController(text: '21');
  final _he = TextEditingController(text: '0');
  final _pressure = TextEditingController();
  final _temperature = TextEditingController();
  final _station = TextEditingController();
  final _analyzer = TextEditingController();
  final _stationFocus = FocusNode();
  final _analyzerFocus = FocusNode();
  List<String> _recentStations = const [];
  List<String> _recentAnalyzers = const [];
  final _notes = TextEditingController();
  String? _mixError;
  String? _pressureError;
  String? _temperatureError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final units = UnitFormatter(ref.read(settingsProvider));
    if (widget.initialMix case final mix?) {
      _o2.text = formatDecimalForInput(mix.o2);
      _he.text = formatDecimalForInput(mix.he);
    }
    if (widget.initialPressureBar case final bar?) {
      // A tenth of a bar, as the blender shows a bar pressure; whole psi.
      final decimals = units.settings.pressureUnit == PressureUnit.bar ? 1 : 0;
      _pressure.text = formatRoundedForInput(
        units.convertPressure(bar),
        decimals,
      );
    }
    if (widget.initialTemperatureC case final c?) {
      _temperature.text = formatRoundedForInput(units.convertTemperature(c), 1);
    }
    if (widget.editing case final fill?) _prefill(fill, units);
    _loadHistory();
  }

  void _prefill(CylinderFill fill, UnitFormatter units) {
    _o2.text = formatDecimalForInput(fill.o2Percent);
    _he.text = formatDecimalForInput(fill.hePercent);
    if (fill.pressureBar case final bar?) {
      final decimals = units.settings.pressureUnit == PressureUnit.bar ? 1 : 0;
      _pressure.text = formatRoundedForInput(
        units.convertPressure(bar),
        decimals,
      );
    }
    if (fill.temperatureC case final c?) {
      _temperature.text = formatRoundedForInput(units.convertTemperature(c), 1);
    }
    _prefilledPressure = _pressure.text;
    _prefilledTemperature = _temperature.text;
    _station.text = fill.stationName ?? '';
    _analyzer.text = fill.analyzer ?? '';
    _notes.text = fill.notes;
  }

  /// The twin set partner of this cylinder on the fill's day (issue #4242),
  /// or null when it had none or the sheet edits a fill.
  EquipmentItem? _watchPartner() {
    if (widget.editing != null) return null;
    final pairing = ref
        .watch(
          pairingOnProvider((
            equipmentId: widget.equipmentId,
            day: calendarDay(_filledAt),
          )),
        )
        .value;
    if (pairing == null) return null;
    return ref
        .watch(equipmentItemProvider(pairing.partnerOf(widget.equipmentId)))
        .value;
  }

  /// Whether the twin switch is on for [partner]: the diver's choice, or on
  /// unless the partner is away from the pair.
  bool _twinOn(EquipmentItem partner) =>
      (_twinChoicePartnerId == partner.id ? _twinChoice : null) ??
      !isPartnerOutOfUse(partner.effectiveStatus);

  /// Recent stations and analyzers for suggestions; the analyzer a diver
  /// used last is filled in, since it is usually the same instrument.
  Future<void> _loadHistory() async {
    try {
      final repository = ref.read(cylinderFillRepositoryProvider);
      final stations = await repository.recentStationNames();
      final analyzers = await repository.recentAnalyzers();
      if (!mounted) return;
      setState(() {
        _recentStations = stations;
        _recentAnalyzers = analyzers;
        if (widget.editing == null &&
            _analyzer.text.isEmpty &&
            analyzers.isNotEmpty) {
          _analyzer.text = analyzers.first;
        }
      });
    } catch (_) {
      // Suggestions are a convenience; the sheet works without them.
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_filledAt),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _filledAt = DateTime(
        _filledAt.year,
        _filledAt.month,
        _filledAt.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  @override
  void dispose() {
    _stationFocus.dispose();
    _analyzerFocus.dispose();
    for (final c in [
      _o2,
      _he,
      _pressure,
      _temperature,
      _station,
      _analyzer,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _filledAt,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _filledAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _filledAt.hour,
        _filledAt.minute,
      );
    });
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.read(settingsProvider));
    final o2 = parseDecimal(_o2.text);
    final he = parseDecimal(_he.text);
    final pressureText = _pressure.text.trim();
    final temperatureText = _temperature.text.trim();
    final pressure = pressureText.isEmpty ? null : parseDecimal(pressureText);
    final temperature = temperatureText.isEmpty
        ? null
        : parseDecimal(temperatureText);

    final mixInvalid =
        o2 == null || he == null || !CylinderFill.isPossibleMix(o2, he);
    setState(() {
      _mixError = mixInvalid ? l10n.passport_logFill_invalidMix : null;
      // Null for blank (both optional) and for readable text.
      _pressureError = invalidNumberText(context, pressureText);
      _temperatureError = invalidNumberText(context, temperatureText);
    });
    if (_mixError != null ||
        _pressureError != null ||
        _temperatureError != null) {
      return;
    }

    final pressureBar = pressure == null ? null : units.pressureToBar(pressure);
    final temperatureC = temperature == null
        ? null
        : units.temperatureToCelsius(temperature);
    final analyzer = _analyzer.text.trim();
    final station = _station.text.trim();
    // Saving from here: a second tap while the partner is read or a warning
    // is open must not save twice.
    setState(() => _saving = true);
    final partner = widget.editing == null ? await _partnerForSave() : null;
    if (!mounted) return;
    final twin = partner != null && _twinOn(partner);
    if (twin &&
        pressureBar != null &&
        !await _acceptPressure(pressureBar, partner, units)) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (!mounted) return;
    final LoggedFill logged;
    try {
      if (widget.editing case final editing?) {
        final editedPressure = _pressure.text == _prefilledPressure
            ? editing.pressureBar
            : pressureBar;
        final editedTemperature = _temperature.text == _prefilledTemperature
            ? editing.temperatureC
            : temperatureC;
        final edited = editing.copyWith(
          filledAt: _filledAt,
          o2Percent: o2,
          hePercent: he,
          pressureBar: editedPressure,
          clearPressureBar: editedPressure == null,
          temperatureC: editedTemperature,
          clearTemperatureC: editedTemperature == null,
          analyzer: analyzer.isEmpty ? null : analyzer,
          clearAnalyzer: analyzer.isEmpty,
          stationName: station.isEmpty ? null : station,
          clearStationName: station.isEmpty,
          notes: _notes.text.trim(),
        );
        final toTied = await _askApplyToTied(editing);
        if (toTied == null) {
          if (mounted) setState(() => _saving = false);
          return;
        }
        await ref
            .read(twinFillServiceProvider)
            .applyEdit(edited, toTied: toTied);
        logged = LoggedFill(fill: edited);
      } else {
        final now = DateTime.now();
        final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
        final fill = CylinderFill(
          id: '',
          diverId: diverId,
          passportId: widget.passportId,
          equipmentId: widget.equipmentId,
          filledAt: _filledAt,
          o2Percent: o2!,
          hePercent: he!,
          pressureBar: pressureBar,
          temperatureC: temperatureC,
          analyzer: analyzer.isEmpty ? null : analyzer,
          stationName: station.isEmpty ? null : station,
          source: FillSource.manual,
          notes: _notes.text.trim(),
          createdAt: now,
          updatedAt: now,
        );
        if (twin) {
          final saved = await ref
              .read(twinFillServiceProvider)
              .recordTwinFill(fill, partnerEquipmentId: partner.id);
          logged = LoggedFill(fill: saved.fill, partnerFill: saved.partnerFill);
        } else {
          logged = LoggedFill(
            fill: await ref.read(cylinderFillRepositoryProvider).create(fill),
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.passport_logFill_saveFailed)));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(logged);
  }

  /// The partner a new fill would also go on, read fresh at save time.
  Future<EquipmentItem?> _partnerForSave() async {
    try {
      final pairing = await ref.read(
        pairingOnProvider((
          equipmentId: widget.equipmentId,
          day: calendarDay(_filledAt),
        )).future,
      );
      if (pairing == null) return null;
      return await ref.read(
        equipmentItemProvider(pairing.partnerOf(widget.equipmentId)).future,
      );
    } catch (_) {
      // The pairing could not be read: the fill goes on this cylinder only.
      return null;
    }
  }

  /// Warns when a twin fill's [pressureBar] is above either cylinder's
  /// working pressure. True to go on saving.
  Future<bool> _acceptPressure(
    double pressureBar,
    EquipmentItem partner,
    UnitFormatter units,
  ) async {
    EquipmentItem? self;
    try {
      self = await ref.read(equipmentItemProvider(widget.equipmentId).future);
    } catch (_) {
      self = null;
    }
    // Each cylinder above its rating is named in turn; Back on any stops.
    for (final item in [?self, partner]) {
      final rated = item.workingPressureBar;
      if (rated == null || pressureBar <= rated + 0.5) continue;
      if (!mounted) return false;
      final go = await confirmOverPressure(
        context,
        pressure: units.formatPressure(pressureBar),
        name: item.name,
        workingPressure: units.formatPressure(rated),
      );
      if (!go) return false;
    }
    return true;
  }

  /// For an edit of one fill of a twin set fill: whether the other fill
  /// takes the edit too. False when there is no other fill, null when the
  /// diver backed out.
  Future<bool?> _askApplyToTied(CylinderFill editing) async {
    final tied = await ref
        .read(cylinderFillRepositoryProvider)
        .tiedFillOf(editing);
    if (tied == null || !mounted) return false;
    final partnerId = tied.equipmentId;
    final partner = partnerId == null
        ? null
        : await ref.read(equipmentItemProvider(partnerId).future);
    if (!mounted) return null;
    return askApplyToTiedFill(
      context,
      partner?.name ?? context.l10n.passport_history_anotherCylinder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final partner = _watchPartner();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.editing == null
                ? l10n.passport_fill_log
                : l10n.passport_logFill_editTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(l10n.passport_logFill_date),
            subtitle: Text(units.formatDate(_filledAt)),
            onTap: _pickDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(l10n.passport_logFill_time),
            subtitle: Text(units.formatTime(_filledAt)),
            onTap: _pickTime,
          ),
          if (partner != null)
            SwitchListTile(
              key: const Key('log-fill-twin'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.passport_logFill_twinSwitch(
                  isPartnerOutOfUse(partner.effectiveStatus)
                      ? l10n.twinSet_partnerStatus(
                          partner.name,
                          partner.effectiveStatus.localizedName(l10n),
                        )
                      : partner.name,
                ),
              ),
              value: _twinOn(partner),
              onChanged: (on) => setState(() {
                _twinChoice = on;
                _twinChoicePartnerId = partner.id;
              }),
            ),
          Row(
            // Top-aligned, so the He field stays level with O2 when O2
            // carries the analysed-values hint.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('logFill_o2'),
                  controller: _o2,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.passport_logFill_o2,
                    helperText: widget.mixFromPlan
                        ? l10n.passport_logFill_analysedHint
                        : null,
                    helperMaxLines: 2,
                    errorText: _mixError,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('logFill_he'),
                  controller: _he,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.passport_logFill_he,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('logFill_pressure'),
                  controller: _pressure,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.passport_logFill_pressure,
                    suffixText: units.pressureSymbol,
                    errorText: _pressureError,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('logFill_temperature'),
                  controller: _temperature,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.passport_logFill_temperature,
                    suffixText: units.temperatureSymbol,
                    errorText: _temperatureError,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SuggestingField(
            controller: _station,
            focusNode: _stationFocus,
            label: l10n.passport_logFill_station,
            suggestions: _recentStations,
          ),
          const SizedBox(height: 12),
          _SuggestingField(
            controller: _analyzer,
            focusNode: _analyzerFocus,
            label: l10n.passport_logFill_analyzer,
            suggestions: _recentAnalyzers,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: InputDecoration(labelText: l10n.passport_logFill_notes),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                child: Text(l10n.forms_cancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(l10n.forms_save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A text field that offers [suggestions] containing what has been typed,
/// case-insensitively, most recent first.
class _SuggestingField extends StatelessWidget {
  const _SuggestingField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.suggestions,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final List<String> suggestions;

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (value) {
        final typed = value.text.trim().toLowerCase();
        if (typed.isEmpty) return const [];
        return suggestions.where(
          (s) => s.toLowerCase().contains(typed) && s.toLowerCase() != typed,
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
          TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(labelText: label),
            onSubmitted: (_) => onSubmitted(),
          ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: AlignmentDirectional.topStart,
        child: Material(
          elevation: 4,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 320),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final option in options)
                  ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () => onSelected(option),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
