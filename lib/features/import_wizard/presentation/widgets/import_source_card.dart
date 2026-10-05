import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/byte_format.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The text an [ImportSourceCard] shows: a name, then up to two detail
/// lines. The first line says what the source is (model, format, date
/// range, account); the second carries its specifics (serial, firmware,
/// connection, size, devices).
typedef ImportSourceLines = ({String title, List<String> details});

/// Builds the lines for [source], leaving out every field that is absent
/// or blank (issue #161).
@visibleForTesting
ImportSourceLines importSourceLines(
  ImportSourceInfo source, {
  required AppLocalizations l10n,
  required UnitFormatter units,
}) {
  final d = source.details;
  final fileCount = d.fileCount ?? 0;
  final title =
      _text(d.title) ??
      (fileCount > 1 ? l10n.importWizard_source_fileCount(fileCount) : null) ??
      source.displayName;

  final model = _text(d.model);
  final formats = d.formats.map(_text).nonNulls.toList();
  final app = _text(d.sourceApp);
  // A format named after its app ("Subsurface XML") already says where the
  // file came from.
  final appIsNamed =
      app != null &&
      formats.any((f) => f.toLowerCase().startsWith(app.toLowerCase()));
  final serial = _text(d.serialNumber);
  final firmware = _text(d.firmwareVersion);
  final devices = d.deviceModels.map(_text).nonNulls.toList();

  final identity = [
    if (model != null && model != title) model,
    if (formats.isNotEmpty) formats.join(', '),
    if (app != null && !appIsNamed) l10n.importWizard_source_fromApp(app),
    if (d.rangeStart != null || d.rangeEnd != null)
      units.formatDateRange(d.rangeStart, d.rangeEnd, l10n: l10n),
    ?_text(d.account),
  ];
  final specifics = [
    if (serial != null) l10n.equipment_rowLabel_serial(serial),
    if (firmware != null) l10n.importWizard_source_firmware(firmware),
    if (d.connection case final connection?) _connectionLabel(l10n, connection),
    if (d.sizeBytes case final size?) formatBytes(size),
    if (devices.isNotEmpty) devices.join(', '),
  ];
  return (
    title: title,
    details: [
      for (final parts in [identity, specifics])
        if (parts.isNotEmpty) parts.join(' · '),
    ],
  );
}

String? _text(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

String _connectionLabel(AppLocalizations l10n, DeviceConnectionType type) =>
    switch (type) {
      DeviceConnectionType.ble => l10n.diveComputer_connectionType_ble,
      DeviceConnectionType.bluetoothClassic =>
        l10n.diveComputer_connectionType_bluetooth,
      DeviceConnectionType.usb => l10n.diveComputer_connectionType_usb,
      DeviceConnectionType.infrared =>
        l10n.diveComputer_connectionType_infrared,
    };

/// Tells the diver where the import on the Review step came from: which
/// dive computer, which file, or which service (issue #161).
class ImportSourceCard extends ConsumerWidget {
  final ImportSourceInfo source;

  const ImportSourceCard({super.key, required this.source});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lines = importSourceLines(
      source,
      l10n: context.l10n,
      units: UnitFormatter(ref.watch(settingsProvider)),
    );

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      color: colorScheme.surfaceContainerHigh,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(_icon, size: 24, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lines.title,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  for (final line in lines.details)
                    Text(
                      line,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon => switch (source.type) {
    ImportSourceType.diveComputer => switch (source.details.connection) {
      DeviceConnectionType.ble ||
      DeviceConnectionType.bluetoothClassic => Icons.bluetooth,
      DeviceConnectionType.usb => Icons.usb,
      _ => Icons.watch_outlined,
    },
    ImportSourceType.healthKit => Icons.favorite_outline,
    ImportSourceType.suuntoCloud ||
    ImportSourceType.garminCloud ||
    ImportSourceType.divelogs => Icons.cloud_download_outlined,
    ImportSourceType.uddf ||
    ImportSourceType.fit ||
    ImportSourceType.universal ||
    ImportSourceType.suuntoFile =>
      (source.details.fileCount ?? 0) > 1
          ? Icons.folder_copy_outlined
          : Icons.insert_drive_file_outlined,
  };
}
