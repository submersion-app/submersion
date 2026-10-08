import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/services/equipment_transfer_service.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_transfer_providers.dart';

void main() {
  test('the transfer service provider builds the real service', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(equipmentTransferServiceProvider),
      isA<EquipmentTransferService>(),
    );
  });
}
