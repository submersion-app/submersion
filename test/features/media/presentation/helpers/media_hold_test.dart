import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/helpers/media_hold.dart';

/// What the photo picker hands a sitting on a dive (issue #4527, plan 6).
void main() {
  test('a network request is drawn as a network photo on its dive, under '
      'a fresh id', () {
    final request = NetworkInsertRequest(
      media: ResolvedNetworkMedia(uri: Uri.parse('https://x.test/a.jpg')),
      diveId: 'dive-1',
    );
    final a = networkPreview(request);
    final b = networkPreview(request);
    expect(a.diveId, 'dive-1');
    expect(a.sourceType, MediaSourceType.networkUrl);
    expect(a.url, 'https://x.test/a.jpg');
    expect(a.id, isNot(b.id));
  });

  testWidgets('the scope hands the tabs its sink; with none, nothing', (
    tester,
  ) async {
    final handed = <List<HeldMediaAdd>>[];
    MediaHoldSink? seen;
    await tester.pumpWidget(
      MediaHoldScope.wrap(
        handed.add,
        Builder(
          builder: (context) {
            seen = MediaHoldScope.maybeOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(seen, isNotNull);
    seen!(const []);
    expect(handed, hasLength(1));

    await tester.pumpWidget(
      MediaHoldScope.wrap(
        null,
        Builder(
          builder: (context) {
            seen = MediaHoldScope.maybeOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(seen, isNull);
  });

  test('a network request for a site is drawn on that site', () {
    final request = NetworkInsertRequest(
      media: ResolvedNetworkMedia(uri: Uri.parse('https://x.test/a.jpg')),
      siteId: 'site-1',
    );

    final preview = networkPreview(request);

    expect(preview.siteId, 'site-1');
    expect(preview.diveId, isNull);
  });
}
