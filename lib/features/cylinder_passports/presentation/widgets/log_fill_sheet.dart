import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A number typed by a diver: a decimal comma is a decimal point, blanks and
/// letters are not numbers.
double? parseDecimal(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

/// Opens the manual fill sheet. Resolves with the saved fill, or null when
/// the diver backed out.
Future<CylinderFill?> showLogFillSheet(
  BuildContext context, {
  required String passportId,
  required String equipmentId,
}) => showModalBottomSheet<CylinderFill>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: LogFillSheet(passportId: passportId, equipmentId: equipmentId),
  ),
);

class LogFillSheet extends ConsumerStatefulWidget {
  const LogFillSheet({
    super.key,
    required this.passportId,
    required this.equipmentId,
  });

  final String passportId;
  final String equipmentId;

  @override
  ConsumerState<LogFillSheet> createState() => _LogFillSheetState();
}

class _LogFillSheetState extends ConsumerState<LogFillSheet> {
  DateTime _filledAt = DateTime.now();
  final _o2 = TextEditingController(text: '21');
  final _he = TextEditingController(text: '0');
  final _pressure = TextEditingController();
  final _temperature = TextEditingController();
  final _station = TextEditingController();
  final _analyzer = TextEditingController();
  final _notes = TextEditingController();
  String? _mixError;
  String? _pressureError;
  String? _temperatureError;
  bool _saving = false;

  @override
  void dispose() {
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
    final picked = await showDatePicker(
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
        o2 == null ||
        he == null ||
        o2 < 0 ||
        o2 > 100 ||
        he < 0 ||
        he > 100 ||
        o2 + he > 100;
    setState(() {
      _mixError = mixInvalid ? l10n.passport_logFill_invalidMix : null;
      _pressureError = pressureText.isNotEmpty && pressure == null
          ? l10n.passport_logFill_invalidNumber
          : null;
      _temperatureError = temperatureText.isNotEmpty && temperature == null
          ? l10n.passport_logFill_invalidNumber
          : null;
    });
    if (_mixError != null ||
        _pressureError != null ||
        _temperatureError != null) {
      return;
    }

    setState(() => _saving = true);
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
      pressureBar: pressure == null ? null : units.pressureToBar(pressure),
      temperatureC: temperature == null
          ? null
          : units.temperatureToCelsius(temperature),
      analyzer: _analyzer.text.trim().isEmpty ? null : _analyzer.text.trim(),
      stationName: _station.text.trim().isEmpty ? null : _station.text.trim(),
      source: FillSource.manual,
      notes: _notes.text.trim(),
      createdAt: now,
      updatedAt: now,
    );
    final saved = await ref.read(cylinderFillRepositoryProvider).create(fill);
    if (!mounted) return;
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.passport_fill_log,
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
          Row(
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
          TextField(
            controller: _station,
            decoration: InputDecoration(
              labelText: l10n.passport_logFill_station,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _analyzer,
            decoration: InputDecoration(
              labelText: l10n.passport_logFill_analyzer,
            ),
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
