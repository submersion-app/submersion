import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/synology/synology_share_link.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/network_video_providers.dart';

final _link = SynologyShareLink.tryParseShareLink(
  Uri.parse('https://nas.example.com:5001/mo/sharing/code1'),
)!;

MediaItem _item({
  required String? url,
  MediaType type = MediaType.video,
  MediaSourceType source = MediaSourceType.manifestEntry,
}) => MediaItem(
  id: 'm1',
  mediaType: type,
  sourceType: source,
  url: url,
  takenAt: DateTime.utc(2024, 1, 1),
  createdAt: DateTime.utc(2024, 1, 1),
  updatedAt: DateTime.utc(2024, 1, 1),
);

void main() {
  final stream = _link.streamUri(id: 7, cacheKey: '7_1').toString();

  test('a network video plays through the cache, nothing else does', () {
    expect(isNetworkVideo(_item(url: stream)), isTrue);
    expect(
      isNetworkVideo(_item(url: stream, source: MediaSourceType.networkUrl)),
      isTrue,
    );
    expect(isNetworkVideo(_item(url: stream, type: MediaType.photo)), isFalse);
    expect(
      isNetworkVideo(_item(url: stream, source: MediaSourceType.localFile)),
      isFalse,
    );
    expect(isNetworkVideo(_item(url: null)), isFalse);
  });

  test('only a conversion offers its original', () {
    expect(hasPlayableOriginal(_item(url: stream)), isTrue);
    expect(
      hasPlayableOriginal(
        _item(url: _link.originalUri(id: 7, cacheKey: '7_1').toString()),
      ),
      isFalse,
    );
    expect(
      hasPlayableOriginal(_item(url: 'https://example.com/a.mp4')),
      isFalse,
    );
  });

  test('the original replaces the conversion when chosen', () {
    final item = _item(url: stream);
    expect(networkVideoUrl(item, original: false), Uri.parse(stream));
    expect(
      networkVideoUrl(item, original: true),
      _link.originalUri(id: 7, cacheKey: '7_1'),
    );
    final plain = _item(url: 'https://example.com/a.mp4');
    expect(
      networkVideoUrl(plain, original: true),
      Uri.parse('https://example.com/a.mp4'),
    );
  });
}
