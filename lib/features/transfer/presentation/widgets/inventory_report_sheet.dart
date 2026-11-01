import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/reports/inventory_report.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/transfer/presentation/widgets/report_sheet_scaffold.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The short options sheet before the inventory exports. One document then
/// serves insurance, customs and a single travel bag.
class InventoryReportSheet extends ConsumerStatefulWidget {
  const InventoryReportSheet({super.key});

  /// Finds the location dropdown in tests.
  @visibleForTesting
  static const locationKey = ValueKey('inventoryReport.location');

  /// Finds the prices switch in tests.
  @visibleForTesting
  static const pricesKey = ValueKey('inventoryReport.prices');

  /// Shows the sheet and returns the options, or null if dismissed.
  static Future<InventoryReportOptions?> show(BuildContext context) =>
      showModalBottomSheet<InventoryReportOptions>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const InventoryReportSheet(),
      );

  @override
  ConsumerState<InventoryReportSheet> createState() =>
      _InventoryReportSheetState();
}

class _InventoryReportSheetState extends ConsumerState<InventoryReportSheet> {
  InventoryGrouping _grouping = InventoryGrouping.type;
  String? _locationId;
  bool _showPrices = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final places = [
      for (final place
          in ref.watch(equipmentLocationsProvider).value ?? const [])
        if (!place.isArchived) place,
    ];

    return ReportSheetScaffold(
      title: l10n.transfer_export_inventoryTitle,
      onContinue: () => Navigator.of(context).pop(
        InventoryReportOptions(
          grouping: _grouping,
          locationId: _locationId,
          showPrices: _showPrices,
        ),
      ),
      children: [
        Text(
          l10n.equipmentReport_sheet_groupBy,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SegmentedButton<InventoryGrouping>(
          segments: [
            ButtonSegment(
              value: InventoryGrouping.type,
              label: Text(l10n.equipmentReport_sheet_groupByType),
            ),
            ButtonSegment(
              value: InventoryGrouping.location,
              label: Text(l10n.equipmentReport_sheet_groupByLocation),
            ),
          ],
          selected: {_grouping},
          onSelectionChanged: (selected) =>
              setState(() => _grouping = selected.first),
        ),
        const SizedBox(height: 16),
        // A diver who has set up no places has nothing to narrow to.
        if (places.isNotEmpty)
          ReportSheetDropdown<String?>(
            key: InventoryReportSheet.locationKey,
            label: l10n.equipmentReport_sheet_location,
            value: _locationId,
            options: [
              (null, l10n.equipmentReport_sheet_allLocations),
              for (final place in places) (place.id, place.name),
            ],
            onChanged: (id) => setState(() => _locationId = id),
          ),
        SwitchListTile(
          key: InventoryReportSheet.pricesKey,
          title: Text(l10n.equipmentReport_sheet_showPrices),
          subtitle: Text(l10n.equipmentReport_sheet_showPricesHelp),
          value: _showPrices,
          onChanged: (value) => setState(() => _showPrices = value),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}
