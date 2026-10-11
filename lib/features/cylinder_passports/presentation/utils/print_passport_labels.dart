import 'package:flutter/material.dart';

import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/pdf/passport_label_pdf_export_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_payload_codec.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_tag_card.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_codec.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_fit.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_rules.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Hands finished labels on: the PDF share sheet in the app, a capture in
/// tests. [origin] anchors the share popover on iPad and macOS, and
/// [localization] is the app language the label text was written in, which
/// picks the fonts and text direction (#2252).
typedef PassportLabelExport =
    Future<void> Function(
      List<PassportLabelData> labels,
      Rect? origin,
      PdfLocalization localization,
    );

Future<void> _shareLabelPdf(
  List<PassportLabelData> labels,
  Rect? origin,
  PdfLocalization localization,
) => PassportLabelPdfExportService().exportToPdf(
  labels,
  sharePositionOrigin: origin,
  localization: localization,
);

/// Builds one label per selected item not on the wishlist, in selection
/// order: the cylinder label for a tank, the gear label for anything else
/// (issue #2652). Mints passport ids where missing and passes the labels to
/// [export], the PDF share sheet by default. Exports nothing when no item
/// qualifies.
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
  final items = [
    for (final id in equipmentIds)
      if (byId[id] case final item? when !item.isWanted) item,
  ];
  if (items.isEmpty || !context.mounted) return;
  final recordsById = await ref
      .read(serviceRecordRepositoryProvider)
      .getRecordsForEquipmentIds([for (final i in items) i.id]);
  final tankIds = [
    for (final i in items)
      if (i.type == EquipmentType.tank) i.id,
  ];
  if (!context.mounted) return;
  final clocksById = Map.fromIterables(
    tankIds,
    await Future.wait([
      for (final id in tankIds)
        ref.read(serviceClockStatusesProvider(id).future),
    ]),
  );

  final labels = <PassportLabelData>[];
  for (final item in items) {
    final stored = item.attrText(EquipmentAttrKeys.passportId);
    final passportId = stored != null && stored.trim().isNotEmpty
        ? stored.trim()
        : await passportRepo.ensurePassportId(item.id, diverId: diverId);
    if (item.type != EquipmentType.tank) {
      labels.add(
        _gearLabel(
          l10n,
          item,
          GearTagFit.fitForLabel(
            gearPayloadForItem(
              item: item,
              passportId: passportId,
              now: now,
              lastService: lastServiceDate(recordsById[item.id] ?? const []),
            ),
          ),
        ),
      );
      continue;
    }
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
          if (item.volumeL != null)
            units.formatTankVolume(item.volumeL, item.workingPressureBar),
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
    PdfLocalization.forLanguageCode(l10n.localeName),
  );
}

/// A gear label (gear tag spec 11): the name, brand and model, the type and
/// serial, and the gear link.
PassportLabelData _gearLabel(
  AppLocalizations l10n,
  EquipmentItem item,
  GearTagPayload payload,
) => PassportLabelData(
  title: item.name,
  subtitle: [
    if (item.brand?.trim().isNotEmpty ?? false) item.brand!.trim(),
    if (item.model?.trim().isNotEmpty ?? false) item.model!.trim(),
  ].join(' '),
  specLine: [
    item.type.localizedName(l10n),
    if (item.serialNumber?.trim().isNotEmpty ?? false)
      item.serialNumber!.trim(),
  ].join(', '),
  url: GearTagCodec.httpsUrl(payload),
);
