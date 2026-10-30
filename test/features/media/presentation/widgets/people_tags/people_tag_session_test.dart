import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/people_tag_viewer_mixin.dart';

import '../../../../../helpers/test_database.dart';
import 'people_tag_test_host.dart';

class _Host extends ConsumerStatefulWidget {
  const _Host({required this.onPause, required this.onSession});
  final ValueChanged<String> onPause;
  final ValueChanged<PeopleTagSession> onSession;

  @override
  ConsumerState<_Host> createState() => _HostState();
}

class _HostState extends ConsumerState<_Host> with PeopleTagViewerMixin<_Host> {
  @override
  Widget build(BuildContext context) {
    widget.onSession(buildPeopleSession(pauseVideo: widget.onPause));
    return const Scaffold(body: SizedBox.expand());
  }
}

/// The session the viewer hands its pages (issue #1745).
void main() {
  setUp(() async {
    await setUpTestDatabase();
    await seedPeopleTagFixtures();
  });
  tearDown(tearDownTestDatabase);

  testWidgets('placing a box on a video pauses it first', (tester) async {
    final paused = <String>[];
    late PeopleTagSession session;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        await peopleTagHost(
          _Host(onPause: paused.add, onSession: (s) => session = s),
        ),
      );
    });
    final video = MediaItem(
      id: 'v1',
      diveId: 'd1',
      mediaType: MediaType.video,
      sourceType: MediaSourceType.platformGallery,
      takenAt: DateTime(2024),
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    session.onPlace(
      video,
      const FaceBox(x: 0.1, y: 0.1, width: 0.2, height: 0.2),
      const Duration(seconds: 3),
    );
    await tester.pump();

    expect(paused, ['v1']);
  });
}
