import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_crop_strip.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

import 'species_picture_test_support.dart';

void main() {
  final crops = [
    testCrop('i1', mediaId: 'p1'),
    testCrop('i2', mediaId: 'v1', video: true, bestMs: 4200),
  ];
  final media = [
    testPhoto('p1'),
    testPhoto('v1', video: true),
    testPhoto('p9'),
  ];

  Future<List<Object?>> pump(
    WidgetTester tester, {
    String? coverIdentificationId,
    String? coverMediaId,
    List<Object?>? calls,
  }) async {
    final log = calls ?? <Object?>[];
    await pumpPictures(
      tester,
      SpeciesCropStrip(
        crops: crops,
        uncropped: [testPhoto('p9')],
        media: media,
        coverIdentificationId: coverIdentificationId,
        coverMediaId: coverMediaId,
        onSetCover: (mediaId, identificationId) =>
            log.add(('set', mediaId, identificationId)),
        onClearCover: () => log.add('clear'),
        openViewer: (context, items, initialId, {initialVideoPosition}) =>
            log.add(('open', initialId, initialVideoPosition)),
      ),
    );
    return log;
  }

  Finder tile(String id) => find.byKey(ValueKey('species_strip_$id'));

  testWidgets('shows one tile per photo, cover first', (tester) async {
    await pump(tester, coverIdentificationId: 'i2', coverMediaId: 'v1');
    expect(tile('i1'), findsOneWidget);
    expect(tile('i2'), findsOneWidget);
    expect(tile('p9'), findsOneWidget);
    expect(
      tester.getTopLeft(tile('i2')).dx,
      lessThan(tester.getTopLeft(tile('i1')).dx),
    );
    expect(
      find.descendant(of: tile('i2'), matching: find.byIcon(Icons.star)),
      findsOneWidget,
    );
  });

  testWidgets('tap opens the viewer at bestMs for a video', (tester) async {
    final log = await pump(tester);
    await tester.tap(tile('i2'));
    await tester.tap(tile('i1'));
    expect(log, [
      ('open', 'v1', const Duration(milliseconds: 4200)),
      ('open', 'p1', null),
    ]);
  });

  testWidgets('long-press sets and removes the cover', (tester) async {
    final log = await pump(tester);
    await tester.longPress(tile('i1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use as cover'));
    await tester.pumpAndSettle();
    expect(log, [('set', 'p1', 'i1')]);

    final cleared = await pump(
      tester,
      coverIdentificationId: 'i1',
      coverMediaId: 'p1',
    );
    await tester.longPress(tile('i1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove cover'));
    await tester.pumpAndSettle();
    expect(cleared, ['clear']);
  });

  testWidgets('an uncropped photo becomes the cover without a crop', (
    tester,
  ) async {
    final log = await pump(tester);
    await tester.longPress(tile('p9'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use as cover'));
    await tester.pumpAndSettle();
    expect(log, [('set', 'p9', null)]);
  });

  testWidgets('nothing to show draws nothing', (tester) async {
    await pumpPictures(
      tester,
      SpeciesCropStrip(
        crops: const [],
        uncropped: const <MediaItem>[],
        media: const [],
        onSetCover: (_, _) {},
        onClearCover: () {},
      ),
    );
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('a cover on a smaller animal of a photo still marks that photo', (
    tester,
  ) async {
    await pump(
      tester,
      coverIdentificationId: 'small_on_p1',
      coverMediaId: 'p1',
    );
    expect(
      find.descendant(of: tile('i1'), matching: find.byIcon(Icons.star)),
      findsOneWidget,
    );
    await tester.longPress(tile('i1'));
    await tester.pumpAndSettle();
    expect(find.text('Remove cover'), findsOneWidget);
  });
}
