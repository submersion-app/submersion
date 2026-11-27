import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/helpers/equipment_web_link_launcher.dart';
import 'package:submersion/features/firmware/domain/firmware_catalogue.dart';
import 'package:submersion/features/firmware/domain/firmware_status.dart';
import 'package:submersion/features/firmware/presentation/providers/firmware_status_providers.dart';
import 'package:submersion/features/firmware/presentation/widgets/log_firmware_update_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// How many newer releases show before "Show all".
const int _shownReleases = 3;

/// The Firmware card of an electronic item's page (issue #5104): the
/// version it runs, what the firmware catalogue says about it, the maker's
/// links, and a way to log an update.
class FirmwareCard extends ConsumerStatefulWidget {
  const FirmwareCard({super.key, required this.item});

  final EquipmentItem item;

  @override
  ConsumerState<FirmwareCard> createState() => _FirmwareCardState();
}

class _FirmwareCardState extends ConsumerState<FirmwareCard> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final status = ref.watch(firmwareStatusProvider(item.id));
    final registrations = item.type == EquipmentType.computer
        ? ref.watch(computersForEquipmentProvider(item.id)).value ?? const []
        : const <Never>[];
    final installed = installedFirmwareOf(item, registrations);
    final model = status is FirmwareListedStatus ? status.model : null;
    // The page the diver saved wins over the catalogue's.
    final pageLink =
        parseWebLink(item.firmwarePageUrl) ??
        parseWebLink(model?.firmwarePageUrl);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.firmware_card_title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _labelled(
              context,
              l10n.firmware_card_installed,
              installed ?? l10n.firmware_card_notRecorded,
            ),
            ..._statusLines(context, status),
            if (pageLink != null) ...[
              const SizedBox(height: 4),
              _link(context, l10n.attrLabel_firmware_page_url, pageLink),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                key: const ValueKey('firmware-log-update'),
                icon: const Icon(Icons.system_update_alt),
                label: Text(l10n.firmware_card_log),
                onPressed: () => showLogFirmwareUpdateDialog(
                  context,
                  item: item,
                  suggestedVersion: status is FirmwareUpdateAvailable
                      ? status.latest.version
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _statusLines(BuildContext context, FirmwareStatus? status) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    Widget line(String text, {Color? color, IconData? icon}) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
    return switch (status) {
      null || FirmwareNotListed() => const [],
      FirmwareUpToDate() => [
        line(
          l10n.firmware_card_upToDate,
          icon: Icons.check_circle_outline,
          color: theme.colorScheme.primary,
        ),
      ],
      FirmwareUnknownVersion(:final latest) => [
        line(l10n.firmware_card_unknownVersion(latest.version)),
      ],
      FirmwareNoVersion(:final latest) => [
        line(l10n.firmware_card_noVersion(latest.version)),
      ],
      FirmwareUpdateAvailable(:final latest, :final newer) => [
        line(
          l10n.firmware_card_updateAvailable(latest.version),
          icon: Icons.system_update_alt,
          color: theme.colorScheme.tertiary,
        ),
        for (final release in _showAll ? newer : newer.take(_shownReleases))
          _ReleaseTile(release: release),
        if (newer.length > _shownReleases)
          TextButton(
            onPressed: () => setState(() => _showAll = !_showAll),
            child: Text(
              _showAll
                  ? l10n.firmware_card_showFewer
                  : l10n.firmware_card_showAll(newer.length),
            ),
          ),
      ],
    };
  }

  Widget _labelled(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  Widget _link(BuildContext context, String label, Uri uri) =>
      FirmwareLink(label: label, uri: uri);
}

/// One newer release: version, date, a safety marker, the maker's summary
/// and its links.
class _ReleaseTile extends ConsumerWidget {
  const _ReleaseTile({required this.release});

  final FirmwareRelease release;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final notes = parseWebLink(release.notesUrl);
    final howTo = parseWebLink(release.instructionsUrl);
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(release.version, style: theme.textTheme.titleSmall),
              if (release.date case final date?)
                Text(
                  units.formatDate(date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (release.safety)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l10n.firmware_card_safety,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
            ],
          ),
          if (release.summary case final summary?)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(summary, style: theme.textTheme.bodySmall),
            ),
          if (notes != null || howTo != null)
            Wrap(
              spacing: 16,
              children: [
                if (notes != null)
                  FirmwareLink(
                    label: l10n.firmware_card_releaseNotes,
                    uri: notes,
                  ),
                if (howTo != null)
                  FirmwareLink(
                    label: l10n.firmware_card_howToUpdate,
                    uri: howTo,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A maker link, opened in the browser (falling back to a copy offer).
class FirmwareLink extends ConsumerWidget {
  const FirmwareLink({super.key, required this.label, required this.uri});

  final String label;
  final Uri uri;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton.icon(
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    ),
    icon: const Icon(Icons.open_in_new, size: 16),
    label: Text(label),
    onPressed: () => launchEquipmentWebLink(
      context,
      uri,
      launch: ref.read(equipmentWebLinkLaunchProvider),
    ),
  );
}
