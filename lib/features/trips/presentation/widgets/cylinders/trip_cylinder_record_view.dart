import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/features/trips/presentation/providers/trip_gas_record_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_gas_record_export.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The board's Record segment: the totals, the gaps line, then one row per
/// dive tank breathed from a trip cylinder, in dive order.
class TripCylinderRecordView extends ConsumerWidget {
  const TripCylinderRecordView({
    super.key,
    required this.tripId,
    required this.tripName,
    required this.centerNames,
  });

  final String tripId;
  final String tripName;
  final Map<String, String> centerNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(tripGasRecordProvider(tripId));
    final record = async.value;
    if (record == null) {
      return Center(
        child: async.hasError
            ? Text(l10n.common_label_error)
            : const CircularProgressIndicator(),
      );
    }
    final units = UnitFormatter(ref.watch(settingsProvider));
    final header = <Widget>[
      _Totals(
        record: record,
        units: units,
        trailing: TripGasRecordExportButton(
          record: record,
          tripName: tripName,
          centerNames: centerNames,
        ),
      ),
      if (record.unlinked.isNotEmpty)
        ListTile(
          key: const Key('record-gaps'),
          leading: const Icon(Icons.link_off),
          title: Text(
            l10n.trips_cylinders_record_unlinked(record.unlinked.length),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showUnlinkedTanksSheet(
            context,
            record.unlinked,
            units: units,
            showDivers: record.multipleDivers,
          ),
        ),
      const Divider(height: 1),
      if (record.rows.isEmpty)
        Padding(
          key: const Key('record-empty'),
          padding: const EdgeInsets.all(24),
          child: Center(child: Text(l10n.trips_cylinders_recordEmpty)),
        ),
    ];
    // Rows build lazily: a shared liveaboard can log hundreds of tanks.
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: header.length + record.rows.length,
      itemBuilder: (_, i) {
        if (i < header.length) return header[i];
        final r = record.rows[i - header.length];
        return _RecordRow(
          row: r,
          units: units,
          centerName: centerNames[r.diveCenterId],
          showDiver: record.multipleDivers,
        );
      },
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({
    required this.record,
    required this.units,
    required this.trailing,
  });

  final TripGasRecord record;
  final UnitFormatter units;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cost = [
      for (final c in record.costs) formatMoney(c.value, c.key),
      if (record.packageFills > 0)
        l10n.trips_cylinders_record_packageFills(record.packageFills),
    ];
    return Padding(
      key: const Key('record-totals'),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.trips_cylinders_record_fillsLogged(record.fillsLogged),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              trailing,
            ],
          ),
          for (final s in record.slots)
            Text(
              [
                s.cylinder.label,
                l10n.trips_cylinders_linkedDives(s.dives),
                if (s.litres case final litres?)
                  units.formatVolume(litres)
                else if (s.dives > 0)
                  '--',
                if (s.leftOut > 0)
                  l10n.trips_cylinders_record_leftOut(s.leftOut),
              ].join(' · '),
              style: theme.textTheme.bodyMedium,
            ),
          if (cost.isNotEmpty)
            Text(
              '${l10n.trips_cylinders_fill_cost}: ${cost.join(' · ')}',
              style: theme.textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.row,
    required this.units,
    required this.centerName,
    required this.showDiver,
  });

  final TripGasRecordRow row;
  final UnitFormatter units;
  final String? centerName;
  final bool showDiver;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tank = row.tank;
    final title = [
      units.formatDateTime(tank.entryTime, l10n: l10n),
      ?tank.siteName,
      if (showDiver) ?tank.diverName,
    ].join(' · ');
    final slotLine = [
      tripCylinderTankLine(l10n, (
        label: row.cylinder.label,
        bottle: row.bottleLabel,
      )),
      if (row.orderedMix case final mix?) tripCylinderMixLabel(l10n, mix),
      if (row.analyzedMix case final mix?)
        l10n.trips_cylinders_record_analyzed(_percent(mix.o2, mix.he)),
    ].join(' · ');
    final gasLine = [
      if (row.fillPressure case final p?)
        l10n.trips_cylinders_record_filled(units.formatPressure(p)),
      ?centerName,
      '${units.formatPressure(tank.startPressure)} → '
          '${units.formatPressure(tank.endPressure)}',
      row.litres == null ? '--' : units.formatVolume(row.litres),
    ].join(' · ');
    return ListTile(
      key: Key('record-row-${tank.tankId}'),
      title: Text(title),
      subtitle: Text('$slotLine\n$gasLine'),
      isThreeLine: true,
    );
  }
}

/// "31.8%" or "18/45%" for an analyzed mix.
String _percent(double o2, double he) {
  String n(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return he > 0 ? '${n(o2)}/${n(he)}%' : '${n(o2)}%';
}

/// The dive tanks that breathe from no trip cylinder; each opens its
/// dive's editor (decided 2026-09-30: a list, not only the first).
Future<void> showUnlinkedTanksSheet(
  BuildContext context,
  List<TripUnlinkedTank> tanks, {
  required UnitFormatter units,
  required bool showDivers,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext);
      return DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.trips_cylinders_record_unlinkedTitle,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  for (final t in tanks)
                    ListTile(
                      key: Key('unlinked-${t.tankId}'),
                      title: Text(
                        [
                          units.formatDateTime(t.entryTime, l10n: l10n),
                          ?t.siteName,
                          if (showDivers) ?t.diverName,
                        ].join(' · '),
                      ),
                      subtitle: Text(
                        l10n.trips_cylinders_record_tank(t.tankOrder + 1),
                      ),
                      trailing: const Icon(Icons.edit),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        context.push('/dives/${t.diveId}/edit');
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
