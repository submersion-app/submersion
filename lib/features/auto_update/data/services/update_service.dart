import 'package:submersion/features/auto_update/domain/entities/update_status.dart';

abstract class UpdateService {
  Future<UpdateStatus> checkForUpdate();
}
