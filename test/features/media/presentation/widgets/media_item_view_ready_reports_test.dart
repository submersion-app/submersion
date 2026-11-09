import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

/// Serves each item id its own answer.
class _PerItemResolver implements MediaSourceResolver {
  _PerItemResolver(this.answers);
  final Map<String, MediaSourceData> answers;
  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;
  @override
  bool canResolveOnThisDevice(MediaItem item) => true;
  @override
  Future<MediaSourceData> resolve(MediaItem item) async => answers[item.id]!;
  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => resolve(item);
  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

MediaItem _item(String id) => MediaItem(
  id: id,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  takenAt: DateTime(2024),
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

Uint8List _png(int width, int height) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

/// A dive card's photo is analysed and shown only once [onImageReady] says
/// so, and falls back to the map or colour once [onImageFailed] does. Both
/// must speak for the item on screen, once.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(tearDownTestDatabase);

  Widget app(
    Map<String, MediaSourceData> answers,
    ValueNotifier<String> itemId, {
    void Function(ImageProvider provider, Size size)? onReady,
    VoidCallback? onFailed,
  }) => ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      mediaSourceResolverRegistryProvider.overrideWithValue(
        MediaSourceResolverRegistry({
          MediaSourceType.platformGallery: _PerItemResolver(answers),
        }),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ValueListenableBuilder<String>(
        valueListenable: itemId,
        builder: (context, id, _) => MediaItemView(
          item: _item(id),
          thumbnail: true,
          onImageReady: onReady,
          onImageFailed: onFailed,
        ),
      ),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
  }

  testWidgets('an item swapped out before the frame does not report the old '
      'image as ready', (tester) async {
    final ready = <Size>[];
    final itemId = ValueNotifier('wide');
    await tester.runAsync(() async {
      await tester.pumpWidget(
        app(
          {
            'wide': BytesData(bytes: _png(120, 40)),
            'tall': BytesData(bytes: _png(40, 120)),
          },
          itemId,
          onReady: (_, size) => ready.add(size),
        ),
      );
      // Resolved and drawn: the image starts decoding.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      // Decoded, its report waiting for the next frame...
      await Future<void>.delayed(const Duration(milliseconds: 300));
      // ...which builds the view for another item first.
      itemId.value = 'tall';
      await tester.pump();
      await settle(tester);
    });

    expect(ready, hasLength(1));
    expect(ready.single.aspectRatio, closeTo(40 / 120, 0.01));
  });

  testWidgets('a photo that cannot be found reports a failure, once', (
    tester,
  ) async {
    var failures = 0;
    final ready = <Size>[];
    await tester.runAsync(() async {
      await tester.pumpWidget(
        app(
          {'gone': const UnavailableData(kind: UnavailableKind.notFound)},
          ValueNotifier('gone'),
          onReady: (_, size) => ready.add(size),
          onFailed: () => failures++,
        ),
      );
      await settle(tester);
      // Rebuilds draw the same answer and say nothing more.
      await tester.pump();
    });

    expect(failures, 1);
    expect(ready, isEmpty);
  });

  testWidgets('a photo the diver has not given access to reports a failure', (
    tester,
  ) async {
    var failures = 0;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        app(
          {'denied': const UnavailableData(kind: UnavailableKind.accessDenied)},
          ValueNotifier('denied'),
          onFailed: () => failures++,
        ),
      );
      await settle(tester);
    });

    expect(failures, 1);
  });

  testWidgets('a resolver that throws reports a failure, once', (tester) async {
    var failures = 0;
    await tester.runAsync(() async {
      // No answer for this id: the resolver's lookup throws.
      await tester.pumpWidget(
        app(const {}, ValueNotifier('broken'), onFailed: () => failures++),
      );
      await settle(tester);
      await tester.pump();
    });

    expect(failures, 1);
  });

  testWidgets('a photo still downloading is not a failure', (tester) async {
    var failures = 0;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        app(
          {'later': const UnavailableData(kind: UnavailableKind.stillFetching)},
          ValueNotifier('later'),
          onFailed: () => failures++,
        ),
      );
      await settle(tester);
    });

    expect(failures, 0);
  });

  testWidgets('bytes that do not decode report a failure', (tester) async {
    var failures = 0;
    final ready = <Size>[];
    await tester.runAsync(() async {
      await tester.pumpWidget(
        app(
          {
            'corrupt': BytesData(bytes: Uint8List.fromList([1, 2, 3, 4, 5])),
          },
          ValueNotifier('corrupt'),
          onReady: (_, size) => ready.add(size),
          onFailed: () => failures++,
        ),
      );
      await settle(tester);
    });
    // The Image widget reports the broken bytes too; that is expected.
    tester.takeException();

    expect(failures, 1);
    expect(ready, isEmpty);
  });

  testWidgets('a photo that draws reports no failure', (tester) async {
    var failures = 0;
    final ready = <Size>[];
    await tester.runAsync(() async {
      await tester.pumpWidget(
        app(
          {'ok': BytesData(bytes: _png(60, 40))},
          ValueNotifier('ok'),
          onReady: (_, size) => ready.add(size),
          onFailed: () => failures++,
        ),
      );
      await settle(tester);
    });

    expect(ready, hasLength(1));
    expect(failures, 0);
  });
}
