import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/card_focus_analyzer.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_crop_alignment.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_photo.dart';
import 'package:submersion/features/dive_log/domain/card_photo/focus_box.dart';
import 'package:submersion/features/dive_log/presentation/providers/card_photo_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_card_photo_background.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/data/services/small_image_decoder.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

class _BytesResolver implements MediaSourceResolver {
  _BytesResolver(this.bytes);
  final Uint8List bytes;
  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async =>
      item.id.startsWith('missing')
      ? const UnavailableData(kind: UnavailableKind.notFound)
      : BytesData(bytes: bytes);
  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

/// The analyser key a card uses for [_item] with [id].
String _key(String id) => DiveCardPhotoBackground.analysisKeyFor(_item(id));

MediaItem _item(String id) => MediaItem(
  id: id,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  takenAt: DateTime(2024),
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

/// A tall image with a bright band low down, so pixel analysis has
/// somewhere to put the crop.
SmallImage _analysedImage() {
  const w = 8;
  const h = 32;
  final rgba = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final v = (y > 22 && y < 28 && x.isEven) ? 255 : 10;
      rgba[i] = v;
      rgba[i + 1] = v;
      rgba[i + 2] = v;
      rgba[i + 3] = 255;
    }
  }
  return (rgba: rgba, width: w, height: h);
}

const _cardSize = Size(400, 120);
const _overlay = (dark: 0.8, light: 0.3);

