import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/pdf/passport_label_pdf_export_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_tag_card.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Hands finished labels on: the PDF share sheet in the app, a capture in
/// tests. [origin] anchors the share popover on iPad and macOS.
typedef PassportLabelExport =
    Future<void> Function(List<PassportLabelData> labels, Rect? origin);

Future<void> _shareLabelPdf(List<PassportLabelData> labels, Rect? origin) =>
    PassportLabelPdfExportService().exportToPdf(
      labels,
      sharePositionOrigin: origin,
    );

/// Builds one label per cylinder among [equipmentIds] (other types are
/// skipped), minting passport ids where missing, and passes them to
/// [export], the PDF share sheet by default. Exports nothing when no
/// cylinder was selected.
Future<void> printPassportLabels(
  BuildContext context,
  WidgetRef ref,
  List<String> equipmentIds, {
  PassportLabelExport export = _shareLabelPdf,
}) async {
  final l10n = context.l10n;
  final units = UnitFormatter(ref.read(settingsProvider));
  final equipmentRepo = ref.read(equipmentRepositoryProvider);
  final passportRepo = ref.read(cylinderPassportRepositoryProvider);
  final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
  final now = DateTime.now();
  final labels = <PassportLabelData>[];
  for (final id in equipmentIds) {
    final item = await equipmentRepo.getEquipmentById(id);
    if (item == null || item.type != EquipmentType.tank) continue;
    final passportId = await passportRepo.ensurePassportId(
      id,
      diverId: diverId,
    );
    final clocks = await ref.read(serviceClockStatusesProvider(id).future);
    final records = await ref.read(
      serviceRecordsForEquipmentProvider(id).future,
    );
    final payload = currentPayloadFor(
      item,
      passportId: passportId,
      clocks: clocks,
      records: records,
      now: now,
    );
    if (payload == null) continue;
    final material = item.attrText(EquipmentAttrKeys.tankMaterial);
    labels.add(
      PassportLabelData(
        title: item.name,
        subtitle: [
          if (item.identifier != null) item.identifier!,
          if (item.serialNumber?.isNotEmpty ?? false) item.serialNumber!,
        ].join(' '),
        specLine: [
          if (item.volumeL != null) units.formatVolume(item.volumeL),
          if (item.workingPressureBar != null)
            units.formatPressure(item.workingPressureBar),
          if (material != null)
            attributeChoiceLabel(
              l10n,
              EquipmentAttrKeys.tankMaterial,
              material,
            ),
        ].join(', '),
        url: PassportPayloadCodec.httpsUrl(payload),
      ),
    );
  }
  if (labels.isEmpty || !context.mounted) return;
  final box = context.findRenderObject() as RenderBox?;
  await export(
    labels,
    box == null ? null : box.localToGlobal(Offset.zero) & box.size,
  );
}
