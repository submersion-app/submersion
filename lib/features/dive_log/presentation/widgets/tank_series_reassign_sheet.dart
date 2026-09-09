import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/data_quality/data/services/quality_repair_executor.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/reassign_tank_picker.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Lets the diver move a transmitter's pressure series to another cylinder
/// (issue #1314). Two tanks get a Swap; more get a per-row Move to. The
/// change is an exchange of the rows' computer bundles, so it survives
/// re-parse and is undone by the snackbar action.
Future<void> showTankSeriesReassignSheet(
  BuildContext context,
  WidgetRef ref, {
  required Dive dive,
  required Map<String, List<TankPressurePoint>> tankPressures,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _ReassignSheet(
      dive: dive,
      tankPressures: tankPressures,
      onExchange: (a, b) => _exchange(context, dive.id, a, b),
    ),
  );
}

Future<void> _exchange(
  BuildContext context,
  String diveId,
  String tankIdA,
  String tankIdB,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final result = await QualityRepairExecutor().exchangeTankSources(
      diveId: diveId,
      tankIdA: tankIdA,
      tankIdB: tankIdB,
    );
    final undo = result.undo;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.diveLog_reassignSheet_applied),
        action: undo == null
            ? null
            : SnackBarAction(
                label: l10n.dataQuality_action_undo,
                onPressed: () => unawaited(undo()),
              ),
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('${l10n.common_label_error}: $e')),
    );
  }
}

class _ReassignSheet extends ConsumerWidget {
  const _ReassignSheet({
    required this.dive,
    required this.tankPressures,
    required this.onExchange,
  });

  final Dive dive;
  final Map<String, List<TankPressurePoint>> tankPressures;
  final Future<void> Function(String tankIdA, String tankIdB) onExchange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final tanks = [...dive.tanks]..sort((a, b) => a.order.compareTo(b.order));
    final withSeries = tanks
        .where((t) => (tankPressures[t.id] ?? const []).isNotEmpty)
        .toList();
    final twoOnly = withSeries.length == 2 && tanks.length == 2;

    // A shrink-wrapped list: sized to its rows on a two-tank dive, scrolling
    // once a many-cylinder dive would overflow the sheet.
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            l10n.diveLog_reassignSheet_title,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final (index, tank) in tanks.indexed)
            _row(context, ref, l10n, units, index, tank, twoOnly),
          if (twoOnly) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.icon(
                icon: const Icon(Icons.swap_vert),
                label: Text(l10n.diveLog_reassignSheet_swap),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await onExchange(withSeries[0].id, withSeries[1].id);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    UnitFormatter units,
    int index,
    DiveTank tank,
    bool twoOnly,
  ) {
    final points = tankPressures[tank.id] ?? const <TankPressurePoint>[];
    final serial = normalizeTransmitterSerial(tank.transmitterSerial);
    final title = tank.name != null && tank.name!.isNotEmpty
        ? tank.name!
        : l10n.diveLog_tank_title(index + 1);
    final subtitle = points.isEmpty
        ? l10n.diveLog_reassignSheet_noSeries
        : '${units.formatPressure(points.first.pressure)} → '
              '${units.formatPressure(points.last.pressure)}, '
              '${l10n.diveLog_reassignSheet_readings(points.length)}'
              '${serial != null ? ', ${l10n.transmitters_serial(serial)}' : ''}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.show_chart),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: twoOnly || points.isEmpty
          ? null
          : TextButton(
              child: Text(l10n.diveLog_reassignSheet_moveTo),
              onPressed: () async {
                final target = await showReassignTankPicker(
                  context,
                  ref,
                  diveId: dive.id,
                  excludeTankId: tank.id,
                );
                if (target == null || !context.mounted) return;
                Navigator.of(context).pop();
                await onExchange(tank.id, target);
              },
            ),
    );
  }
}
