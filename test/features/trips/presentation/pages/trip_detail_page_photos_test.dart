import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/presentation/helpers/media_hold.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_media_preview.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import 'trip_detail_page_unlock_harness.dart';

/// The Photos card's scans are held in the trip's sitting behind the phase
/// 3 switch (issue #4527): what they find is shown apart until Save, and
/// can be taken out first.
void main() {
  final l = AppLocalizationsEn();
  final at = DateTime.utc(2030, 6, 2, 9);

  final noPhotos = [
    tripMediaPreviewProvider.overrideWith(
      (ref, id) async => TripMediaPreview.empty,
    ),
    mediaCountForTripProvider.overrideWith((ref, id) async => 0),
  ];

  Future<void> showPhotos(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(Tab, l.trips_detail_tab_photos));
    await tester.pumpAndSettle();
  }

  testWidgets('locked, the Photos tab offers Scan photos; in a sitting the '
      'photos held show apart, and Take out drops one', (tester) async {
    final harness = await pumpTripPage(
      tester,
      size: const Size(1000, 1600),
      extraOverrides: noPhotos,
    );
    await showPhotos(tester);
    expect(find.byTooltip(l.trips_photos_tooltip_scan), findsOneWidget);

    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    final session = RecordEditScope.maybeOf<Trip>(
      tester.element(find.byType(TabBar)),
    )!.session!;
    addMediaToSitting(session, [
      HeldMediaRow((
        item: MediaItem(
          id: 'm1',
          diveId: 'd1',
          mediaType: MediaType.photo,
          sourceType: MediaSourceType.platformGallery,
          platformAssetId: 'a1',
          takenAt: at,
          createdAt: at,
          updatedAt: at,
        ),
        enrichment: null,
      )),
    ]);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trip-held-photo-m1')), findsOneWidget);
    expect(find.text(l.trips_sitting_notSaved), findsOneWidget);
    expect(session.changedCardIds, {'photos'});

    await tester.tap(find.byKey(const Key('trip-held-photo-takeOut-m1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trip-held-photos')), findsNothing);
    expect(session.changedCardIds, isEmpty);
    expect(harness.save.calls, isEmpty);
  });
}
