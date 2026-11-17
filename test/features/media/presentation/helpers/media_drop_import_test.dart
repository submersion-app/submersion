import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/open_dive_sitting_provider.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/media/presentation/helpers/media_drop_destination.dart';
import 'package:submersion/features/media/presentation/helpers/media_drop_import.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/l10n_test_helpers.dart';

const _hint = 'Unlock this dive to add photos.';

/// A photo dropped on a dive while it is locked is refused with a hint
/// before anything is looked up or opened (issue #4527, plan 6). The held
/// path ends in the photo picker, which flutter_test cannot drive; its
/// answer is open_dive_sitting_provider_test's, its hold the picker's own.
void main() {
  Future<void> drop(
    WidgetTester tester, {
    OpenDiveSitting? open,
    String diveId = 'dive-1',
  }) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(openDiveSittingProvider.notifier).state = open;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => importDroppedMedia(
                  context,
                  ref,
                  MediaDropDestination(target: DiveAttachTarget(diveId)),
                  const ['/photos/a.jpg'],
                ),
                child: const Text('drop'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('drop'));
    await tester.pump();
  }

  final dive = Dive(id: 'dive-1', dateTime: DateTime.utc(2026));

  testWidgets('a locked dive, its page or the list pane: the hint', (
    tester,
  ) async {
    await drop(tester);
    expect(find.text(_hint), findsOneWidget);
  });

  testWidgets('another dive unlocked: the hint, and its card stays shut', (
    tester,
  ) async {
    final session = EditSession<Dive>(dive);
    addTearDown(session.dispose);
    var shown = 0;
    await drop(
      tester,
      diveId: 'dive-2',
      open: OpenDiveSitting(
        diveId: 'dive-1',
        session: session,
        showMediaCard: () => shown++,
      ),
    );
    expect(find.text(_hint), findsOneWidget);
    expect(shown, 0);
  });

  testWidgets('a sitting being saved: the hint', (tester) async {
    final session = EditSession<Dive>(dive)..freeze();
    addTearDown(session.dispose);
    await drop(
      tester,
      open: OpenDiveSitting(
        diveId: 'dive-1',
        session: session,
        showMediaCard: () {},
      ),
    );
    expect(find.text(_hint), findsOneWidget);
  });
}
