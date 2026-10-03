import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/services/equipment_transfer_service.dart';

final equipmentTransferServiceProvider = Provider<EquipmentTransferService>(
  (ref) => EquipmentTransferService(),
);
