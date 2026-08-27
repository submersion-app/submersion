import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/pages/photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/perdix_face.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

/// The Perdix face defaults to the top-right corner, which is where the
/// viewer's toolbar keeps its action buttons. Those buttons are mounted in the
/// same Stack and absorb pointers, so a face drawn underneath them cannot be
/// dragged out of the corner by its most natural grab points. The page keeps
/// the face out of that band entirely.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({'perdix_overlay_enabled': true});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  final media = MediaItem(
    id: 'm1',
    diveId: 'd1',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    platformAssetId: 'g1',
    takenAt: DateTime.utc(2026, 7, 1, 10),
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
    enrichment: MediaEnrichment(
      id: 'e1',
      mediaId: 'm1',
      diveId: 'd1',
      elapsedSeconds: 180,
      depthMeters: 15.0,
      matchConfidence: MatchConfidence.exact,
      createdAt: DateTime.utc(2026, 7, 1),
    ),
  );

  final dive = domain.Dive(
    id: 'd1',
    dateTime: DateTime.utc(2026, 7, 1, 9, 30),
    profile: const [
      domain.DiveProfilePoint(timestamp: 0, depth: 0.0),
      domain.DiveProfilePoint(timestamp: 60, depth: 10.0),
      domain.DiveProfilePoint(timestamp: 120, depth: 20.0),
      domain.DiveProfilePoint(timestamp: 180, depth: 15.0),
      domain.DiveProfilePoint(timestamp: 240, depth: 5.0),
    ],
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            mediaForDiveProvider('d1').overrideWith((ref) async => [media]),
            diveProvider('d1').overrideWith((ref) async => dive),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PhotoViewerPage(diveId: 'd1', initialMediaId: 'm1'),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    });
  }

  testWidgets('the face clears the toolbar buttons at its default corner', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(PerdixFace), findsOneWidget);

    final face = tester.getRect(find.byType(PerdixFace));
    final buttons = tester
        .widgetList<IconButton>(find.byType(IconButton))
        .toList();
    expect(buttons, isNotEmpty, reason: 'toolbar should be showing');

    for (var i = 0; i < buttons.length; i++) {
      final button = tester.getRect(find.byType(IconButton).at(i));
      expect(
        face.overlaps(button),
        isFalse,
        reason: 'face $face overlaps toolbar button $i at $button',
      );
    }
  });

  testWidgets('a downward drag on the face moves it instead of closing the '
      'viewer', (tester) async {
    await pump(tester);
    final before = tester.getRect(find.byType(PerdixFace));

    // Straight down is the natural way to pull the face out of the top-right
    // corner, and it is also the viewer's swipe-to-close gesture. The page
    // wraps the whole Stack in that recognizer, so it contends for this drag
    // from an ancestor; the face has to win the arena or the gesture either
    // does nothing or dismisses the page.
    await tester.fling(find.byType(PerdixFace), const Offset(0, 260), 1200);
    await tester.pumpAndSettle();

    expect(
      find.byType(PhotoViewerPage),
      findsOneWidget,
      reason: 'the viewer should not have been dismissed',
    );
    expect(
      tester.getRect(find.byType(PerdixFace)).top,
      greaterThan(before.top),
    );
  });

  testWidgets('the face is grabbable where it would meet the bottom chrome', (
    tester,
  ) async {
    await pump(tester);
    final before = tester.getRect(find.byType(PerdixFace));

    // Drag toward the bottom-right, where the metadata gradient and the mini
    // profile chart sit. Both absorb pointers, so the face only keeps moving
    // if it is mounted above them.
    await tester.drag(find.byType(PerdixFace), const Offset(0, 4000));
    await tester.pumpAndSettle();
    final parked = tester.getRect(find.byType(PerdixFace));
    expect(parked.top, greaterThan(before.top));

    // Now drag it back out from where it landed.
    await tester.drag(find.byType(PerdixFace), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(PerdixFace)).top, lessThan(parked.top));
  });
}
