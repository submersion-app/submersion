import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/widgets/media_reupload_button.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import '../../helpers/in_memory_media_object_store.dart';

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late MediaStoreResolver resolver;

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('reupload_btn');
    resolver = MediaStoreResolver(
      store: InMemoryMediaObjectStore(),
      cache: MediaCacheStore(database: db, root: root),
    );
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  final item = MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    takenAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Widget host({required bool connected, required List<Object> recorded}) =>
      ProviderScope(
        overrides: [
          mediaStoreResolverProvider.overrideWith(
            (ref) => connected ? resolver : null,
          ),
          mediaStoreReuploadProvider.overrideWithValue(
            (String mediaId, MediaUploadQuality level) async =>
                recorded.add([mediaId, level]),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MediaReuploadButton(item: item)),
        ),
      );

  testWidgets('hidden when no store is connected', (tester) async {
    await tester.pumpWidget(host(connected: false, recorded: []));
    await tester.pump();
    expect(find.byKey(const Key('media-reupload-button')), findsNothing);
  });

  testWidgets('picking a level calls the reupload provider', (tester) async {
    final recorded = <Object>[];
    await tester.pumpWidget(host(connected: true, recorded: recorded));
    await tester.pump();
    await tester.tap(find.byKey(const Key('media-reupload-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Small').last);
    await tester.pumpAndSettle();
    expect(recorded, [
      ['m1', MediaUploadQuality.small],
    ]);
  });
}
