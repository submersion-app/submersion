import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/widgets/track_stats_header.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';
import 'package:submersion/features/tracks/presentation/providers/tracks_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import 'gps_track_detail_page_unlock_harness.dart';

/// The GPS track page edits in place behind the phase 3 switch (issue
/// #4527, plan 5): it opens locked, a sitting holds its name and trim, and
/// one Save writes them.
void main() {
  final l = AppLocalizationsEn();

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
  }

  Future<void> openCard(WidgetTester tester, String title) async {
    await tester.tap(find.byTooltip(l.recordEdit_editCardTooltip(title)));
    await tester.pumpAndSettle();
  }

  Future<void> addFromStrip(WidgetTester tester, String title) async {
    await tester.tap(
      find.descendant(of: find.byType(AddStrip), matching: find.text(title)),
    );
    await tester.pumpAndSettle();
  }

  /// Drags the trim's start handle about a quarter of the way in.
  Future<void> dragTrimStart(WidgetTester tester) async {
    final slider = tester.getRect(find.byType(RangeSlider));
    final gesture = await tester.startGesture(
      Offset(slider.left + 24, slider.center.dy),
    );
    await gesture.moveBy(Offset(slider.width * 0.3, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
  }

  List<int> statsPoints(WidgetTester tester) => [
    for (final p
        in tester
            .widget<TrackStatsHeader>(find.byType(TrackStatsHeader))
            .points)
      p.timestamp,
  ];

  final trimTitle = l.gpsTrack_editCard_trim;
  final headerTitle = l.gpsTrack_detail_title;

  testWidgets('locked, no tap writes and the menu offers no Trim', (
    tester,
  ) async {
    final harness = await pumpGpsTrackPage(
      tester,
      track: gpsTrack(trimStart: gpsStartMs + 3600 * 1000),
    );

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byType(RecordPencilIcon), findsNothing);
    await tester.tap(find.text('Morning swim'));
    await tester.tap(find.byKey(const ValueKey('gps-track-trim-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gps-track-overflow')));
    await tester.pumpAndSettle();

    expect(find.text(l.gpsTrack_action_resetTrim), findsNothing);
    expect(harness.save.calls, isEmpty);
    expect(find.byType(RecordEditBar), findsNothing);
  });

  testWidgets('a rename and a trim in one sitting save as one entry and lock', (
    tester,
  ) async {
    final harness = await pumpGpsTrackPage(tester);
    await unlock(tester);
    await openCard(tester, headerTitle);
    await tester.enterText(
      find.byKey(const ValueKey('gps-track-name-field')),
      'Shore dive',
    );
    await tester.pumpAndSettle();
    await addFromStrip(tester, trimTitle);
    await dragTrimStart(tester);

    await save(tester);

    expect(harness.save.calls, hasLength(1));
    final call = harness.save.calls.single;
    expect(call.cards, {'header', 'trim'});
    expect(call.after.name, 'Shore dive');
    expect(call.after.trimStartTime, greaterThan(gpsStartMs));
    expect(find.byType(RecordEditBar), findsNothing);
    expect(find.text('Shore dive'), findsOneWidget);
  });

  testWidgets('while a trim is held the stats show the trimmed span', (
    tester,
  ) async {
    final harness = await pumpGpsTrackPage(tester);
    expect(statsPoints(tester), hasLength(5));
    await unlock(tester);
    await addFromStrip(tester, trimTitle);
    await dragTrimStart(tester);

    expect(statsPoints(tester).length, lessThan(5));
    expect(harness.save.calls, isEmpty);
  });

  testWidgets('a saved trim redraws the map at once', (tester) async {
    final harness = await pumpGpsTrackPage(tester);
    await unlock(tester);
    await addFromStrip(tester, trimTitle);
    await dragTrimStart(tester);
    final held = statsPoints(tester);

    await save(tester);

    // The cached geometry is dropped, so the map reads the saved trim.
    expect(harness.evicted, ['track-1']);
    expect(statsPoints(tester), held);
  });

  testWidgets('a rename alone keeps the cached geometry', (tester) async {
    final harness = await pumpGpsTrackPage(tester);
    await unlock(tester);
    await openCard(tester, headerTitle);
    await tester.enterText(
      find.byKey(const ValueKey('gps-track-name-field')),
      'Shore dive',
    );
    await tester.pumpAndSettle();

    await save(tester);

    expect(harness.evicted, isEmpty);
  });

  testWidgets('Reset trim is a change of Trim', (tester) async {
    final harness = await pumpGpsTrackPage(
      tester,
      track: gpsTrack(trimStart: gpsStartMs + 3600 * 1000),
    );
    expect(statsPoints(tester), hasLength(4));
    await unlock(tester);
    await openCard(tester, trimTitle);
    await tester.tap(find.byKey(const ValueKey('gps-track-reset-trim')));
    await tester.pumpAndSettle();

    expect(statsPoints(tester), hasLength(5));
    await save(tester);
    expect(harness.save.calls.single.cards, {'trim'});
    expect(harness.save.calls.single.after.trimStartTime, isNull);
  });

  testWidgets('opening the Trim editor and closing it changes nothing', (
    tester,
  ) async {
    await pumpGpsTrackPage(
      tester,
      track: gpsTrack(trimStart: gpsStartMs + 3600 * 1000),
    );
    await unlock(tester);
    await openCard(tester, trimTitle);

    expect(
      tester.widget<RecordEditBar>(find.byType(RecordEditBar)).canSave,
      isFalse,
    );
  });

  testWidgets('an untrimmed track offers Trim in the strip', (tester) async {
    await pumpGpsTrackPage(tester);
    expect(find.byKey(const ValueKey('gps-track-trim-card')), findsNothing);
    await unlock(tester);

    expect(
      find.descendant(
        of: find.byType(AddStrip),
        matching: find.text(trimTitle),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the header block shows unlocked even when unnamed', (
    tester,
  ) async {
    await pumpGpsTrackPage(tester, track: gpsTrack(name: null));
    expect(find.byKey(const ValueKey('gps-track-header-block')), findsNothing);

    await unlock(tester);

    expect(
      find.byKey(const ValueKey('gps-track-header-block')),
      findsOneWidget,
    );
    expect(find.text(l.gpsTrack_editCard_nameHint), findsOneWidget);
  });

  testWidgets('the colour mode stays reachable while unlocked', (tester) async {
    await pumpGpsTrackPage(tester);
    await unlock(tester);

    expect(find.text(l.gpsTrack_colorMode_speed), findsOneWidget);
  });

  testWidgets('Cancel with changes asks first', (tester) async {
    await pumpGpsTrackPage(tester);
    await unlock(tester);
    await openCard(tester, headerTitle);
    await tester.enterText(
      find.byKey(const ValueKey('gps-track-name-field')),
      'Shore dive',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });

  group('Split and Delete', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('gps-track-overflow')));
      await tester.pumpAndSettle();
    }

    PopupMenuItem<Object?> item(WidgetTester tester, String text) =>
        tester.widget<PopupMenuItem<Object?>>(
          find.ancestor(
            of: find.text(text),
            matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
          ),
        );

    testWidgets('locked, Split and Delete are off under "Unlock to use '
        'these"', (tester) async {
      await pumpGpsTrackPage(tester);
      await openMenu(tester);

      expect(find.text(l.recordEdit_unlockToUseThese), findsOneWidget);
      expect(item(tester, l.gpsTrack_action_split).enabled, isFalse);
      expect(item(tester, l.common_action_delete).enabled, isFalse);
    });

    testWidgets('export works locked', (tester) async {
      await pumpGpsTrackPage(tester);
      await openMenu(tester);

      expect(item(tester, l.gpsTrack_action_shareGpx).enabled, isTrue);
      expect(item(tester, l.gpsTrack_action_saveKml).enabled, isTrue);
    });

    testWidgets('with unsaved changes they are off', (tester) async {
      await pumpGpsTrackPage(tester);
      await unlock(tester);
      await openCard(tester, headerTitle);
      await tester.enterText(
        find.byKey(const ValueKey('gps-track-name-field')),
        'Shore dive',
      );
      await tester.pumpAndSettle();
      await openMenu(tester);

      expect(find.text(l.recordEdit_saveOrCancelFirst), findsOneWidget);
      expect(item(tester, l.gpsTrack_action_split).enabled, isFalse);
      expect(item(tester, l.common_action_delete).enabled, isFalse);
    });

    testWidgets('split from a clean sitting creates two tracks and pops '
        'without asking', (tester) async {
      final harness = await pumpGpsTrackPage(tester);
      await unlock(tester);
      await openMenu(tester);
      await tester.tap(find.text(l.gpsTrack_action_split));
      await tester.pumpAndSettle();
      expect(find.text(l.gpsTrack_edit_splitWarning), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('gps-track-edit-apply')));
      await tester.pumpAndSettle();

      expect(harness.splits, hasLength(1));
      expect(harness.splits.single.$1, 'track-1');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('first route'), findsOneWidget);
      expect(find.byType(RecordEditBar), findsNothing);
    });

    testWidgets('delete asks, deletes, forgets the track and pops', (
      tester,
    ) async {
      final harness = await pumpGpsTrackPage(tester);
      final key = GpsTrackItem(gpsTrack()).selectionKey;
      harness.container.read(highlightedTrackKeyProvider.notifier).state = key;
      await unlock(tester);
      await openMenu(tester);
      await tester.tap(find.text(l.common_action_delete));
      await tester.pumpAndSettle();
      expect(find.text(l.gpsLogger_deleteTrackTitle), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l.common_action_delete),
        ),
      );
      await tester.pumpAndSettle();

      expect(harness.deleted, ['track-1']);
      expect(harness.container.read(highlightedTrackKeyProvider), isNull);
      expect(find.text('first route'), findsOneWidget);
    });

    testWidgets('a cancelled delete leaves the track and the sitting', (
      tester,
    ) async {
      final harness = await pumpGpsTrackPage(tester);
      await unlock(tester);
      await openMenu(tester);
      await tester.tap(find.text(l.common_action_delete));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l.common_action_cancel),
        ),
      );
      await tester.pumpAndSettle();

      expect(harness.deleted, isEmpty);
      expect(find.byType(RecordEditBar), findsOneWidget);
    });
  });

  testWidgets('a cache that fails to drop the old geometry does not fail the '
      'save', (tester) async {
    final harness = await pumpGpsTrackPage(tester, evictFails: true);
    await unlock(tester);
    await addFromStrip(tester, trimTitle);
    await dragTrimStart(tester);

    await save(tester);

    expect(harness.save.calls, hasLength(1));
    expect(find.byType(RecordEditBar), findsNothing);
    expect(find.text(l.recordEdit_saveFailed), findsNothing);
  });

  testWidgets('a held trim with too few fixes shows neither statistics nor '
      'map, and keeps the Trim card', (tester) async {
    await pumpGpsTrackPage(tester);
    await unlock(tester);
    await addFromStrip(tester, trimTitle);
    // The start handle dragged past the end: a trim around the last fix.
    final slider = tester.getRect(find.byType(RangeSlider));
    final gesture = await tester.startGesture(
      Offset(slider.left + 24, slider.center.dy),
    );
    await gesture.moveBy(Offset(slider.width, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byType(TrackStatsHeader), findsNothing);
    expect(find.text(l.gpsTrack_detail_noPoints), findsOneWidget);
    expect(find.byType(RangeSlider), findsOneWidget);
  });

  group('the split panel', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('gps-track-overflow')));
      await tester.pumpAndSettle();
    }

    Future<void> openSplit(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('gps-track-overflow')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.gpsTrack_action_split));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('gps-track-edit-panel')),
        findsOneWidget,
      );
    }

    testWidgets('closes when the sitting ends', (tester) async {
      await pumpGpsTrackPage(tester);
      await unlock(tester);
      await openSplit(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(RecordEditBar),
          matching: find.text(l.forms_cancel),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RecordEditBar), findsNothing);
      expect(find.byKey(const ValueKey('gps-track-edit-panel')), findsNothing);
    });

    testWidgets('closes once the sitting has changes', (tester) async {
      await pumpGpsTrackPage(tester);
      await unlock(tester);
      await openSplit(tester);

      await openCard(tester, headerTitle);
      await tester.enterText(
        find.byKey(const ValueKey('gps-track-name-field')),
        'Shore dive',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('gps-track-edit-panel')), findsNothing);
    });

    testWidgets('a refused split point says why and keeps the panel and the '
        'sitting', (tester) async {
      final harness = await pumpGpsTrackPage(tester, splitRefused: true);
      await unlock(tester);
      await openMenu(tester);
      await tester.tap(find.text(l.gpsTrack_action_split));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('gps-track-edit-apply')));
      await tester.pumpAndSettle();

      expect(harness.splits, isEmpty);
      expect(find.text('Split point refused'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('gps-track-edit-panel')),
        findsOneWidget,
      );
      expect(find.byType(RecordEditBar), findsOneWidget);
    });

    testWidgets('a failed delete says so and keeps the page', (tester) async {
      final harness = await pumpGpsTrackPage(tester, deleteFails: true);
      await unlock(tester);
      await openMenu(tester);
      await tester.tap(find.text(l.common_action_delete));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(l.common_action_delete),
        ),
      );
      await tester.pumpAndSettle();

      expect(harness.deleted, isEmpty);
      expect(find.text(l.common_error_tryAgain), findsOneWidget);
      expect(find.text('first route'), findsNothing);
      expect(find.byType(RecordEditBar), findsOneWidget);
    });
  });

  testWidgets('with a trim held, typing a name keeps the drawn fixes the same '
      'list, so the map keeps its framing and the statistics are not redone', (
    tester,
  ) async {
    await pumpGpsTrackPage(tester);
    await unlock(tester);
    await addFromStrip(tester, trimTitle);
    await dragTrimStart(tester);
    final before = tester
        .widget<TrackStatsHeader>(find.byType(TrackStatsHeader))
        .points;

    await openCard(tester, headerTitle);
    await tester.enterText(
      find.byKey(const ValueKey('gps-track-name-field')),
      'Shore dive',
    );
    await tester.pumpAndSettle();

    final after = tester
        .widget<TrackStatsHeader>(find.byType(TrackStatsHeader))
        .points;
    expect(after, same(before));
  });

  testWidgets('a track with one fix can still be named', (tester) async {
    final harness = await pumpGpsTrackPage(
      tester,
      track: GpsTrack(
        id: 'track-1',
        startTime: gpsStartMs,
        endTime: gpsStartMs,
        pointCount: 1,
        points: [gpsFix(0)],
      ),
    );
    expect(find.text(l.gpsTrack_detail_noPoints), findsOneWidget);
    await unlock(tester);

    await openCard(tester, headerTitle);
    await tester.enterText(
      find.byKey(const ValueKey('gps-track-name-field')),
      'Short',
    );
    await tester.pumpAndSettle();
    await save(tester);

    expect(harness.save.calls.single.after.name, 'Short');
    expect(find.text(l.gpsTrack_detail_noPoints), findsOneWidget);
  });
}
