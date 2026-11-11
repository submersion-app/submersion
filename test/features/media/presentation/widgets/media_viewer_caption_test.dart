import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/widgets/media_viewer_caption.dart';

/// The media viewer's source line (issue #3355) stays within its share of
/// the screen, so a long check-in title cannot run into the colour label or
/// off a phone's edge.
void main() {
  testWidgets('a long caption is bounded and kept to one line', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final long = 'Check-in: ${List.filled(20, 'Leaking hose').join(', ')}';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                top: 0,
                right: 12,
                child: MediaViewerCaption(text: long),
              ),
            ],
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byKey(const ValueKey('viewer_caption')));
    expect(size.width, lessThanOrEqualTo(375 * 0.6));
    final text = tester.widget<Text>(find.text(long));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });
}
