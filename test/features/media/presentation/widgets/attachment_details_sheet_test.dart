import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:submersion/features/media/domain/value_objects/attachment_details_edit.dart';
import 'package:submersion/features/media/presentation/providers/site_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/attachment_details_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart' show getBaseOverrides;

import '../support/media_widget_harness.dart';

class _StubMediaRepository extends MediaRepository {
  @override
  Future<List<MediaItem>> getMediaForSite(String siteId) async => const [];
}

class _RecordingNotifier extends SiteMediaListNotifier {
  _RecordingNotifier(Ref ref, this.saves, {this.failWith})
    : super(_StubMediaRepository(), ref, 's1');

  final List<(String, AttachmentDetailsEdit)> saves;
  final Object? failWith;

  @override
  Future<void> setAttachmentDetails(
    String id,
    AttachmentDetailsEdit edit,
  ) async {
    saves.add((id, edit));
    if (failWith != null) throw failWith!;
  }
}

/// Issue #1039: Edit details sets an attachment's category and overrides its
/// display size. It never renames: the stored filename is how other devices
/// and the repair wizard find the file.
class _GatedNotifier extends SiteMediaListNotifier {
  _GatedNotifier(Ref ref, this.gate) : super(_StubMediaRepository(), ref, 's1');

  final Future<void> gate;

  @override
  Future<void> setAttachmentDetails(String id, AttachmentDetailsEdit edit) =>
      gate;
}

void main() {
  late List<(String, AttachmentDetailsEdit)> saves;
  MediaItem? result;

  setUp(() {
    saves = [];
    result = null;
  });

  Future<void> open(
    WidgetTester tester,
    MediaItem item, {
    Object? failWith,
  }) async {
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [
          siteMediaListNotifierProvider('s1').overrideWith(
            (ref) => _RecordingNotifier(ref, saves, failWith: failWith),
          ),
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showAttachmentDetailsSheet(
                context,
                item: item,
                siteId: 's1',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> chooseCategory(WidgetTester tester, String label) async {
    await tester.tap(find.text('Uncategorized'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  final pdf = testMediaItem(
    id: 'm1',
    siteId: 's1',
    mediaType: MediaType.document,
    originalFilename: 'scan_0042.pdf',
  );

  testWidgets('saves only what changed and returns the saved item', (
    tester,
  ) async {
    await open(tester, pdf);
    await chooseCategory(tester, 'Site map');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final (id, edit) = saves.single;
    expect(id, 'm1');
    expect(edit.category!.value, SiteAttachmentCategory.siteMap);
    expect(edit.displaySize, isNull);
    expect(result!.siteCategory, SiteAttachmentCategory.siteMap);
    expect(find.text('Attachment details'), findsNothing);
  });

  testWidgets('offers no way to rename', (tester) async {
    await open(tester, pdf);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('scan_0042.pdf'), findsOneWidget);
  });
  testWidgets('the default size segment follows the chosen category', (
    tester,
  ) async {
    await open(tester, pdf);
    expect(find.text('Default (Tile)'), findsOneWidget);
    await chooseCategory(tester, 'Parking');
    expect(find.text('Default (Large)'), findsOneWidget);
  });

  testWidgets('choosing Large stores an override', (tester) async {
    await open(tester, pdf);
    await tester.tap(find.text('Default (Tile)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Large').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saves.single.$2.displaySize!.value, AttachmentDisplaySize.large);
  });

  testWidgets('a failed save keeps the sheet open and says why', (
    tester,
  ) async {
    await open(tester, pdf, failWith: StateError('gone'));
    await chooseCategory(tester, 'Parking');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't save"), findsOneWidget);
    expect(find.text('Attachment details'), findsOneWidget);
    expect(result, isNull);
  });

  // Three segments could not hold "Default (Large)" at phone width; the
  // longest translations are the real test.
  for (final lang in ['en', 'hu', 'de', 'fr', 'es', 'nl']) {
    testWidgets('fits a 320 px phone in $lang', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: await getBaseOverrides(),
          child: MaterialApp(
            locale: Locale(lang),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AttachmentDetailsSheet(
                item: pdf.copyWith(
                  originalFilename: 'a_long_site_map_name_for_the_reef.pdf',
                  siteCategory: SiteAttachmentCategory.anchorage,
                ),
                siteId: 's1',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('a sheet dismissed mid-save leaves the page underneath', (
    tester,
  ) async {
    final gate = Completer<void>();
    await tester.pumpWidget(
      await mediaTestApp(
        overrides: [
          siteMediaListNotifierProvider(
            's1',
          ).overrideWith((ref) => _GatedNotifier(ref, gate.future)),
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showAttachmentDetailsSheet(context, item: pdf, siteId: 's1'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await chooseCategory(tester, 'Parking');
    await tester.tap(find.text('Save'));
    await tester.pump();
    // Dismiss by tapping the barrier above the sheet while the save runs.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Attachment details'), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('Cancel writes nothing', (tester) async {
    await open(tester, pdf);
    await chooseCategory(tester, 'Parking');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(saves, isEmpty);
    expect(result, isNull);
  });
}
