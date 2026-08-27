import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/pages/document_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_bytes_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

MediaItem _doc({String? originDeviceId, String? originalFilename}) => MediaItem(
  id: 'doc-1',
  siteId: 'site-1',
  mediaType: MediaType.document,
  originalFilename: originalFilename,
  originDeviceId: originDeviceId,
  takenAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// The viewer never reaches PdfViewer here on purpose: pdfrx needs a
/// pdfium binary that flutter_test cannot load, and a failed init hangs
/// the calling future. Every override below therefore resolves to
/// unavailable, an error, or nothing at all.
///
/// Overriding [mediaBytesProvider] is also what pins the page to the right
/// resolution stack. It used to read [resolvedFullResolutionProvider], which
/// only ever looks a `platformAssetId` up in the photo library — an id no
/// document attachment carries — so every PDF opened to the unavailable
/// state (issue #1019). If the page regressed to that provider, the
/// pending-completer test below would show the unavailable state instead of
/// its spinner.
Widget _host(
  MediaItem item, {
  FutureOr<ResolvedAssetResult> Function(Ref ref)? resolve,
}) => ProviderScope(
  overrides: [
    mediaBytesProvider(item).overrideWith(
      resolve ??
          (ref) async =>
              const ResolvedAssetResult(status: ResolutionStatus.unavailable),
    ),
  ],
  child: MaterialApp(
    // flutter_test forwards the HOST locale list; without this pin the
    // English assertions below fail on a non-English dev machine.
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: DocumentViewerPage(item: item),
  ),
);

void main() {
  testWidgets('unavailable document shows the unavailable state', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_doc(originalFilename: 'reef-map.pdf')));
    await tester.pumpAndSettle();
    expect(find.text('reef-map.pdf'), findsOneWidget); // app bar title
    expect(
      find.text('This document is not available on this device'),
      findsOneWidget,
    );
    // No origin device known: the hint stays hidden.
    expect(find.textContaining('added from'), findsNothing);
  });

  testWidgets('origin-device hint shown when originDeviceId present', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(_doc(originalFilename: 'reef-map.pdf', originDeviceId: 'device-2')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('added from'), findsOneWidget);
  });

  testWidgets('shows a spinner while the bytes are still resolving', (
    tester,
  ) async {
    // Never completes: the page must stay in its loading branch.
    final pending = Completer<ResolvedAssetResult>();
    addTearDown(
      () => pending.complete(
        const ResolvedAssetResult(status: ResolutionStatus.unavailable),
      ),
    );

    await tester.pumpWidget(
      _host(
        _doc(originalFilename: 'reef-map.pdf'),
        resolve: (ref) => pending.future,
      ),
    );
    // Deliberately no pumpAndSettle: settling would never terminate.

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // The chrome is usable while the body loads.
    expect(find.text('reef-map.pdf'), findsOneWidget);
    expect(
      find.text('This document is not available on this device'),
      findsNothing,
    );
  });

  testWidgets('resolution error degrades to the unavailable state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _doc(originalFilename: 'reef-map.pdf', originDeviceId: 'device-2'),
        resolve: (ref) async => throw Exception('resolver exploded'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('This document is not available on this device'),
      findsOneWidget,
    );
    // The error path renders the same state, origin hint included.
    expect(find.textContaining('added from'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('app bar falls back to the generic title without a filename', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_doc()));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Document'), findsOneWidget);
  });

  testWidgets('sharing an unresolvable document reports it cannot be shared', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_doc(originalFilename: 'reef-map.pdf')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.share));
    await tester.pumpAndSettle();

    expect(find.text('Cannot share this photo'), findsOneWidget);
  });

  testWidgets('share surfaces the failure when resolution throws', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _doc(originalFilename: 'reef-map.pdf'),
        resolve: (ref) async => throw Exception('resolver exploded'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.share));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Failed to share: Exception: resolver exploded'),
      findsOneWidget,
    );
    expect(find.text('Cannot share this photo'), findsNothing);
  });
}
