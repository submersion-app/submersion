import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/features/media/presentation/widgets/people_tags/face_box_layer.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

MediaPersonChip chip(String id, String? name, {Duration? at, String? diver}) =>
    MediaPersonChip(
      buddyName: name,
      tag: MediaPersonTag(
        id: id,
        mediaId: 'm1',
        buddyId: diver == null ? id : null,
        diverId: diver,
        box: const FaceBox(x: 0.1, y: 0.1, width: 0.2, height: 0.2),
        videoPosition: at,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required List<MediaPersonChip> chips,
    Size? imageSize = const Size(400, 300),
    bool visible = true,
    Duration? showAt,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaPeopleChipsProvider('m1').overrideWith((ref) async => chips),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Center(
            child: SizedBox(
              key: const ValueKey('view'),
              width: 400,
              height: 300,
              child: FaceBoxLayer(
                mediaId: 'm1',
                imageSize: imageSize,
                visible: visible,
                showAt: showAt,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('draws a labelled box per tag', (tester) async {
    await pump(
      tester,
      chips: [
        chip('alex', 'Alex'),
        chip('me', null, diver: 'A'),
      ],
    );
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
    final view = tester.getTopLeft(find.byKey(const ValueKey('view')));
    final rect = tester.getRect(find.byKey(const ValueKey('face-box-alex')));
    expect(rect.shift(-view), const Rect.fromLTWH(40, 30, 80, 60));
  });

  testWidgets('is hidden with the viewer controls', (tester) async {
    await pump(tester, chips: [chip('alex', 'Alex')], visible: false);
    expect(find.text('Alex'), findsNothing);
  });

  testWidgets('draws nothing until the image size is known', (tester) async {
    await pump(tester, chips: [chip('alex', 'Alex')], imageSize: null);
    expect(find.text('Alex'), findsNothing);
  });

  testWidgets('on a video shows only the boxes at the shown moment', (
    tester,
  ) async {
    await pump(
      tester,
      chips: [
        chip('alex', 'Alex', at: const Duration(seconds: 42)),
        chip('bea', 'Bea', at: const Duration(seconds: 90)),
      ],
      showAt: const Duration(milliseconds: 42300),
    );
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Bea'), findsNothing);
  });

  testWidgets('a tag without a spot draws no box', (tester) async {
    final noSpot = MediaPersonChip(
      buddyName: 'Cal',
      tag: MediaPersonTag(
        id: 'cal',
        mediaId: 'm1',
        buddyId: 'cal',
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    await pump(tester, chips: [noSpot]);
    expect(find.text('Cal'), findsNothing);
  });

  testWidgets('a box frame never dims the face inside it', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 80,
            height: 80,
            child: FaceBoxFrame(label: 'A'),
          ),
        ),
      ),
    );
    // A box shadow paints a filled shape behind the frame, which shows
    // through its transparent middle as a dark square over the face.
    final decorations = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(FaceBoxFrame),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((d) => d.decoration)
        .whereType<BoxDecoration>();
    for (final d in decorations) {
      expect(d.boxShadow ?? const [], isEmpty);
    }
  });
}
