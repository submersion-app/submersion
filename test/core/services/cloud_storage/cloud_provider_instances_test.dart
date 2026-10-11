import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/cloud_provider_instances.dart';

void main() {
  test('every provider id equals its enum name', () {
    // LibraryMovedMarker, EstablishedProviderStore and the cleanup offer map
    // ids back with CloudProviderType.values by name.
    for (final type in CloudProviderType.values) {
      expect(cloudProviderInstanceFor(type).providerId, type.name);
    }
  });
}
