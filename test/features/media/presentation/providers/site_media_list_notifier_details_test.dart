import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/site_attachment_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_details_edit.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';

class _StubMediaRepository extends MediaRepository {
  int loads = 0;

  @override
  Future<List<MediaItem>> getMediaForSite(String siteId) async {
    loads++;
    return const <MediaItem>[];
  }
}

class _RecordingSiteAttachmentRepository extends SiteAttachmentRepository {
  final details = <(String, AttachmentDetailsEdit)>[];
  final categories = <(List<String>, SiteAttachmentCategory?)>[];

  @override
  Future<void> setAttachmentDetails(
    String id,
    AttachmentDetailsEdit edit,
  ) async => details.add((id, edit));

  @override
  Future<int> setSiteCategory(
    List<String> ids,
    SiteAttachmentCategory? category,
  ) async {
    categories.add((ids, category));
    return ids.length - 1;
  }
}

/// Issue #1039: the site media notifier is how the UI saves attachment
/// details, and it reloads the site's list afterwards.
void main() {
  late _StubMediaRepository media;
  late _RecordingSiteAttachmentRepository attachments;
  late ProviderContainer container;

  setUp(() {
    media = _StubMediaRepository();
    attachments = _RecordingSiteAttachmentRepository();
    container = ProviderContainer(
      overrides: [
        mediaRepositoryProvider.overrideWithValue(media),
        siteAttachmentRepositoryProvider.overrideWithValue(attachments),
      ],
    );
    addTearDown(container.dispose);
  });

  test('setAttachmentDetails delegates, then reloads', () async {
    final notifier = container.read(
      siteMediaListNotifierProvider('s1').notifier,
    );
    final loadsBefore = media.loads;
    const edit = AttachmentDetailsEdit(
      category: FieldChange(SiteAttachmentCategory.parking),
    );
    await notifier.setAttachmentDetails('m1', edit);
    expect(attachments.details.single.$1, 'm1');
    expect(attachments.details.single.$2, same(edit));
    expect(media.loads, greaterThan(loadsBefore));
  });

  test('setSiteCategory delegates, then reloads', () async {
    final notifier = container.read(
      siteMediaListNotifierProvider('s1').notifier,
    );
    final loadsBefore = media.loads;
    expect(await notifier.setSiteCategory(['a', 'b'], null), 1);
    expect(attachments.categories.single.$1, ['a', 'b']);
    expect(attachments.categories.single.$2, isNull);
    expect(media.loads, greaterThan(loadsBefore));
  });
}
