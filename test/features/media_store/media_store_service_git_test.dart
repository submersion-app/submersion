import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/features/media_store/data/media_store_service.dart';

void main() {
  test('Git is never a media store', () async {
    // Photos and videos in Git history would grow the repository forever.
    expect(await buildMediaObjectStore(CloudProviderType.git), isNull);
  });
}
