import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/services/bulk_equipment_tag_service.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_tag_providers.dart';

/// Applies and undoes bulk tag edits across selected equipment (issue #1942).
final bulkEquipmentTagServiceProvider = Provider<BulkEquipmentTagService>(
  (ref) => BulkEquipmentTagService(ref.watch(equipmentTagRepositoryProvider)),
);
