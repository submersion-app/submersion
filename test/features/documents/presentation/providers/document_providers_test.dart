import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/domain/document_expiry.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/notifications/data/services/notification_scheduler.dart';
import 'package:submersion/features/notifications/presentation/providers/notification_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../document_repository_doubles.dart';

/// Records which documents had their reminders rescheduled.
class _RecordingScheduler extends NotificationScheduler {
  final updated = <String>[];

  @override
  Future<void> updateForDocument(
    Document document,
    AppSettings settings,
  ) async => updated.add(document.id);
}

DocumentPage _scan(List<int> bytes) => DocumentPage(
  id: '',
  documentId: '',
  pageIndex: 0,
  fileName: 'scan.jpg',
  mimeType: 'image/jpeg',
  sizeBytes: bytes.length,
  bytes: Uint8List.fromList(bytes),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 1, 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Document doc(DocumentType type, DateTime? expiry, String title) {
    final now = DateTime.now();
    return Document(
      id: '',
      diverId: 'd1',
      owner: const DocumentOwner.personal(),
      type: type,
      title: title,
      expiryDate: expiry,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('page content (issue #3847)', () {
    late DocumentReadSpy repo;
    late ProviderContainer c;

    setUp(() {
      repo = DocumentReadSpy();
      c = ProviderContainer(
        overrides: [documentRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
    });

    Future<List<DocumentPage>> settledPages(String id) async {
      await pumpEventQueue();
      return c.read(documentPagesProvider(id).future);
    }

    test('the page list holds no content; a page reads its own', () async {
      final saved = await repo.save(doc(DocumentType.permit, null, 'p'), [
        _scan([1, 2]),
      ]);
      c.listen(documentPagesProvider(saved.id), (_, _) {});
      final page = (await settledPages(saved.id)).single;
      expect(page.bytes, isNull);
      expect(repo.contentReads, isEmpty);

      expect(
        await c.read(documentPageContentProvider(page.contentKey).future),
        [1, 2],
      );
    });

    test('a title edit does not read a loaded page again', () async {
      final saved = await repo.save(doc(DocumentType.permit, null, 'p'), [
        _scan([1, 2]),
      ]);
      c.listen(documentPagesProvider(saved.id), (_, _) {});
      final pages = await settledPages(saved.id);
      final key = pages.single.contentKey;
      c.listen(documentPageContentProvider(key), (_, _) {});
      await c.read(documentPageContentProvider(key).future);
      expect(repo.contentReads, hasLength(1));

      await repo.save(saved.copyWith(title: 'renamed'), pages);

      expect((await settledPages(saved.id)).single.contentKey, key);
      expect(await c.read(documentPageContentProvider(key).future), [1, 2]);
      expect(repo.contentReads, hasLength(1));
    });

    test('a content write in the same millisecond gets a new key', () async {
      final saved = await repo.save(doc(DocumentType.permit, null, 'p'), [
        _scan([1, 2]),
      ]);
      c.listen(documentPagesProvider(saved.id), (_, _) {});
      final page = (await settledPages(saved.id)).single;

      await repo.save(saved, [
        page.copyWith(bytes: Uint8List.fromList([3])),
      ]);
      // Puts the clock back: the second write stamped the first's millisecond.
      await DatabaseService.instance.database.customStatement(
        'UPDATE document_pages SET updated_at = ? WHERE id = ?',
        [page.updatedAt.millisecondsSinceEpoch, page.id],
      );

      final changed = (await settledPages(saved.id)).single;
      expect(changed.updatedAt, page.updatedAt);
      expect(changed.contentKey, isNot(page.contentKey));
      expect(
        await c.read(documentPageContentProvider(changed.contentKey).future),
        [3],
      );
    });

    test('releasing a page drops its decoded images from the cache', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final saved = await repo.save(doc(DocumentType.permit, null, 'p'), [
        _scan([1, 2]),
      ]);
      final page = (await repo.getPages(saved.id, withBytes: false)).single;
      final provider = documentPageContentProvider(page.contentKey);
      final held = c.listen(provider, (_, _) {});
      final bytes = (await c.read(provider.future))!;

      final cache = PaintingBinding.instance.imageCache;
      final keys = [
        for (final image in <ImageProvider>[
          MemoryImage(bytes),
          ResizeImage.resizeIfNeeded(
            documentPageStripImageWidth,
            null,
            MemoryImage(bytes),
          ),
          ResizeImage.resizeIfNeeded(
            documentPageThumbnailImageWidth,
            null,
            MemoryImage(bytes),
          ),
        ])
          await image.obtainKey(ImageConfiguration.empty),
      ];
      for (final key in keys) {
        cache.putIfAbsent(
          key,
          () => OneFrameImageStreamCompleter(Completer<ImageInfo>().future),
        );
      }
      expect(keys.where(cache.containsKey), hasLength(3));

      held.close();
      await pumpEventQueue();

      expect(c.exists(provider), isFalse);
      expect(keys.where(cache.containsKey), isEmpty);
    });

    test('new content gives the page a new key to read', () async {
      final saved = await repo.save(doc(DocumentType.permit, null, 'p'), [
        _scan([1, 2]),
      ]);
      c.listen(documentPagesProvider(saved.id), (_, _) {});
      final page = (await settledPages(saved.id)).single;

      // Saves stamp milliseconds: the second must land on a later one.
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await repo.save(saved, [
        page.copyWith(bytes: Uint8List.fromList([3])),
      ]);

      final changed = (await settledPages(saved.id)).single;
      expect(changed.contentKey, isNot(page.contentKey));
      expect(
        await c.read(documentPageContentProvider(changed.contentKey).future),
        [3],
      );
    });
  });

  test('attention list excludes insurance and sorts expired first', () async {
    final c = container();
    final now = DateTime.now();
    DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);
    final mutations = c.read(documentMutationsProvider);
    await mutations.save(doc(DocumentType.insurance, day(-1), 'ins'), const []);
    await mutations.save(doc(DocumentType.permit, day(5), 'permit'), const []);
    await mutations.save(
      doc(DocumentType.medicalClearance, day(-2), 'med'),
      const [],
    );
    await mutations.save(doc(DocumentType.other, day(400), 'far'), const []);
    final list = await c.read(attentionDocumentsProvider.future);
    expect([for (final (d, _) in list) d.title], ['med', 'permit']);
    expect(list.first.$2.kind, DocumentExpiryKind.expired);
  });

  test('owner, all and by-id providers see a saved document', () async {
    final c = container();
    final saved = await c
        .read(documentMutationsProvider)
        .save(doc(DocumentType.permit, null, 'Park'), const []);
    expect(
      await c.read(
        documentsForOwnerProvider(const DocumentOwner.personal()).future,
      ),
      hasLength(1),
    );
    expect(await c.read(allDocumentsProvider.future), hasLength(1));
    expect(
      (await c.read(documentByIdProvider(saved.id).future))!.title,
      'Park',
    );
  });

  test('restoring a snapshot puts the documents back and re-arms their '
      'reminders, which the delete cancelled', () async {
    final scheduler = _RecordingScheduler();
    final c = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        notificationSchedulerProvider.overrideWithValue(scheduler),
      ],
    );
    addTearDown(c.dispose);
    final now = DateTime.now();
    final repo = c.read(documentRepositoryProvider);
    final permit = await repo.save(
      doc(
        DocumentType.permit,
        DateTime(now.year, now.month, now.day + 60),
        'Park',
      ),
      const [],
    );
    final captured = [
      (
        document: permit,
        pages: const <DocumentPage>[],
        tagIds: const <String>[],
      ),
    ];
    await repo.delete(permit.id);

    await c.read(documentMutationsProvider).restoreSnapshot(captured);

    expect(await repo.getById(permit.id), isNotNull);
    expect(scheduler.updated, [permit.id]);
  });

  test('delete removes the document', () async {
    final c = container();
    final mutations = c.read(documentMutationsProvider);
    final saved = await mutations.save(
      doc(DocumentType.permit, null, 'Park'),
      const [],
    );
    await mutations.delete(saved.id);
    expect(await c.read(documentByIdProvider(saved.id).future), isNull);
  });

  test('the list and detail labels follow a renamed owner (#3391)', () async {
    final c = container();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      'INSERT INTO dive_sites (id, diver_id, name, created_at, updated_at) '
      "VALUES ('s1', 'd1', 'Blue Hole', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dives (id, diver_id, dive_number, dive_date_time, site_id, '
      "created_at, updated_at) VALUES ('v1', 'd1', 142, 0, 's1', 0, 0)",
    );
    final saved = await c
        .read(documentMutationsProvider)
        .save(
          doc(
            DocumentType.other,
            null,
            'Log',
          ).copyWith(owner: const DocumentOwner(DocumentOwnerKind.dive, 'v1')),
          const [],
        );
    final all = c.listen(allDocumentsProvider, (_, _) {});
    final one = c.listen(documentEntryProvider(saved.id), (_, _) {});
    expect(
      (await c.read(allDocumentsProvider.future)).single.ownerLabel,
      '#142 · Blue Hole',
    );
    await c.read(documentEntryProvider(saved.id).future);
    // A table write Drift reports to listeners, as the site editor's is.
    await db
        .update(db.diveSites)
        .write(const DiveSitesCompanion(name: Value('Great Blue Hole')));
    // The owner tick is debounced so a sync's write burst refreshes once.
    await Future<void>.delayed(DiveRepository.changeTickDebounce * 2);
    expect(
      (await c.read(allDocumentsProvider.future)).single.ownerLabel,
      '#142 · Great Blue Hole',
    );
    expect(
      (await c.read(documentEntryProvider(saved.id).future))!.ownerLabel,
      '#142 · Great Blue Hole',
    );
    all.close();
    one.close();
  });
}
