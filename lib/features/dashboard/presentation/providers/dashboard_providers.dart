import 'package:submersion/core/providers/provider.dart';

import '../../../dive_log/domain/entities/dive.dart';
import '../../../dive_log/presentation/providers/dive_providers.dart';
import '../../../divers/domain/entities/diver.dart';
import '../../../divers/presentation/providers/diver_providers.dart';
import '../../../equipment/domain/entities/equipment_item.dart';
import '../../../equipment/presentation/providers/equipment_providers.dart';

/// Dashboard alerts data class
class DashboardAlerts {
  final List<EquipmentItem> equipmentServiceDue;
  final bool insuranceExpiringSoon;
  final bool insuranceExpired;
  final DateTime? insuranceExpiryDate;
  final String? insuranceProvider;

  const DashboardAlerts({
    required this.equipmentServiceDue,
    required this.insuranceExpiringSoon,
    required this.insuranceExpired,
    this.insuranceExpiryDate,
    this.insuranceProvider,
  });

  bool get hasAlerts =>
      equipmentServiceDue.isNotEmpty ||
      insuranceExpiringSoon ||
      insuranceExpired;

  int get alertCount {
    int count = equipmentServiceDue.length;
    if (insuranceExpiringSoon || insuranceExpired) count++;
    return count;
  }
}

/// Recent dives provider (last 5)
final recentDivesProvider = FutureProvider<List<Dive>>((ref) async {
  final allDives = await ref.watch(divesProvider.future);
  // Dives are already sorted by date descending in the repository
  return allDives.take(5).toList();
});

/// Dashboard alerts provider - combines equipment and insurance alerts
final dashboardAlertsProvider = FutureProvider<DashboardAlerts>((ref) async {
  final serviceDue = await ref.watch(serviceDueEquipmentProvider.future);
  final diver = await ref.watch(currentDiverProvider.future);

  return DashboardAlerts(
    equipmentServiceDue: serviceDue,
    insuranceExpiringSoon: diver?.insurance.isExpiringSoon ?? false,
    insuranceExpired: diver?.insurance.isExpired ?? false,
    insuranceExpiryDate: diver?.insurance.expiryDate,
    insuranceProvider: diver?.insurance.provider,
  );
});

/// Current diver provider (re-exported for convenience)
final dashboardDiverProvider = FutureProvider<Diver?>((ref) async {
  return ref.watch(currentDiverProvider.future);
});
