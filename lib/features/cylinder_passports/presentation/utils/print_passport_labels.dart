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
  BuildContext? anchor,
  PassportLabelExport export = _shareLabelPdf,
}) async {
  final l10n = context.l10n;
  final units = UnitFormatter(ref.read(settingsProvider));
  final passportRepo = ref.read(cylinderPassportRepositoryProvider);
  final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
  // `ref` is unusable once the calling widget is gone; stop rather than throw.
  if (!context.mounted) return;
  final now = DateTime.now();

  // Batched: one read for the items and their attributes, one for every
  // service record, the clocks concurrently; ids are minted only for the
  // cylinders that have none yet.
  final byId = {
    for (final item
        in await ref
            .read(equipmentRepositoryProvider)
            .getEquipmentByIds(equipmentIds))
      item.id: item,
  };
  final tanks = [
    for (final id in equipmentIds)
      if (byId[id] case final item? when item.type == EquipmentType.tank) item,
  ];
  if (tanks.isEmpty || !context.mounted) return;
  final tankIds = [for (final t in tanks) t.id];
  final recordsById = await ref
      .read(serviceRecordRepositoryProvider)
      .getRecordsForEquipmentIds(tankIds);
  if (!context.mounted) return;
  final clocksById = Map.fromIterables(
    tankIds,
    await Future.wait([
      for (final id in tankIds)
        ref.read(serviceClockStatusesProvider(id).future),
    ]),
  );

  final labels = <PassportLabelData>[];
  for (final item in tanks) {
    final stored = item.attrText(EquipmentAttrKeys.passportId);
    final passportId = stored != null && stored.trim().isNotEmpty
        ? stored.trim()
        : await passportRepo.ensurePassportId(item.id, diverId: diverId);
    final payload = currentPayloadFor(
      item,
      passportId: passportId,
      clocks: clocksById[item.id] ?? const [],
      records: recordsById[item.id] ?? const [],
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
  // The share popover (iPad, macOS) points at [anchor], the control that
  // was tapped, when the caller gives one.
  final target = anchor != null && anchor.mounted ? anchor : context;
  final box = target.findRenderObject() as RenderBox?;
  await export(
    labels,
    box == null ? null : box.localToGlobal(Offset.zero) & box.size,
  );
}
