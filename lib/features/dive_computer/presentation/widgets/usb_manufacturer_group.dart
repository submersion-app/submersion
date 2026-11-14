import 'package:flutter/material.dart';

import 'package:submersion/features/dive_computer/domain/entities/device_model.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/collapsible_group_header.dart';

/// One manufacturer in the USB list of Connect New Computer: a foldable
/// heading with the brand and its model count, like the Equipment list's
/// groups, and the brand's models below it while open (issue #4480).
class UsbManufacturerGroup extends StatelessWidget {
  const UsbManufacturerGroup({
    super.key,
    required this.manufacturer,
    required this.models,
    required this.isExpanded,
    required this.onToggle,
    required this.onModelSelected,
  });

  final String manufacturer;
  final List<DeviceModel> models;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ValueChanged<DeviceModel> onModelSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CollapsibleGroupHeader(
          label: manufacturer,
          countLabel: context.l10n.diveComputer_discovery_usbModelCount(
            models.length,
          ),
          isExpanded: isExpanded,
          onTap: onToggle,
          isHeading: true,
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final model in models)
                  _UsbDeviceListTile(
                    model: model,
                    onTap: () => onModelSelected(model),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// List tile for a USB device model.
class _UsbDeviceListTile extends StatelessWidget {
  final DeviceModel model;
  final VoidCallback onTap;

  const _UsbDeviceListTile({required this.model, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        label: context.l10n.diveComputer_scan_usbSemanticLabel(model.model),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                ExcludeSemantics(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.usb,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(model.model, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.diveComputer_scan_usbCableLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Chevron
                ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
