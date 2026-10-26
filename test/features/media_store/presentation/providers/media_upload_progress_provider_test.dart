// The Photos page's "{copied} of {total} copied" counts for the attached
// store, so copies in another store are not copies here (issue #3482).

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/media_store/domain/media_transfer_summary.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_upload_progress_provider.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late MediaStoreAttachState attachState;
  late MediaRepository media;

  setUp(() async {
    final db = await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    attachState = MediaStoreAttachState(
      prefs: await SharedPreferences.getInstance(),
    );
    media = MediaRepository();
    final epoch = DateTime(2026).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            diveDateTime: Value(epoch),
            createdAt: Value(epoch),
            updatedAt: Value(epoch),
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  Future<void> photo(String name, {String? storeId}) async {
    final created = await media.createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        filePath: '/tmp/$name',
        localPath: '/tmp/$name',
        originalFilename: name,
        diveId: 'dive-1',
        takenAt: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await media.stampRemoteUploaded(
      created.id,
      uploadedAt: DateTime.utc(2026),
      storeId: storeId,
    );
  }

  Future<({int copied, int total})> read() async {
    final container = ProviderContainer(
      overrides: [
        mediaStoreAttachStateProvider.overrideWithValue(attachState),
        mediaTransferSummaryProvider.overrideWith(
          (ref) => Stream.value(const MediaTransferSummary()),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(mediaUploadProgressProvider, (_, _) {});
    addTearDown(sub.close);
    return container.read(mediaUploadProgressProvider.future);
  }

  test('counts only the attached store\'s copies', () async {
    await attachState.setAttached(
      'store-b',
      providerType: CloudProviderType.dropbox,
    );
    await photo('old.jpg', storeId: 'store-a');
    await photo('here.jpg', storeId: 'store-b');

    final progress = await read();

    expect(progress.total, 2);
    expect(progress.copied, 1);
  });

  test('with nothing attached every stamp counts', () async {
    await photo('old.jpg', storeId: 'store-a');

    expect((await read()).copied, 1);
  });

  test(
    'a device on a store that is not announced leaves out moved rows',
    () async {
      await attachState.setAttached(
        'store-a',
        providerType: CloudProviderType.dropbox,
      );
      await MediaStoresRepository().upsertActive(
        storeId: 'store-b',
        providerType: 'dropbox',
        displayHint: 'Dropbox',
      );
      await photo('moved.jpg', storeId: 'store-b');
      await photo('here.jpg', storeId: 'store-a');

      final progress = await read();

      expect(progress.total, 1);
      expect(progress.copied, 1);
    },
  );
}
