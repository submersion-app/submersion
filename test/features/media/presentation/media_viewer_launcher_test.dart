import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_launcher.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';

MediaItem _item(String id) => MediaItem(
  id: id,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.localFile,
  filePath: p.join('media', id),
  takenAt: DateTime(2026, 3, 12),
  createdAt: DateTime(2026, 3, 12),
  updatedAt: DateTime(2026, 3, 12),
);

void main() {
  testWidgets('pushes a full-screen MediaViewerPage on the tapped item', (
    tester,
  ) async {
    final observer = _RecordingObserver();
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );

    // didPush fires synchronously inside push, so the route is observable
    // without pumping a frame. Pumping would build MediaViewerPage, which
    // needs the viewer's whole provider graph; this test is about the route.
    openMediaViewer(ctx, [_item('a'), _item('b')], 'b');

    final route = observer.pushed.last as MaterialPageRoute<void>;
    expect(route.fullscreenDialog, isTrue);
    final page = route.builder(ctx) as MediaViewerPage;
    expect(page.initialMediaId, 'b');
    expect(page.mediaList.map((m) => m.id), ['a', 'b']);
    expect(page.showGoToDive, isTrue);
  });
}

class _RecordingObserver extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}
