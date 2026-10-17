import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../media_store/support/fake_local_file_resolver.dart';
import '../support/media_widget_harness.dart';

/// A tile coming back into view used to show the grey placeholder for a
/// frame or more while its file was looked up again, even though its decoded
/// image was still in memory (issue #3337).
void main() {
  late Directory dir;
  late File png;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('first_frame_test');
    png = File(p.join(dir.path, 'thumb.png'))..writeAsBytesSync(onePixelPng());
  });

  tearDown(() async {
    final cache = PaintingBinding.instance.imageCache;
    cache
      ..clear()
      ..clearLiveImages();
    await dir.delete(recursive: true);
  });

  Future<Widget> host(Widget child) async {
    final resolver = FakeLocalFileResolver(FileData(file: png));
    return ProviderScope(
      overrides: [
        ...await getBaseOverrides(),
        mediaSourceResolverRegistryProvider.overrideWithValue(
          MediaSourceResolverRegistry({MediaSourceType.localFile: resolver}),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  Widget tile(MediaItem item, {Key? key}) => SizedBox(
    key: key,
    width: 100,
    height: 100,
    child: MediaItemView(
      item: item,
      thumbnail: true,
      targetSize: const Size(200, 200),
    ),
  );

  bool paintsAnImage(WidgetTester tester) => tester
      .widgetList<RawImage>(find.byType(RawImage))
      .any((raw) => raw.image != null);

  /// Lets the file read and decode, which are real I/O, finish.
  Future<void> letImageLoad(WidgetTester tester) async {
    for (var i = 0; i < 40 && !paintsAnImage(tester); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }
  }

  testWidgets('a tile whose image is still in memory paints it on its first '
      'frame', (tester) async {
    final item = testMediaItem();
    await tester.pumpWidget(await host(tile(item, key: const ValueKey('a'))));
    await letImageLoad(tester);
    expect(paintsAnImage(tester), isTrue);

    // Scrolled away...
    await tester.pumpWidget(await host(const SizedBox.shrink()));
    expect(find.byType(MediaItemView), findsNothing);

    // ...and back: one frame, with the file lookup still in flight.
    await tester.pumpWidget(await host(tile(item, key: const ValueKey('b'))));

    expect(paintsAnImage(tester), isTrue);
    await tester.pumpAndSettle();
    expect(paintsAnImage(tester), isTrue);
  });

  testWidgets('an orphaned row shows the placeholder first, not a picture '
      'its resolution is likely to take back', (tester) async {
    final item = testMediaItem();
    await tester.pumpWidget(await host(tile(item, key: const ValueKey('a'))));
    await letImageLoad(tester);
    await tester.pumpWidget(await host(const SizedBox.shrink()));

    await tester.pumpWidget(
      await host(
        tile(item.copyWith(isOrphaned: true), key: const ValueKey('b')),
      ),
    );

    expect(paintsAnImage(tester), isFalse);
    await letImageLoad(tester);
  });

  testWidgets('a tile whose image is not in memory still shows the '
      'placeholder first', (tester) async {
    final item = testMediaItem();
    await tester.pumpWidget(await host(tile(item, key: const ValueKey('a'))));
    await letImageLoad(tester);
    await tester.pumpWidget(await host(const SizedBox.shrink()));
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();

    await tester.pumpWidget(await host(tile(item, key: const ValueKey('b'))));

    expect(paintsAnImage(tester), isFalse);
    await letImageLoad(tester);
    expect(paintsAnImage(tester), isTrue);
  });
}
