import 'package:flutter/material.dart';

import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';

/// The Record header's export action (Task 7 wires the share and save).
class TripGasRecordExportButton extends StatelessWidget {
  const TripGasRecordExportButton({
    super.key,
    required this.record,
    required this.tripName,
    required this.centerNames,
  });

  final TripGasRecord record;
  final String tripName;
  final Map<String, String> centerNames;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
