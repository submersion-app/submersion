import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;

import 'package:submersion/features/equipment/presentation/widgets/equipment_documents_section.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_unlink_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/providers/equipment_media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

import '../../../../helpers/mock_providers.dart' show Override;
import '../../../media/presentation/support/media_widget_harness.dart';

/// Repository stub so nothing under test reaches a database.
class _StubMediaRepository extends MediaRepository {
  @override
  Future<List<MediaItem>> getMediaForEquipment(String equipmentId) async =>
      const <MediaItem>[];
}

/// Records the ids the section asks to detach, and can fail on demand.
class _RecordingUnlinkService extends MediaUnlinkService {
  _RecordingUnlinkService({required this.calls, this.failWith})
    : super(repository: _StubMediaRepository(), deleteMedia: (_) async {});

  final List<List<String>> calls;
  final Object? failWith;

  @override
  Future<EquipmentUnlinkOutcome> unlinkFromEquipment(
    List<String> mediaIds,
  ) async {
    calls.add(List<String>.of(mediaIds));
    if (failWith != null) throw failWith!;
    return EquipmentUnlinkOutcome(deleted: mediaIds.length, keptLinked: 0);
  }
}

void main() {
  final invoice = testMediaItem(
    id: 'doc-1',
    originalFilename: 'invoice.pdf',
    mediaType: MediaType.document,
  );
  final warranty = testMediaItem(
    id: 'doc-2',
    originalFilename: 'warranty.docx',
    mediaType: MediaType.document,
  );

  Future<Widget> host({
    List<MediaItem> documents = const [],
    Future<List<MediaItem>>? pending,
    Object? error,
    VoidCallback? onAttach,
    void Function(MediaItem)? onOpen,
    List<Override> extraOverrides = const [],
  }) {
    return mediaTestApp(
      overrides: [
        mediaForEquipmentProvider('e1').overrideWith((ref) {
          if (pending != null) return pending;
          if (error != null) throw error;
          return documents;
        }),
        ...extraOverrides,
      ],
      home: Scaffold(
        body: SingleChildScrollView(
          child: EquipmentDocumentsSection(
            equipmentId: 'e1',
            onAttachPressed: onAttach,
            onOpenDocument: onOpen,
          ),
        ),
      ),
    );
  }

  testWidgets('empty state names what belongs here', (tester) async {
    await tester.pumpWidget(await host(onAttach: () {}));
    await tester.pumpAndSettle();

    expect(find.text('Documents'), findsOneWidget);
    expect(
      find.text('Invoices, receipts and warranty paperwork'),
      findsOneWidget,
    );
    expect(find.text('No documents attached yet'), findsOneWidget);
  });

  testWidgets('renders a tile per attached document', (tester) async {
    await tester.pumpWidget(
      await host(documents: [invoice, warranty], onAttach: () {}),
    );
    await tester.pumpAndSettle();

    expect(find.text('invoice.pdf'), findsOneWidget);
    expect(find.text('warranty.docx'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('equipment-document-doc-1')),
      findsOneWidget,
    );
    // A PDF gets the PDF glyph; anything else is a generic document.
    expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
    expect(find.byIcon(Icons.description), findsOneWidget);
    expect(find.text('No documents attached yet'), findsNothing);
  });

  testWidgets('the attach action routes to its callback', (tester) async {
    var attaches = 0;
    await tester.pumpWidget(await host(onAttach: () => attaches++));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('equipment-documents-attach')));
    await tester.pumpAndSettle();

    expect(attaches, 1);
  });

  testWidgets('the attach action is hidden when no callback is given', (
    tester,
  ) async {
    await tester.pumpWidget(await host());
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('equipment-documents-attach')),
      findsNothing,
    );
  });

  testWidgets('tapping a document hands it to the open callback', (
    tester,
  ) async {
    final opened = <MediaItem>[];
    await tester.pumpWidget(
      await host(documents: [invoice], onAttach: () {}, onOpen: opened.add),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('invoice.pdf'));
    await tester.pumpAndSettle();

    expect(opened.map((m) => m.id), ['doc-1']);
  });

  testWidgets('a tile is inert when no open callback is wired', (tester) async {
    // A no-op onTap closure would still give the tile ripple feedback and a
    // tap target it cannot honour.
    await tester.pumpWidget(await host(documents: [invoice]));
    await tester.pumpAndSettle();

    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.onTap, isNull);
  });

  testWidgets('a tile is tappable once an open callback is wired', (
    tester,
  ) async {
    await tester.pumpWidget(await host(documents: [invoice], onOpen: (_) {}));
    await tester.pumpAndSettle();

    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(tile.onTap, isNotNull);
  });

  testWidgets('a still-loading provider shows a spinner', (tester) async {
    final completer = Completer<List<MediaItem>>();
    await tester.pumpWidget(await host(pending: completer.future));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(const []);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a failing provider reports rather than rendering empty', (
    tester,
  ) async {
    await tester.pumpWidget(await host(error: 'disk gone'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load documents'), findsOneWidget);
    // Not the empty state: "nothing attached" and "could not read" are
    // different facts and must not look alike.
    expect(find.text('No documents attached yet'), findsNothing);
  });

  group('remove', () {
    testWidgets('asks first and does nothing when cancelled', (tester) async {
      final calls = <List<String>>[];
      await tester.pumpWidget(
        await host(
          documents: [invoice],
          onAttach: () {},
          extraOverrides: [
            mediaUnlinkServiceProvider.overrideWithValue(
              _RecordingUnlinkService(calls: calls),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Remove document?'), findsOneWidget);
      expect(
        find.textContaining('Your original file is never touched'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
    });

    testWidgets('detaches the document once confirmed', (tester) async {
      final calls = <List<String>>[];
      await tester.pumpWidget(
        await host(
          documents: [invoice],
          onAttach: () {},
          extraOverrides: [
            mediaUnlinkServiceProvider.overrideWithValue(
              _RecordingUnlinkService(calls: calls),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(calls, [
        ['doc-1'],
      ]);
      expect(find.text('Document removed'), findsOneWidget);
    });

    testWidgets('leaves other equipment items alone', (tester) async {
      // The invalidation is scoped to this item's id. Invalidating the family
      // root would rebuild every other equipment item's list and count, and
      // each rebuild is a database read.
      final calls = <List<String>>[];
      var otherBuilds = 0;
      await tester.pumpWidget(
        await host(
          documents: [invoice],
          onAttach: () {},
          extraOverrides: [
            mediaForEquipmentProvider('other-equipment').overrideWith((
              ref,
            ) async {
              otherBuilds++;
              return const <MediaItem>[];
            }),
            mediaUnlinkServiceProvider.overrideWithValue(
              _RecordingUnlinkService(calls: calls),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // A LIVE listener, not a one-off read: an invalidated FutureProvider
      // with nothing listening simply drops its state and rebuilds lazily on
      // the next read, so a bare read would make this assertion vacuous --
      // it passes against the family-wide invalidation too. Verified both
      // directions.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(EquipmentDocumentsSection)),
      );
      final sub = container.listen(
        mediaForEquipmentProvider('other-equipment'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);
      await container.read(mediaForEquipmentProvider('other-equipment').future);
      expect(otherBuilds, 1);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(calls, [
        ['doc-1'],
      ]);
      expect(otherBuilds, 1, reason: 'unrelated equipment was rebuilt');
    });

    testWidgets('surfaces a failure instead of pretending it worked', (
      tester,
    ) async {
      final calls = <List<String>>[];
      await tester.pumpWidget(
        await host(
          documents: [invoice],
          onAttach: () {},
          extraOverrides: [
            mediaUnlinkServiceProvider.overrideWithValue(
              _RecordingUnlinkService(
                calls: calls,
                failWith: StateError('store offline'),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(calls, [
        ['doc-1'],
      ]);
      expect(
        find.textContaining('Could not remove the document'),
        findsOneWidget,
      );
      expect(find.text('Document removed'), findsNothing);
    });
  });
}
