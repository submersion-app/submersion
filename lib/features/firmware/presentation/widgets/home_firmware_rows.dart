import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dashboard/presentation/widgets/home_charts.dart';
import 'package:submersion/features/firmware/presentation/providers/firmware_status_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Firmware updates in the home dashboard's gear service panel (issue
/// #5104): up to [limit] rows, each opening its item, then a count of the
/// rest.
class HomeFirmwareRows extends StatelessWidget {
  const HomeFirmwareRows({
    super.key,
    required this.updates,
    required this.limit,
  });

  final List<FirmwareUpdateEntry> updates;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shown = updates.take(limit < 0 ? 0 : limit).toList();
    final rest = updates.length - shown.length;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final u in shown)
          InkWell(
            key: ValueKey('home-firmware-${u.item.id}'),
            onTap: () => context.push('/equipment/${u.item.id}'),
            child: HomeBarRow(
              label: u.item.name,
              value: l10n.firmware_home_version(u.status.latest.version),
              fraction: null,
            ),
          ),
        if (rest > 0)
          Text(
            l10n.firmware_home_more(rest),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
