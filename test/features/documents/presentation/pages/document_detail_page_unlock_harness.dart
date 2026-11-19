import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/theme/app_theme_registry.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/data/services/document_edit_save_service.dart';
import 'package:submersion/core/services/images/profile_photo_codec.dart';
import 'package:submersion/features/documents/data/services/document_page_capture.dart';
import 'package:submersion/features/documents/presentation/editing/document_pages_card_editor.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/editing/document_record.dart';
import 'package:submersion/features/documents/presentation/pages/document_detail_page.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/providers/document_record_provider.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_link_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../document_repository_doubles.dart';

/// The document the page shows, as stored: an insurance kept as its numbers
/// alone (no pages), so the details fill the page.
final travel = Document(
  id: 'doc',
  diverId: 'd1',
  owner: const DocumentOwner.personal(),
  type: DocumentType.insurance,
  title: 'Travel',
  issuer: 'DAN',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

DocumentPage storedPage(int index) => DocumentPage(
  id: 'pg$index',
  documentId: 'doc',
  pageIndex: index,
  fileName: 'p$index.jpg',
  mimeType: 'image/jpeg',
  sizeBytes: 2,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// Records each save the page asks for, stores its result where the page
/// reads the record from, and can fail.
class FakeDocumentSave implements DocumentEditSaveService {
  FakeDocumentSave(this.stored);

  final StateController<DocumentRecord?> stored;
  final calls = <({DocumentRecord after, Set<String> cards})>[];
  bool fail = false;

  @override
  Future<({DocumentRecord before, DocumentRecord after})?> save({
    required String documentId,
    required DocumentRecord Function(DocumentRecord stored) apply,
    required Iterable<String> changedCardIds,
  }) async {
    if (fail) throw StateError('the save failed');
    final before = stored.state!;
    final after = apply(before);
    calls.add((after: after, cards: changedCardIds.toSet()));
    stored.state = after;
    return (before: before, after: after);
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records deletes, and re-arms nothing, instead of touching a database.
class FakeDocumentMutations extends DocumentMutations {
  FakeDocumentMutations(super.ref);

  final deleted = <String>[];

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  Future<void> rearmReminders(Iterable<Document> documents) async {}
}

/// What a test pumped: the fake save, the stored record to change
/// underneath, and the deletes.
class DocumentPageHarness {
  DocumentPageHarness(this.save, this.stored, this.mutations);

  final FakeDocumentSave save;
  final StateController<DocumentRecord?> stored;
  final FakeDocumentMutations mutations;
}

final _storedProvider = StateProvider<DocumentRecord?>((ref) => null);

/// Pumps the document page with the phase 3 switch on (unless
/// [unlockEditing] is false), at [size].
Future<DocumentPageHarness> pumpDocumentPage(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  Document? document,
  List<DocumentPage> pages = const [],
  List<String>? tagIds = const [],
  bool unlockEditing = true,
  bool openUnlocked = false,
  bool embedded = false,
  VoidCallback? onSittingEnded,
  Size size = const Size(600, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final doc = document ?? travel;
  final record = DocumentRecord(document: doc, pages: pages, tagIds: tagIds);
  final overrides = await getBaseOverrides();
  late DocumentPageHarness harness;
  late FakeDocumentMutations mutations;
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        ...overrides,
        _storedProvider.overrideWith((ref) => record),
        documentRecordProvider(
          doc.id,
        ).overrideWith((ref) async => ref.watch(_storedProvider)),
        documentEntryProvider(doc.id).overrideWith((ref) async {
          final now = ref.watch(_storedProvider)?.document ?? doc;
          return DocumentListEntry(now, null, pages.length);
        }),
        documentPagesProvider(doc.id).overrideWith((ref) async => pages),
        documentRepositoryProvider.overrideWithValue(FakeDocumentContent()),
        documentPageCaptureProvider.overrideWithValue(
          DocumentPageCapture(
            pickFile: (_) async =>
                (bytes: Uint8List.fromList([1, 2]), name: 'scan.png'),
            pickImage: (_) async => (bytes: Uint8List(4), name: 'shot.jpg'),
            encode: (p) async => (
              outcome: ImageEncodeOutcome.encoded,
              bytes: Uint8List.fromList([9]),
            ),
          ),
        ),
        tagsForItemProvider((
          scope: TagScope.documents,
          itemId: doc.id,
        )).overrideWith((ref) async => const <Tag>[]),
        documentMutationsProvider.overrideWith(
          (ref) => mutations = FakeDocumentMutations(ref),
        ),
        documentEditSaveServiceProvider.overrideWith((ref) {
          final save = FakeDocumentSave(ref.watch(_storedProvider.notifier));
          harness = DocumentPageHarness(
            save,
            ref.watch(_storedProvider.notifier),
            mutations,
          );
          return save;
        }),
      ],
      child: Theme(
        // The app's own theme, light or dark.
        data: AppThemeRegistry.resolveTheme(
          AppThemeRegistry.presets.first,
          brightness,
        ),
        child: DocumentDetailPage(
          documentId: doc.id,
          unlockEditing: unlockEditing,
          openUnlocked: openUnlocked,
          embedded: embedded,
          onSittingEnded: onSittingEnded,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(DocumentDetailPage)),
  );
  container.read(documentMutationsProvider);
  container.read(documentEditSaveServiceProvider);
  return harness;
}
