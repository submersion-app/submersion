import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/widgets/media_reupload_menu.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import '../../helpers/in_memory_media_object_store.dart';

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late MediaStoreResolver resolver;

  setUp(() async {
    db = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
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

  // Its full-quality original is in the store.
  final uploadedOriginal = item.copyWith(
    remoteUploadedAt: DateTime(2026, 1, 2),
  );
  // Only a compressed copy is in the store.
  final renditionOnly = item.copyWith(
    remoteCompressedUploadedAt: DateTime(2026, 1, 2),
  );

  Widget host({
    required bool connected,
    required List<Object> recorded,
    MediaItem? photo,
    ValueNotifier<bool>? showButton,
    String? attachedStoreId,
  }) => ProviderScope(
    overrides: [
      mediaAttachedStoreIdProvider.overrideWith((ref) async => attachedStoreId),
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
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) => mediaReuploadAvailable(ref)
              // The viewer's controls can hide while a dialog is up.
              ? ValueListenableBuilder<bool>(
                  valueListenable: showButton ?? ValueNotifier(true),
                  builder: (_, shown, _) => !shown
                      ? const SizedBox.shrink()
                      : Builder(
                          builder: (anchor) => IconButton(
                            key: const Key('media-reupload-button'),
                            icon: const Icon(Icons.tune),
                            onPressed: () => showMediaReuploadMenu(
                              anchor,
                              ref,
                              photo ?? item,
                            ),
                          ),
                        ),
                )
              : const SizedBox.shrink(),
        ),
      ),
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

  // A compressed level for an uploaded original drops the full-quality
  // copy, so it asks first (issue #4527, media library decision 4).
  group('a downgrade of an uploaded original', () {
    Future<List<Object>> pick(
      WidgetTester tester,
      MediaItem photo,
      String level,
    ) async {
      final recorded = <Object>[];
      await tester.pumpWidget(
        host(connected: true, recorded: recorded, photo: photo),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('media-reupload-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(level).last);
      await tester.pumpAndSettle();
      return recorded;
    }

    testWidgets('asks; Replace queues it', (tester) async {
      final recorded = await pick(tester, uploadedOriginal, 'Balanced');
      expect(find.text('Replace the full-quality copy?'), findsOneWidget);
      expect(find.textContaining('with a Balanced copy'), findsOneWidget);
      expect(recorded, isEmpty);

      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();
      expect(recorded, [
        ['m1', MediaUploadQuality.balanced],
      ]);
      expect(find.text('Re-upload queued'), findsOneWidget);
    });

    testWidgets('Replace queues it even if the button hid meanwhile', (
      tester,
    ) async {
      final recorded = <Object>[];
      final showButton = ValueNotifier(true);
      addTearDown(showButton.dispose);
      await tester.pumpWidget(
        host(
          connected: true,
          recorded: recorded,
          photo: uploadedOriginal,
          showButton: showButton,
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('media-reupload-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Balanced').last);
      await tester.pumpAndSettle();

      showButton.value = false;
      await tester.pump();
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();

      expect(recorded, [
        ['m1', MediaUploadQuality.balanced],
      ]);
      expect(find.text('Re-upload queued'), findsOneWidget);
    });

    testWidgets('Cancel queues nothing', (tester) async {
      final recorded = await pick(tester, uploadedOriginal, 'Balanced');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(recorded, isEmpty);
      expect(find.text('Re-upload queued'), findsNothing);
    });

    testWidgets('Original queues at once', (tester) async {
      final recorded = await pick(tester, uploadedOriginal, 'Original');
      expect(find.text('Replace the full-quality copy?'), findsNothing);
      expect(recorded, [
        ['m1', MediaUploadQuality.original],
      ]);
    });

    // Stamps from another store say nothing about this one: the pipeline
    // leaves that store's original alone.
    testWidgets('an original uploaded to another store queues at once', (
      tester,
    ) async {
      final recorded = <Object>[];
      await tester.pumpWidget(
        host(
          connected: true,
          recorded: recorded,
          photo: uploadedOriginal.copyWith(remoteStoreId: 'store-a'),
          attachedStoreId: 'store-b',
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('media-reupload-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Small').last);
      await tester.pumpAndSettle();

      expect(find.text('Replace the full-quality copy?'), findsNothing);
      expect(recorded, [
        ['m1', MediaUploadQuality.small],
      ]);
    });

    testWidgets('a photo with only a compressed copy queues at once', (
      tester,
    ) async {
      final recorded = await pick(tester, renditionOnly, 'Small');
      expect(find.text('Replace the full-quality copy?'), findsNothing);
      expect(recorded, [
        ['m1', MediaUploadQuality.small],
      ]);
    });
  });
}
