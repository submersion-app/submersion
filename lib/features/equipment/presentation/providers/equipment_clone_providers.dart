import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/services/equipment_clone_service.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

/// Copies a clone's clocks, sets and documents (issue #3184).
final equipmentCloneServiceProvider = Provider<EquipmentCloneService>((ref) {
  return EquipmentCloneService(
    schedules: ref.watch(serviceScheduleRepositoryProvider),
    sets: ref.watch(equipmentSetRepositoryProvider),
    media: ref.watch(mediaRepositoryProvider),
  );
});