void main() {
  late SharedPreferences prefs;
  late Uint8List png;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    // Portrait, so a wide card crops it and the alignment matters.
    png = Uint8List.fromList(img.encodePng(img.Image(width: 60, height: 120)));
  });
  tearDown(tearDownTestDatabase);

  /// Pumps the background around a card-sized child, and lets the photo
  /// resolve and decode.
  Future<void> pumpCard(
    WidgetTester tester, {
    required ValueNotifier<CardPhoto> photo,
    required CardFocusAnalyzer analyzer,
    Brightness brightness = Brightness.dark,
    bool hasMedia = true,
    Size size = _cardSize,
    ValueNotifier<MediaItem>? media,
  }) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            mediaSourceResolverRegistryProvider.overrideWithValue(
              MediaSourceResolverRegistry({
                MediaSourceType.platformGallery: _BytesResolver(png),
              }),
            ),
            mediaByIdProvider.overrideWith((ref, id) async {
              if (media != null) {
                void refresh() => ref.invalidateSelf();
                media.addListener(refresh);
                ref.onDispose(() => media.removeListener(refresh));
                return media.value;
              }
              return hasMedia ? _item(id) : null;
            }),
            cardPhotoOverlayProvider.overrideWithValue(_overlay),
            cardFocusAnalyzerProvider.overrideWithValue(analyzer),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData(brightness: brightness),
            home: Center(
              child: SizedBox.fromSize(
                size: size,
                child: ValueListenableBuilder<CardPhoto>(
                  valueListenable: photo,
                  builder: (context, value, _) => DiveCardPhotoBackground(
                    photo: value,
                    child: const Text('card'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
    });
  }

  Set<String> failed(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(DiveCardPhotoBackground)),
  ).read(failedCardPhotosProvider);

  Finder fade() => find.descendant(
    of: find.byType(DiveCardPhotoBackground),
    matching: find.byType(AnimatedOpacity),
  );

  double opacity(WidgetTester tester) =>
      tester.widget<AnimatedOpacity>(fade()).opacity;

  double imageAlignmentY(WidgetTester tester) =>
      (tester.widget<Image>(find.byType(Image)).alignment as Alignment).y;

  LinearGradient? scrim(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: fade(), matching: find.byType(DecoratedBox)).last,
    );
    return (box.decoration as BoxDecoration).gradient as LinearGradient?;
  }

  /// The aspect of the decoded image, as the card computes its crop from.
  const imageAspect = 60 / 120;
  final cardAspect = _cardSize.width / _cardSize.height;

  testWidgets('a dive whose photo has no media row shows only the card', (
    tester,
  ) async {
    await pumpCard(
      tester,
      photo: ValueNotifier(const CardPhoto(mediaId: 'gone')),
      analyzer: CardFocusAnalyzer(decode: (_) async => null),
      hasMedia: false,
    );

    expect(find.text('card'), findsOneWidget);
    expect(fade(), findsNothing);
    // So the card moves on to another photo, or the map.
    expect(failed(tester), {'gone'});
  });

  testWidgets('a photo whose file cannot be found is marked failed', (
    tester,
  ) async {
    await pumpCard(
      tester,
      photo: ValueNotifier(const CardPhoto(mediaId: 'missing-1')),
      analyzer: CardFocusAnalyzer(decode: (_) async => null),
    );

    expect(failed(tester), {'missing-1'});
    expect(opacity(tester), 0);
  });

  testWidgets('a photo that draws is not marked failed', (tester) async {
    await pumpCard(
      tester,
      photo: ValueNotifier(const CardPhoto(mediaId: 'm1')),
      analyzer: CardFocusAnalyzer(decode: (_) async => null),
    );

    expect(failed(tester), isEmpty);
  });

  testWidgets('a photo with tagged people fades in cropped to them, without '
      'pixel analysis', (tester) async {
    var decodes = 0;
    const boxes = [FocusBox(x: 0.3, y: 0.7, width: 0.3, height: 0.2)];
    await pumpCard(
      tester,
      photo: ValueNotifier(const CardPhoto(mediaId: 'm1', focusBoxes: boxes)),
      analyzer: CardFocusAnalyzer(
        decode: (_) async {
          decodes++;
          return null;
        },
      ),
    );

    expect(opacity(tester), 1);
    expect(decodes, 0);
    expect(
      imageAlignmentY(tester),
      closeTo(
        cardCropAlignmentY(
          imageAspect: imageAspect,
          cardAspect: cardAspect,
          focusBoxes: boxes,
        ),
        0.02,
      ),
    );
    expect(find.text('card'), findsOneWidget);
  });

  testWidgets('a photo without people stays hidden until its analysis '
      'lands, then crops to it', (tester) async {
    final analysis = Completer<SmallImage?>();
    final analyzer = CardFocusAnalyzer(decode: (_) => analysis.future);
    await pumpCard(
      tester,
      photo: ValueNotifier(const CardPhoto(mediaId: 'm1')),
      analyzer: analyzer,
    );

    expect(opacity(tester), 0);
    expect(imageAlignmentY(tester), 0);

    await tester.runAsync(() async {
      analysis.complete(_analysedImage());
      await settle(tester);
    });

    expect(opacity(tester), 1);
    final rows = analyzer.peek(_key('m1'));
    expect(rows, isNotNull);
    final expected = cardCropAlignmentY(
      imageAspect: imageAspect,
      cardAspect: cardAspect,
      rowScores: rows,
    );
    // The bright band is low in the image, so the crop moves down.
    expect(expected, greaterThan(0));
    expect(imageAlignmentY(tester), closeTo(expected, 0.02));
  });

  testWidgets('a failed analysis still shows the photo, centred', (
    tester,
  ) async {
    await pumpCard(
      tester,
      photo: ValueNotifier(const CardPhoto(mediaId: 'm1')),
      analyzer: CardFocusAnalyzer(decode: (_) async => null),
    );

    expect(opacity(tester), 1);
    expect(imageAlignmentY(tester), 0);
  });

  testWidgets('a photo analysed before reuses the answer without decoding '
      'again', (tester) async {
    var decodes = 0;
    final analyzer = CardFocusAnalyzer(
      decode: (_) async {
        decodes++;
        return _analysedImage();
      },
    );
    await tester.runAsync(
      () => analyzer.rowScoresFor(_key('m1'), MemoryImage(png)),
    );
    expect(decodes, 1);

    await pumpCard(
      tester,
      photo: ValueNotifier(const CardPhoto(mediaId: 'm1')),
      analyzer: analyzer,
    );

    expect(decodes, 1);
    expect(opacity(tester), 1);
    expect(
      imageAlignmentY(tester),
      closeTo(
        cardCropAlignmentY(
          imageAspect: imageAspect,
          cardAspect: cardAspect,
          rowScores: analyzer.peek(_key('m1')),
        ),
        0.02,
      ),
    );
  });

  testWidgets('untagging the people on a photo crops it by its pixels '
      'instead', (tester) async {
    var decodes = 0;
    final analyzer = CardFocusAnalyzer(
      decode: (_) async {
        decodes++;
        return _analysedImage();
      },
    );
    final photo = ValueNotifier(
      const CardPhoto(
        mediaId: 'm1',
        focusBoxes: [FocusBox(x: 0.3, y: 0.05, width: 0.2, height: 0.1)],
      ),
    );
    await pumpCard(tester, photo: photo, analyzer: analyzer);
    expect(decodes, 0);
    // Cropped to the box near the top.
    expect(imageAlignmentY(tester), lessThan(0));

    await tester.runAsync(() async {
      photo.value = const CardPhoto(mediaId: 'm1');
      await settle(tester);
    });

    expect(decodes, 1);
    expect(opacity(tester), 1);
    expect(
      imageAlignmentY(tester),
      closeTo(
        cardCropAlignmentY(
          imageAspect: imageAspect,
          cardAspect: cardAspect,
          rowScores: analyzer.peek(_key('m1')),
        ),
        0.02,
      ),
    );
    expect(imageAlignmentY(tester), greaterThan(0));
  });

  testWidgets('untagging the people on a photo analysed before reuses its '
      'scores without decoding again', (tester) async {
    var decodes = 0;
    final analyzer = CardFocusAnalyzer(
      decode: (_) async {
        decodes++;
        return _analysedImage();
      },
    );
    // Another card already analysed this photo's pixels.
    await tester.runAsync(
      () => analyzer.rowScoresFor(_key('m1'), MemoryImage(png)),
    );
    expect(decodes, 1);
    final photo = ValueNotifier(
      const CardPhoto(
        mediaId: 'm1',
        focusBoxes: [FocusBox(x: 0.3, y: 0.05, width: 0.2, height: 0.1)],
      ),
    );
    await pumpCard(tester, photo: photo, analyzer: analyzer);
    expect(imageAlignmentY(tester), lessThan(0));

    await tester.runAsync(() async {
      photo.value = const CardPhoto(mediaId: 'm1');
      await settle(tester);
    });

    expect(decodes, 1);
    expect(opacity(tester), 1);
    expect(
      imageAlignmentY(tester),
      closeTo(
        cardCropAlignmentY(
          imageAspect: imageAspect,
          cardAspect: cardAspect,
          rowScores: analyzer.peek(_key('m1')),
        ),
        0.02,
      ),
    );
    expect(imageAlignmentY(tester), greaterThan(0));
  });

  testWidgets('tagging someone on a photo crops it to them without decoding '
      'again', (tester) async {
    var decodes = 0;
    final analyzer = CardFocusAnalyzer(
      decode: (_) async {
        decodes++;
        return _analysedImage();
      },
    );
    final photo = ValueNotifier(const CardPhoto(mediaId: 'm1'));
    await pumpCard(tester, photo: photo, analyzer: analyzer);
    expect(decodes, 1);

    const boxes = [FocusBox(x: 0.3, y: 0.05, width: 0.2, height: 0.1)];
    await tester.runAsync(() async {
      photo.value = const CardPhoto(mediaId: 'm1', focusBoxes: boxes);
      await settle(tester);
    });

    expect(decodes, 1);
    expect(
      imageAlignmentY(tester),
      closeTo(
        cardCropAlignmentY(
          imageAspect: imageAspect,
          cardAspect: cardAspect,
          focusBoxes: boxes,
          rowScores: analyzer.peek(_key('m1')),
        ),
        0.02,
      ),
    );
    expect(imageAlignmentY(tester), lessThan(0));
  });

  testWidgets('a different photo hides the card again until it is ready', (
    tester,
  ) async {
    final second = Completer<SmallImage?>();
    final analyzer = CardFocusAnalyzer(
      decode: (_) => second.isCompleted ? Future.value(null) : second.future,
    );
    final photo = ValueNotifier(
      const CardPhoto(
        mediaId: 'm1',
        focusBoxes: [FocusBox(x: 0.3, y: 0.1, width: 0.2, height: 0.2)],
      ),
    );
    await pumpCard(tester, photo: photo, analyzer: analyzer);
    expect(opacity(tester), 1);

    // The new photo has decoded but its analysis is still out: the card
    // must not keep showing the first photo's ready state.
    await tester.runAsync(() async {
      photo.value = const CardPhoto(mediaId: 'm2');
      await settle(tester);
    });
    expect(opacity(tester), 0);

    await tester.runAsync(() async {
      second.complete(null);
      await settle(tester);
    });
    expect(opacity(tester), 1);
  });

  testWidgets('a card with no width draws no photo', (tester) async {
    await pumpCard(
      tester,
      photo: ValueNotifier(const CardPhoto(mediaId: 'm1')),
      analyzer: CardFocusAnalyzer(decode: (_) async => null),
      size: const Size(0, 120),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsNothing);
    expect(find.text('card'), findsOneWidget);
  });

  testWidgets('a photo relinked to other pixels under the same id is '
      'analysed again, not cropped by the old scores', (tester) async {
    var decodes = 0;
    final analyzer = CardFocusAnalyzer(
      decode: (_) async {
        decodes++;
        return _analysedImage();
      },
    );
    final media = ValueNotifier(_item('m1').copyWith(localPath: '/old.jpg'));
    await pumpCard(
      tester,
      photo: ValueNotifier(const CardPhoto(mediaId: 'm1')),
      analyzer: analyzer,
      media: media,
    );
    expect(decodes, 1);
    expect(opacity(tester), 1);

    await tester.runAsync(() async {
      media.value = _item('m1').copyWith(localPath: '/new.jpg');
      await settle(tester);
    });

    expect(decodes, 2);
    expect(opacity(tester), 1);
    expect(
      analyzer.hasAnswer(DiveCardPhotoBackground.analysisKeyFor(media.value)),
      isTrue,
    );
  });

  test(
    'sources that differ only in where a path splits get different keys',
    () {
      // '|' is a valid path character, so it cannot be the separator.
      final split = _item('m1').copyWith(filePath: 'a', localPath: 'b');
      final joined = _item('m1').copyWith(filePath: 'a|b');
      expect(
        DiveCardPhotoBackground.analysisKeyFor(split),
        isNot(DiveCardPhotoBackground.analysisKeyFor(joined)),
      );
    },
  );

  testWidgets('the dark theme draws its own overlay', (tester) async {
    await pumpCard(
      tester,
      photo: ValueNotifier(const CardPhoto(mediaId: 'm1')),
      analyzer: CardFocusAnalyzer(decode: (_) async => null),
    );

    expect(
      scrim(tester),
      DiveCardPhotoScrim.gradient(Brightness.dark, _overlay.dark),
    );
  });

  test('the card text is chosen against the overlay colour of its theme', () {
    expect(
      DiveCardPhotoScrim.textBase(Brightness.dark),
      const Color(0xFF1A1A2E),
    );
    expect(DiveCardPhotoScrim.textBase(Brightness.light), Colors.white);
  });

  testWidgets('the light theme draws its own overlay', (tester) async {
    await pumpCard(
      tester,
      photo: ValueNotifier(const CardPhoto(mediaId: 'm1')),
      analyzer: CardFocusAnalyzer(decode: (_) async => null),
      brightness: Brightness.light,
    );

    expect(
      scrim(tester),
      DiveCardPhotoScrim.gradient(Brightness.light, _overlay.light),
    );
  });
}

/// Real time for the resolver and decoder, with frames in between.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
}
