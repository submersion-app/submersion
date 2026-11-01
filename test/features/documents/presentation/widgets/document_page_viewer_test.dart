import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/document_page_viewer.dart';

import '../../../../helpers/test_app.dart';
import '../../document_repository_doubles.dart';

DocumentPage _stored(
  String id, {
  String mimeType = 'image/jpeg',
  String fileName = 'scan.jpg',
  DateTime? updatedAt,
}) => DocumentPage(
  id: id,
  documentId: 'x',
  pageIndex: 0,
  fileName: fileName,
  mimeType: mimeType,
  sizeBytes: 2,
  createdAt: DateTime(2026),
  updatedAt: updatedAt ?? DateTime(2026),
);

/// The viewer's content loading (issue #3847): what it reads is bounded by
/// the page on screen and its neighbours, not by the document.
void main() {
  Widget viewer(FakeDocumentContent repo, List<DocumentPage> pages) => testApp(
    locale: const Locale('en'),
    overrides: [documentRepositoryProvider.overrideWithValue(repo)],
    child: DocumentPageViewer(pages: pages),
  );

  List<DocumentPage> scans(int count) => [
    for (var i = 0; i < count; i++) _stored('p$i'),
  ];

  Future<void> swipeForward(WidgetTester t) async {
    await t.fling(find.byType(PageView), const Offset(-600, 0), 2000);
    await t.pumpAndSettle();
  }

  bool holds(WidgetTester t, DocumentPage page) => ProviderScope.containerOf(
    t.element(find.byType(DocumentPageViewer)),
  ).exists(documentPageContentProvider(page.contentKey));

  for (final count in [1, 10, 50]) {
    testWidgets('opening $count pages reads no more than the first two', (
      t,
    ) async {
      final repo = FakeDocumentContent();
      await t.pumpWidget(viewer(repo, scans(count)));
      await t.pumpAndSettle();
      expect(repo.reads, ['p0', if (count > 1) 'p1']);
    });
  }

  testWidgets('a swipe reads ahead and lets go of what it leaves behind', (
    t,
  ) async {
    final repo = FakeDocumentContent();
    final pages = scans(50);
    await t.pumpWidget(viewer(repo, pages));
    await t.pumpAndSettle();

    await swipeForward(t);
    expect(repo.reads, ['p0', 'p1', 'p2']);
    expect(holds(t, pages[0]), isTrue);

    await swipeForward(t);
    await t.pumpAndSettle();
    expect(find.text('3 of 50'), findsOneWidget);
    expect(repo.reads, ['p0', 'p1', 'p2', 'p3']);
    expect(holds(t, pages[0]), isFalse);
    expect(
      [for (final p in pages.skip(1).take(3)) holds(t, p)],
      [true, true, true],
    );
    expect(pages.skip(4).where((p) => holds(t, p)), isEmpty);
  });

  testWidgets('swiping back reads a released page again', (t) async {
    final repo = FakeDocumentContent();
    await t.pumpWidget(viewer(repo, scans(5)));
    await t.pumpAndSettle();
    await swipeForward(t);
    await swipeForward(t);
    repo.reads.clear();

    await t.fling(find.byType(PageView), const Offset(600, 0), 2000);
    await t.pumpAndSettle();
    expect(find.text('2 of 5'), findsOneWidget);
    expect(repo.reads, ['p0']);
  });

  testWidgets('a page list that kept its pages reads nothing again', (t) async {
    final repo = FakeDocumentContent();
    await t.pumpWidget(viewer(repo, scans(3)));
    await t.pumpAndSettle();
    repo.reads.clear();

    // What an unrelated write leaves: the same pages in a new list.
    await t.pumpWidget(viewer(repo, scans(3)));
    await t.pumpAndSettle();
    expect(repo.reads, isEmpty);
  });

  testWidgets('a page whose content changed is read again', (t) async {
    final repo = FakeDocumentContent();
    await t.pumpWidget(viewer(repo, [_stored('p0')]));
    await t.pumpAndSettle();
    repo.reads.clear();

    await t.pumpWidget(
      viewer(repo, [_stored('p0', updatedAt: DateTime(2027))]),
    );
    await t.pumpAndSettle();
    expect(repo.reads, ['p0']);
  });

  testWidgets('a Word page reads nothing to show its file tile', (t) async {
    final repo = FakeDocumentContent();
    await t.pumpWidget(
      viewer(repo, [
        _stored('p0', mimeType: 'application/msword', fileName: 'policy.doc'),
        _stored('p1', mimeType: 'text/plain', fileName: 'notes.txt'),
      ]),
    );
    await t.pumpAndSettle();
    expect(find.text('policy.doc'), findsOneWidget);
    expect(find.text('Open with...'), findsOneWidget);
    expect(repo.reads, isEmpty);
  });

  testWidgets('an image waits for its content, then zooms', (t) async {
    final repo = FakeDocumentContent();
    await t.pumpWidget(viewer(repo, [_stored('p0')]));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await t.pump();
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('a corrupt image shows a placeholder', (t) async {
    await t.pumpWidget(viewer(FakeDocumentContent(), [_stored('p0')]));
    await t.pumpAndSettle();
    expect(find.text("Can't display this page"), findsOneWidget);
  });

  testWidgets('content that cannot be read shows a placeholder', (t) async {
    await t.pumpWidget(
      viewer(FakeDocumentContent(failing: true), [_stored('p0')]),
    );
    await t.pumpAndSettle();
    expect(find.text("Can't display this page"), findsOneWidget);
  });
}
