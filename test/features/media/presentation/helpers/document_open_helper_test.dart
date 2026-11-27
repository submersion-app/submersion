import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/helpers/document_open_helper.dart';
import 'package:submersion/features/media/presentation/pages/attachment_details_page.dart';
import 'package:submersion/features/media/presentation/pages/document_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_bytes_providers.dart';
import 'package:submersion/features/media/presentation/providers/photo_editing_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';

import '../support/media_widget_harness.dart';

/// Every document here resolves to "unavailable" on purpose: the routing
/// decision is what is under test, and real bytes would drag a PDF into
/// pdfrx, whose native binary flutter_test cannot load.
void main() {
  Future<void> pumpAndOpen(
    WidgetTester tester,
    MediaItem item, {
    String? editableSiteId,
  }) async {
    late WidgetRef capturedRef;
    late BuildContext capturedContext;

    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [
          mediaBytesProvider(item).overrideWith(
            (ref) async =>
                const ResolvedAssetResult(status: ResolutionStatus.unavailable),
          ),
          // A page with the attachment's lock reads its stored row; one
          // read as gone would close it.
          photoRecordProvider(item.id).overrideWith(
            (ref) async =>
                PhotoRecord(item: item, species: const [], people: const []),
          ),
        ],
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    // Deliberately not awaited: for a PDF, open() awaits Navigator.push,
    // which only completes when the pushed route is popped.
    unawaited(
      DocumentOpenHelper.open(
        capturedContext,
        capturedRef,
        item,
        editableSiteId: editableSiteId,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a PDF opens in the in-app document viewer', (tester) async {
    final pdf = testMediaItem(
      mediaType: MediaType.document,
      originalFilename: 'reef-map.pdf',
    );

    await pumpAndOpen(tester, pdf);

    expect(find.byType(DocumentViewerPage), findsOneWidget);
    expect(find.text('reef-map.pdf'), findsOneWidget);
  });

  testWidgets('a site PDF opens the viewer under its lock', (tester) async {
    final pdf = testMediaItem(
      siteId: 's1',
      mediaType: MediaType.document,
      originalFilename: 'reef-map.pdf',
    );

    await pumpAndOpen(tester, pdf, editableSiteId: 's1');

    final viewer = tester.widget<DocumentViewerPage>(
      find.byType(DocumentViewerPage),
    );
    expect(viewer.editableSiteId, 's1');
    expect(find.byKey(const ValueKey('document_unlock')), findsOneWidget);
  });

  testWidgets('a non-PDF document never reaches the in-app viewer', (
    tester,
  ) async {
    final doc = testMediaItem(
      mediaType: MediaType.document,
      originalFilename: 'briefing.txt',
    );

    await pumpAndOpen(tester, doc);

    // Routed to the external opener instead, which reports that these
    // bytes cannot be produced on this device.
    expect(find.byType(DocumentViewerPage), findsNothing);
    expect(
      find.text('This document is not available on this device'),
      findsOneWidget,
    );
  });

  testWidgets('a site document with no viewer opens its '
      'details page', (tester) async {
    final doc = testMediaItem(
      siteId: 's1',
      mediaType: MediaType.document,
      originalFilename: 'briefing.docx',
    );

    await pumpAndOpen(tester, doc, editableSiteId: 's1');

    expect(find.byType(AttachmentDetailsPage), findsOneWidget);
    expect(
      find.text('This document is not available on this device'),
      findsNothing,
    );
  });

  testWidgets('an extensionless document is treated as non-PDF', (
    tester,
  ) async {
    final doc = testMediaItem(
      mediaType: MediaType.document,
      originalFilename: 'README',
    );

    await pumpAndOpen(tester, doc);

    expect(find.byType(DocumentViewerPage), findsNothing);
  });
}
