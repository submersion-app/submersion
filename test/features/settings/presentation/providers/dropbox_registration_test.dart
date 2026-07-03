import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/dropbox_storage_provider.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

void main() {
  test(
    'CloudProviderType.dropbox persists under the stable name "dropbox"',
    () {
      expect(CloudProviderType.dropbox.name, 'dropbox');
    },
  );

  test('cloudProviderInstanceFor returns the Dropbox singleton', () {
    final a = cloudProviderInstanceFor(CloudProviderType.dropbox);
    final b = cloudProviderInstanceFor(CloudProviderType.dropbox);
    expect(a, isA<DropboxStorageProvider>());
    expect(identical(a, b), isTrue);
    expect(a.providerId, 'dropbox');
  });
}
