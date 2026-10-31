import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/reports/service_report.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/transfer/presentation/widgets/report_sheet_scaffold.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The short options sheet before the service report exports: which gear,
/// and whether its history and costs print.
class ServiceReportSheet extends ConsumerStatefulWidget {
  const ServiceReportSheet({super.key});

  /// Finds the gear dropdown in tests.
  @visibleForTesting
  static const gearKey = ValueKey('serviceReport.gear');

  /// Finds the trip dropdown in tests.
  @visibleForTesting
  static const tripKey = ValueKey('serviceReport.trip');

  /// Finds the item dropdown in tests.
  @visibleForTesting
  static const itemKey = ValueKey('serviceReport.item');

  /// Finds the history switch in tests.
  @visibleForTesting
  static const historyKey = ValueKey('serviceReport.history');

  /// Finds the costs switch in tests.
  @visibleForTesting
  static const costsKey = ValueKey('serviceReport.costs');

  /// Shows the sheet and returns the options, or null if dismissed.
  static Future<ServiceReportOptions?> show(BuildContext context) =>
      showModalBottomSheet<ServiceReportOptions>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const ServiceReportSheet(),
      );

  @override
  ConsumerState<ServiceReportSheet> createState() => _ServiceReportSheetState();
}

class _ServiceReportSheetState extends ConsumerState<ServiceReportSheet> {
  ServiceReportScope _scope = ServiceReportScope.all;
  String? _tripId;
  String? _itemId;
  bool _includeHistory = true;
  bool _showCosts = true;

  bool get _isComplete => switch (_scope) {
    ServiceReportScope.all => true,
    ServiceReportScope.trip => _tripId != null,
    ServiceReportScope.item => _itemId != null,
  };

  String _scopeLabel(AppLocalizations l10n, ServiceReportScope scope) =>
      switch (scope) {
        ServiceReportScope.all => l10n.equipmentReport_sheet_gearAll,
        ServiceReportScope.trip => l10n.equipmentReport_sheet_gearTrip,
        ServiceReportScope.item => l10n.equipmentReport_sheet_gearItem,
      };

  /// Newest first: the trip being packed for is usually the latest one.
  List<Trip> _trips() =>
      [...?ref.watch(allTripsProvider).value]
        ..sort((a, b) => b.startDate.compareTo(a.startDate));

  /// Everything but wishlist gear: selling a retired regulator is a main
  /// reason to print its history.
  List<EquipmentItem> _items() => [
    for (final item in ref.watch(allEquipmentProvider).value ?? const [])
      if (!item.isWanted) item,
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  void _finish() => Navigator.of(context).pop(
    ServiceReportOptions(
      scope: _scope,
      tripId: _scope == ServiceReportScope.trip ? _tripId : null,
      itemId: _scope == ServiceReportScope.item ? _itemId : null,
      includeHistory: _includeHistory,
      showCosts: _showCosts,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ReportSheetScaffold(
      title: l10n.transfer_export_serviceReportTitle,
      onContinue: _isComplete ? _finish : null,
      children: [
        ReportSheetDropdown<ServiceReportScope>(
          key: ServiceReportSheet.gearKey,
          label: l10n.equipmentReport_sheet_gear,
          value: _scope,
          options: [
            for (final scope in ServiceReportScope.values)
              (scope, _scopeLabel(l10n, scope)),
          ],
          onChanged: (scope) {
            if (scope != null) setState(() => _scope = scope);
          },
        ),
        if (_scope == ServiceReportScope.trip)
          ReportSheetDropdown<String>(
            key: ServiceReportSheet.tripKey,
            label: l10n.equipmentReport_sheet_trip,
            value: _tripId,
            options: [for (final trip in _trips()) (trip.id, trip.name)],
            onChanged: (id) => setState(() => _tripId = id),
          ),
        if (_scope == ServiceReportScope.item)
          ReportSheetDropdown<String>(
            key: ServiceReportSheet.itemKey,
            label: l10n.equipmentReport_sheet_item,
            value: _itemId,
            options: [for (final item in _items()) (item.id, item.name)],
            onChanged: (id) => setState(() => _itemId = id),
          ),
        SwitchListTile(
          key: ServiceReportSheet.historyKey,
          title: Text(l10n.equipmentReport_sheet_history),
          value: _includeHistory,
          onChanged: (value) => setState(() => _includeHistory = value),
          contentPadding: EdgeInsets.zero,
        ),
        // Costs only print in the history, so with it off this has no effect.
        SwitchListTile(
          key: ServiceReportSheet.costsKey,
          title: Text(l10n.equipmentReport_sheet_showCosts),
          value: _showCosts,
          onChanged: _includeHistory
              ? (value) => setState(() => _showCosts = value)
              : null,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}
