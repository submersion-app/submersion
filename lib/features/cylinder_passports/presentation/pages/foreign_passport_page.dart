import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_passport_payload.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_attribute_keys.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where a scanned tag the diver does not hold opens. The tag rides in the
/// query so the page survives a restart; its payload is public by design.
String foreignPassportLocation(CylinderPassportPayload tag) => Uri(
  path: '/equipment/tag',
  queryParameters: {'t': PassportPayloadCodec.httpsUrl(tag)},
).toString();

/// The tag a foreign passport route carried, or null when it is not one.
CylinderPassportPayload? foreignTagFromQuery(String? t) {
  if (t == null) return null;
  final decoded = PassportPayloadCodec.decode(t);
  return decoded is PassportDecoded ? decoded.payload : null;
}

/// A read-only passport built from a tag alone (spec section 9): what the
/// label said when it was written, for a cylinder that is not the diver's.
class ForeignPassportPage extends ConsumerStatefulWidget {
  const ForeignPassportPage({super.key, required this.tag});

  final CylinderPassportPayload? tag;

  @override
  ConsumerState<ForeignPassportPage> createState() =>
      _ForeignPassportPageState();
}

class _ForeignPassportPageState extends ConsumerState<ForeignPassportPage> {
  /// The page's actions (Use on a dive, Add to my gear).
  List<Widget> _actions(CylinderPassportPayload tag) => const [];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tag = widget.tag;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.passport_foreign_title)),
      body: tag == null
          ? Center(child: Text(l10n.passport_tag_linkInvalid))
          : _body(context, tag),
    );
  }

  Widget _body(BuildContext context, CylinderPassportPayload tag) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final rows = <(String, String)>[
      if (tag.volumeL != null)
        (
          attributeLabel(l10n, EquipmentAttrKeys.volumeL),
          units.formatVolume(tag.volumeL),
        ),
      if (tag.workingPressureBar != null)
        (
          attributeLabel(l10n, EquipmentAttrKeys.workingPressureBar),
          units.formatPressure(tag.workingPressureBar!.toDouble()),
        ),
      if (tag.material case final m?)
        (
          attributeLabel(l10n, EquipmentAttrKeys.tankMaterial),
          attributeChoiceLabel(
            l10n,
            EquipmentAttrKeys.tankMaterial,
            tankMaterialChoiceKey(m),
          ),
        ),
      if (tag.valve case final v?)
        (
          attributeLabel(l10n, 'valve_type'),
          attributeChoiceLabel(l10n, 'valve_type', valveChoiceKey(v)),
        ),
      if (tag.lastHydro case final d?)
        (attributeLabel(l10n, 'last_hydro_test'), units.formatDate(d)),
      if (tag.lastVip case final d?)
        (attributeLabel(l10n, 'last_visual_inspection'), units.formatDate(d)),
    ];
    final hasDetails = rows.isNotEmpty || tag.name != null || tag.o2Clean;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          tag.name ?? l10n.passport_foreign_defaultName,
          style: theme.textTheme.headlineMedium,
        ),
        if (tag.serial case final serial?)
          Text(l10n.passport_foreign_serial(serial)),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.passport_foreign_notInGear),
          ),
        ),
        if (tag.formatVersion > CylinderPassportPayload.currentFormatVersion)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.passport_scan_newerFormat),
          ),
        if (tag.writtenOn case final written?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.passport_foreign_writtenOn(units.formatDate(written)),
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(label)),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        if (tag.o2Clean)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(l10n.passport_foreign_o2Clean),
          ),
        if (!hasDetails)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.passport_foreign_noDetails),
          ),
        const SizedBox(height: 24),
        ..._actions(tag),
      ],
    );
  }
}
