import 'package:submersion/core/constants/enums.dart';

/// Service record DTO for equipment maintenance export/import.
///
/// This is a lightweight transfer object used by the export service,
/// separate from the domain ServiceRecord entity.
class ServiceRecord {
  final String id;
  final String equipmentId;
  final ServiceType serviceType;
  final DateTime serviceDate;
  final String? provider;
  final double? cost;
  final String currency;
  final DateTime? nextServiceDue;
  final String notes;

  const ServiceRecord({
    required this.id,
    required this.equipmentId,
    required this.serviceType,
    required this.serviceDate,
    this.provider,
    this.cost,
    this.currency = 'USD',
    this.nextServiceDue,
    this.notes = '',
  });
}
