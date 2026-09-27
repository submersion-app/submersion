import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_event.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_adjust_sheet.dart';
import 'package:submersion/features/trips/presentation/widgets/cylinders/trip_cylinder_fill_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Every fill and adjustment on the trip, newest first. Tapping one opens
/// it for editing; the bin deletes it after a confirmation.
class TripCylinderLedgerView extends ConsumerWidget {
  final String tripId;
  final List<TripCylinderState> states;
  final Map<String, String> centerNames;

  const TripCylinderLedgerView({
    super.key,
    required this.tripId,
    required this.states,
    required this.centerNames,
  });

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    TripCylinderEvent event,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.trips_cylinders_deleteEventConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      // A deleted fill takes its passport copy with it (Task 6). The copy
      // goes first: if that fails nothing is deleted and the diver can try
      // again, where the other order would strand the copy with no fill.
      if (event.kind == TripCylinderEventKind.fill) {
        await ref.read(tripFillPassportCopierProvider).afterDelete(event.id);
      }
      await ref.read(tripCylinderRepositoryProvider).deleteEvent(event.id);
    } catch (_) {
      if (context.mounted) showTripCylinderChangeFailed(context);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final fallbackCurrency = ref.watch(defaultCurrencyProvider);
    final async = ref.watch(tripCylinderLedgerProvider(tripId));
    final events = async.value;
    // Not loaded yet, or failed: neither is an empty ledger.
    if (events == null) {
      return Center(
        child: async.hasError
            ? Text(l10n.common_label_error)
            : const CircularProgressIndicator(),
      );
    }
    if (events.isEmpty) {
      return Center(child: Text(l10n.trips_cylinders_ledgerEmpty));
    }
    final byId = {for (final s in states) s.cylinder.id: s};
    return ListView.separated(
      itemCount: events.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = events[i];
        final slot = byId[e.tripCylinderId];
        final isFill = e.kind == TripCylinderEventKind.fill;
        final kind = isFill
            ? l10n.trips_cylinders_kind_fill
            : l10n.trips_cylinders_kind_adjustment;
        final when = units.formatDateTime(e.occurredAt, l10n: l10n);
        final mix = e.effectiveMix;
        final details = [
          if (mix != null) tripCylinderMixLabel(l10n, mix),
          if (e.pressure != null) units.formatPressure(e.pressure),
          if (e.bottleLabel case final bottle?)
            l10n.trips_cylinders_bottle(bottle),
          ?centerNames[e.diveCenterId],
          if (e.cost case final cost?)
            formatMoney(cost, e.currency ?? fallbackCurrency),
          if (e.isPackage) l10n.trips_cylinders_fill_package,
        ].join(' · ');
        return ListTile(
          key: Key('ledger-${e.id}'),
          title: Text(slot?.cylinder.label ?? ''),
          subtitle: Text(
            details.isEmpty ? '$kind · $when' : '$kind · $when\n$details',
          ),
          isThreeLine: details.isNotEmpty,
          onTap: slot == null
              ? null
              : () => isFill
                    ? showTripCylinderFillSheet(
                        context,
                        slots: states,
                        editing: e,
                      )
                    : showTripCylinderAdjustSheet(
                        context,
                        cylinder: slot.cylinder,
                        editing: e,
                      ),
          trailing: IconButton(
            key: Key('ledger-delete-${e.id}'),
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.common_action_delete,
            onPressed: () => _confirmDelete(context, ref, e),
          ),
        );
      },
    );
  }
}
