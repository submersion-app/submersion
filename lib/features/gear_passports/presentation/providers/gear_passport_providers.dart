import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/gear_passports/data/services/gear_adoption_service.dart';

final gearAdoptionServiceProvider = Provider<GearAdoptionService>(
  (ref) => GearAdoptionService(),
);
