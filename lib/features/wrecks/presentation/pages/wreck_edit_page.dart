import 'package:flutter/material.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/wrecks/domain/entities/wreck.dart';
import 'package:submersion/features/wrecks/presentation/providers/wreck_providers.dart';
import 'package:submersion/features/wrecks/presentation/widgets/wreck_labels.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Create or edit one catalogue wreck. A null [wreckId] is the create
/// flow. Depths and length are typed in the diver's unit and stored in
/// meters.
class WreckEditPage extends ConsumerStatefulWidget {
  final String? wreckId;

  const WreckEditPage({super.key, this.wreckId});

  @override
  ConsumerState<WreckEditPage> createState() => _WreckEditPageState();
}

class _WreckEditPageState extends ConsumerState<WreckEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _deck = TextEditingController();
  final _seabed = TextEditingController();
  final _length = TextEditingController();
  final _yearBuilt = TextEditingController();
  final _yearSunk = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _notes = TextEditingController();

  String? _vesselType;
  String? _cause;
  String? _condition;
  String? _protection;
  String? _siteId;
  bool? _penetration;
  bool _loaded = false;
  Wreck? _existing;

  @override
  void dispose() {
    for (final c in [
      _name,
      _deck,
      _seabed,
      _length,
      _yearBuilt,
      _yearSunk,
      _latitude,
      _longitude,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Fills the form from the stored wreck exactly once, converting the
  /// stored meters into the diver's unit for display.
  void _hydrate(Wreck wreck, double unitInMeters) {
    if (_loaded) return;
    _loaded = true;
    _existing = wreck;
    _name.text = wreck.name;
    _deck.text = _display(wreck.depthToDeckMeters, unitInMeters);
    _seabed.text = _display(wreck.depthToSeabedMeters, unitInMeters);
    _length.text = _display(wreck.lengthMeters, unitInMeters);
    _yearBuilt.text = wreck.yearBuilt?.toString() ?? '';
    _yearSunk.text = wreck.yearSunk?.toString() ?? '';
    _latitude.text = wreck.latitude?.toString() ?? '';
    _longitude.text = wreck.longitude?.toString() ?? '';
    _notes.text = wreck.notes;
    _vesselType = wreck.vesselTypeName;
    _cause = wreck.causeName;
    _condition = wreck.conditionName;
    _protection = wreck.protectionName;
    _siteId = wreck.siteId;
    _penetration = wreck.penetrationPossible;
  }

  static String _display(double? meters, double unitInMeters) {
    if (meters == null) return '';
    final v = meters / unitInMeters;
    return v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }

  static double? _meters(String text, double unitInMeters) {
    final v = double.tryParse(text.trim().replaceAll(',', '.'));
    return v == null ? null : v * unitInMeters;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final depthUnit = ref.watch(settingsProvider.select((s) => s.depthUnit));
    final unitInMeters = depthUnit == DepthUnit.feet ? 0.3048 : 1.0;
    final symbol = depthUnit.symbol;

    if (widget.wreckId != null) {
      final stored = ref.watch(wreckProvider(widget.wreckId!)).valueOrNull;
      if (stored != null) _hydrate(stored, unitInMeters);
    }

    final sites = ref.watch(sitesProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.wreckId == null ? l10n.wrecks_add : l10n.wrecks_edit,
        ),
        actions: [
          IconButton(
            key: const ValueKey('wreckSaveButton'),
            icon: const Icon(Icons.check),
            tooltip: l10n.common_action_save,
            onPressed: () => _save(unitInMeters),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const ValueKey('wreckNameField'),
              controller: _name,
              decoration: InputDecoration(labelText: l10n.wrecks_field_name),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.wrecks_add : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const ValueKey('wreckVesselTypeField'),
              initialValue: _vesselType,
              decoration: InputDecoration(
                labelText: l10n.wrecks_field_vesselType,
              ),
              items: [
                for (final t in WreckVesselType.values)
                  DropdownMenuItem(
                    value: t.name,
                    child: Text(wreckVesselTypeLabel(l10n, t.name)),
                  ),
              ],
              onChanged: (v) => setState(() => _vesselType = v),
            ),
            const SizedBox(height: 12),
            _numberField(
              key: 'wreckDeckDepthField',
              controller: _deck,
              label: '${l10n.wrecks_field_depthToDeck} ($symbol)',
            ),
            const SizedBox(height: 12),
            _numberField(
              key: 'wreckSeabedDepthField',
              controller: _seabed,
              label: '${l10n.wrecks_field_depthToSeabed} ($symbol)',
            ),
            const SizedBox(height: 12),
            _numberField(
              key: 'wreckLengthField',
              controller: _length,
              label: '${l10n.wrecks_field_length} ($symbol)',
            ),
            const SizedBox(height: 12),
            _numberField(
              key: 'wreckYearBuiltField',
              controller: _yearBuilt,
              label: l10n.wrecks_field_yearBuilt,
            ),
            const SizedBox(height: 12),
            _numberField(
              key: 'wreckYearSunkField',
              controller: _yearSunk,
              label: l10n.wrecks_field_yearSunk,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const ValueKey('wreckCauseField'),
              initialValue: _cause,
              decoration: InputDecoration(labelText: l10n.wrecks_field_cause),
              items: [
                for (final c in WreckCause.values)
                  DropdownMenuItem(
                    value: c.name,
                    child: Text(wreckCauseLabel(l10n, c.name)),
                  ),
              ],
              onChanged: (v) => setState(() => _cause = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const ValueKey('wreckConditionField'),
              initialValue: _condition,
              decoration: InputDecoration(
                labelText: l10n.wrecks_field_condition,
              ),
              items: [
                for (final c in WreckCondition.values)
                  DropdownMenuItem(
                    value: c.name,
                    child: Text(wreckConditionLabel(l10n, c.name)),
                  ),
              ],
              onChanged: (v) => setState(() => _condition = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const ValueKey('wreckProtectionField'),
              initialValue: _protection,
              decoration: InputDecoration(
                labelText: l10n.wrecks_field_protection,
              ),
              items: [
                for (final p in WreckProtection.values)
                  DropdownMenuItem(
                    value: p.name,
                    child: Text(wreckProtectionLabel(l10n, p.name)),
                  ),
              ],
              onChanged: (v) => setState(() => _protection = v),
            ),
            const SizedBox(height: 12),
            // Tristate: null is "unknown", which is not the same as no.
            DropdownButtonFormField<bool?>(
              key: const ValueKey('wreckPenetrationField'),
              initialValue: _penetration,
              decoration: InputDecoration(
                labelText: l10n.wrecks_field_penetration,
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.wrecks_cause_unknown),
                ),
                DropdownMenuItem(
                  value: true,
                  child: Text(l10n.common_action_yes),
                ),
                DropdownMenuItem(
                  value: false,
                  child: Text(l10n.common_action_no),
                ),
              ],
              onChanged: (v) => setState(() => _penetration = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const ValueKey('wreckSiteField'),
              initialValue: _siteId,
              decoration: InputDecoration(labelText: l10n.wrecks_field_site),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.wrecks_linkNone),
                ),
                for (final s in sites)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _siteId = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _numberField(
                    key: 'wreckLatitudeField',
                    controller: _latitude,
                    label: 'Lat',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numberField(
                    key: 'wreckLongitudeField',
                    controller: _longitude,
                    label: 'Lon',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('wreckNotesField'),
              controller: _notes,
              maxLines: 4,
              decoration: InputDecoration(labelText: l10n.wrecks_field_notes),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField({
    required String key,
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      key: ValueKey(key),
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(labelText: label),
    );
  }

  Future<void> _save(double unitInMeters) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final lat = double.tryParse(_latitude.text.trim());
    final lon = double.tryParse(_longitude.text.trim());
    final draft = Wreck(
      id: widget.wreckId ?? '',
      name: _name.text.trim(),
      diverId: _existing?.diverId,
      siteId: _siteId,
      latitude: lat,
      longitude: lon,
      vesselTypeName: _vesselType,
      causeName: _cause,
      conditionName: _condition,
      protectionName: _protection,
      depthToDeckMeters: _meters(_deck.text, unitInMeters),
      depthToSeabedMeters: _meters(_seabed.text, unitInMeters),
      lengthMeters: _meters(_length.text, unitInMeters),
      yearBuilt: int.tryParse(_yearBuilt.text.trim()),
      yearSunk: int.tryParse(_yearSunk.text.trim()),
      penetrationPossible: _penetration,
      notes: _notes.text.trim(),
      isShared: _existing?.isShared ?? false,
    );

    final repository = ref.read(wreckRepositoryProvider);
    if (widget.wreckId == null) {
      await repository.createWreck(draft);
    } else {
      await repository.updateWreck(draft);
    }
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}
