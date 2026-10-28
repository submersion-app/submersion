import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/people_tag_editor.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The tag-mode box editor (issue #1745).
void main() {
  final tag = MediaPersonTag(
    id: 't1',
    mediaId: 'm1',
    buddyId: 'alex',
    box: const FaceBox(x: 0.25, y: 0.25, width: 0.25, height: 0.25),
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );

  testWidgets('a corner handle can be grabbed from just outside the box', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 400);
    addTearDown(tester.view.reset);
    FaceBox? moved;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaPeopleChipsProvider('m1').overrideWith(
            (ref) async => [MediaPersonChip(tag: tag, buddyName: 'Alex')],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PeopleTagEditor(
            mediaId: 'm1',
            imageSize: const Size(400, 400),
            selectedTagId: 't1',
            canPlace: true,
            onPlace: (_) {},
            onSelect: (_) {},
            onMove: (_, box) => moved = box,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The box's top left corner is at (100, 100); start 8 px outside it.
    await tester.dragFrom(const Offset(93, 93), const Offset(-40, -40));
    await tester.pumpAndSettle();

    expect(moved, isNotNull);
    expect(moved!.x, lessThan(0.25));
    expect(moved!.width, greaterThan(0.25));
  });

  testWidgets('a dropped box stays put until the save comes back', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The saved row never changes here: the write has not landed.
          mediaPeopleChipsProvider('m1').overrideWith(
            (ref) async => [MediaPersonChip(tag: tag, buddyName: 'Alex')],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PeopleTagEditor(
            mediaId: 'm1',
            imageSize: const Size(400, 400),
            selectedTagId: 't1',
            canPlace: true,
            onPlace: (_) {},
            onSelect: (_) {},
            onMove: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = tester.getRect(find.byKey(const ValueKey('edit-box-t1')));

    // Drag the box's middle (150, 150) by 60 px right.
    await tester.dragFrom(const Offset(150, 150), const Offset(60, 0));
    await tester.pumpAndSettle();

    // The pan's touch slop takes the first ~20 px of the drag.
    final after = tester.getRect(find.byKey(const ValueKey('edit-box-t1')));
    expect(after.left, greaterThan(before.left + 30));
  });
}
