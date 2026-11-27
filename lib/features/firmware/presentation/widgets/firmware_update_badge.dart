import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/firmware/domain/firmware_status.dart';
import 'package:submersion/features/firmware/presentation/providers/firmware_status_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Whether the equipment list should flag [itemId] (issue #5104).
bool hasFirmwareUpdate(WidgetRef ref, String itemId) =>
    ref.watch(firmwareStatusProvider(itemId)) is FirmwareUpdateAvailable;

/// The equipment list's one-line "Update available" flag for gear whose
/// firmware catalogue lists a newer release.
class FirmwareUpdateBadge extends StatelessWidget {
  const FirmwareUpdateBadge({super.key, this.textAlign});

  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      context.l10n.firmware_badge_updateAvailable,
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.tertiary,
        fontWeight: FontWeight.w600,
      ),
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
