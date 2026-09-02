import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_unlink_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';

class _StubMediaRepository extends MediaRepository {
  @override
  Future<List<MediaItem>> getMediaForSite(String siteId) async =>
      const <MediaItem>[];
}

/// Records the site unlinks routed through the notifier.
class _RecordingUnlinkService implements MediaUnlinkService {
  final List<List<String>> siteUnlinks = [];

  @override
  Future<SiteUnlinkOutcome> unlinkFromSite(List<String> mediaIds) async {
    siteUnlinks.add(List.of(mediaIds));
    return SiteUnlinkOutcome(deleted: mediaIds.length, keptAsDiveMedia: 0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('unlinkMultipleMedia routes through the unlink service', () async {
    final service = _RecordingUnlinkService();
    final container = ProviderContainer(
      overrides: [
        mediaRepositoryProvider.overrideWithValue(_StubMediaRepository()),
        mediaUnlinkServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(
      siteMediaListNotifierProvider('site-1').notifier,
    );
    final outcome = await notifier.unlinkMultipleMedia(['m1', 'm2']);

    expect(service.siteUnlinks, [
      ['m1', 'm2'],
    ]);
    expect(outcome.deleted, 2);
    expect(outcome.keptAsDiveMedia, 0);
  });
}
