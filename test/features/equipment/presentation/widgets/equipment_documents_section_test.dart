import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_media_sitting.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_documents_section.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_unlink_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/presentation/providers/equipment_media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart' show Override;
import '../../../media/presentation/support/media_widget_harness.dart';

/// Repository stub so nothing under test reaches a database.
class _StubMediaRepository extends MediaRepository {
  @override
  Future<List<MediaItem>> getMediaForEquipment(String equipmentId) async =>
      const <MediaItem>[];
}

/// Records the ids anything asks to detach: a held remove asks none.
class _RecordingUnlinkService extends MediaUnlinkService {
  _RecordingUnlinkService({required this.calls})
    : super(repository: _StubMediaRepository(), deleteMedia: (_) async {});

  final List<List<String>> calls;

  @override
  Future<EquipmentUnlinkOutcome> unlinkFromEquipment(
    List<String> mediaIds,
  ) async {
    calls.add(List<String>.of(mediaIds));
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
    void Function(MediaItem)? onOpen,
    List<Override> extraOverrides = const [],
    EditSession<EquipmentItem>? editing,
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
            onOpenDocument: onOpen,
            editing: editing,
          ),
        ),
      ),
    );
  }

  // Where the item page edits in place and is locked (issue #4527, phase
  // 3): the files still open, and none can be removed.
  testWidgets('locked, a file can be opened but not removed', (tester) async {
    final opened = <MediaItem>[];
    await tester.pumpWidget(
      await host(documents: [invoice], onOpen: opened.add),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsNothing);
    await tester.tap(find.text('invoice.pdf'));
    await tester.pumpAndSettle();
    expect(opened.single.id, 'doc-1');
  });

  testWidgets('nothing linked shows no card at all', (tester) async {
    await tester.pumpWidget(await host());
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsNothing);
    expect(find.text('Linked files'), findsNothing);
  });

  testWidgets('legacy card lists only non-photo leftovers', (tester) async {
    // Gear photos (issue #3355) belong to the Photos card and the check-ins.
    final photo = testMediaItem(
      id: 'photo-1',
      originalFilename: 'label.png',
    ).copyWith(equipmentId: 'e1');
    await tester.pumpWidget(await host(documents: [invoice, photo]));
    await tester.pumpAndSettle();

    expect(find.text('invoice.pdf'), findsOneWidget);
    expect(find.text('label.png'), findsNothing);
  });

  testWidgets('only gear photos linked shows no card at all', (tester) async {
    final photo = testMediaItem(
      id: 'photo-1',
      originalFilename: 'label.png',
    ).copyWith(equipmentId: 'e1');
    await tester.pumpWidget(await host(documents: [photo]));
    await tester.pumpAndSettle();

    expect(find.text('Linked files'), findsNothing);
  });

  testWidgets('files left behind are listed as Linked files', (tester) async {
    await tester.pumpWidget(await host(documents: [invoice, warranty]));
    await tester.pumpAndSettle();

    expect(find.text('Linked files'), findsOneWidget);
    expect(
      find.text('Too large, or a format Documents cannot hold'),
      findsOneWidget,
    );
    expect(find.text('invoice.pdf'), findsOneWidget);
    expect(find.text('warranty.docx'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('equipment-document-doc-1')),
      findsOneWidget,
    );
    // A PDF gets the PDF glyph; anything else is a generic document.
    expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
    expect(find.byIcon(Icons.description), findsOneWidget);
  });

  testWidgets('there is no attach action: paperwork goes to Documents', (
    tester,
  ) async {
    await tester.pumpWidget(await host(documents: [invoice]));
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
      await host(documents: [invoice], onOpen: opened.add),
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

  testWidgets('nothing shows while loading: most gear has no linked files', (
    tester,
  ) async {
    final completer = Completer<List<MediaItem>>();
    await tester.pumpWidget(await host(pending: completer.future));
    await tester.pump();

    expect(find.byType(Card), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    completer.complete([invoice]);
    await tester.pumpAndSettle();
    expect(find.text('Linked files'), findsOneWidget);
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

  // The open Legacy files card (issue #4527, phase 3).
  testWidgets('in a sitting, a remove asks nothing and is held until Save', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final session = EditSession(
      const EquipmentItem(id: 'e1', name: 'Reg', type: EquipmentType.regulator),
    );
    addTearDown(session.dispose);
    holdLegacyFiles(session, SittingMediaWriters.forEquipment(container.read));
    final calls = <List<String>>[];
    await tester.pumpWidget(
      await host(
        documents: [invoice, warranty],
        editing: session,
        extraOverrides: [
          mediaUnlinkServiceProvider.overrideWithValue(
            _RecordingUnlinkService(calls: calls),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(calls, isEmpty);
    expect(heldLegacyFileUnlinks(session), {'doc-1'});
    expect(session.changedCardIds, {'legacyFiles'});
    expect(find.text('invoice.pdf'), findsNothing);
    expect(find.text('warranty.docx'), findsOneWidget);
  });
}
