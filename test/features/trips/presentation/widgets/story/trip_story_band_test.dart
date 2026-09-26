import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_band.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_band_extents.dart';
import 'package:submersion/features/trips/presentation/widgets/story/trip_story_docked_day.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

const _bandWidth = 400.0;

TripStoryDay futureDayFixture() => TripStoryDay(
  date: DateTime(2026, 3, 27),
  dayNumber: 3,
  kind: TripStoryDayKind.future,
);

Future<void> pumpBand(
  WidgetTester tester, {
  required double shrinkOffset,
  required bool withDay,
  TripStoryDay? day,
}) async {
  final overrides = await getBaseOverrides();
  final extents = TripStoryBandExtents.forScaler(TextScaler.noScaling);
  final delegate = TripStoryBandDelegate(
    extents: extents,
    map: const SizedBox.expand(key: Key('fake-map')),
    dockedDay: withDay ? (day ?? futureDayFixture()) : null,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: _bandWidth,
            height: extents.expanded,
            child: Builder(
              builder: (context) =>
                  delegate.build(context, shrinkOffset, false),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('expanded, the map takes the full width', (tester) async {
    await pumpBand(tester, shrinkOffset: 0, withDay: true);

    expect(tester.getSize(find.byKey(const Key('fake-map'))).width, _bandWidth);
  });

  testWidgets('docked, the map takes half the width', (tester) async {
    final extents = TripStoryBandExtents.forScaler(TextScaler.noScaling);
    await pumpBand(
      tester,
      shrinkOffset: extents.expanded - extents.docked,
      withDay: true,
    );

    expect(
      tester.getSize(find.byKey(const Key('fake-map'))).width,
      _bandWidth / 2,
    );
    expect(find.byType(TripStoryDockedDay), findsOneWidget);
  });

  testWidgets('the panel stays hidden through the first half of the morph', (
    tester,
  ) async {
    final extents = TripStoryBandExtents.forScaler(TextScaler.noScaling);
    await pumpBand(
      tester,
      shrinkOffset: (extents.expanded - extents.docked) * 0.25,
      withDay: true,
    );

    final opacity = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byType(TripStoryDockedDay),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(opacity.opacity, 0.0);
  });

  testWidgets('swapping the docked day cross-fades rather than cutting', (
    tester,
  ) async {
    final extents = TripStoryBandExtents.forScaler(TextScaler.noScaling);
    final docked = extents.expanded - extents.docked;
    await pumpBand(tester, shrinkOffset: docked, withDay: true);

    // Same tree, a different day: the switcher keeps the outgoing panel on
    // screen for the length of the transition.
    await pumpBand(
      tester,
      shrinkOffset: docked,
      withDay: true,
      day: TripStoryDay(
        date: DateTime(2026, 3, 28),
        dayNumber: 4,
        kind: TripStoryDayKind.past,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(TripStoryDockedDay), findsNWidgets(2));

    await tester.pumpAndSettle();
    expect(find.byType(TripStoryDockedDay), findsOneWidget);
  });

  test(
    'shouldRebuild is false for equal inputs, true when a field changes',
    () {
      // The map instance is hoisted by the view, so its identity is stable
      // across delegate instances: a scroll that changes only the shrink offset
      // must not count as a change.
      const map = SizedBox.expand(key: Key('fake-map'));
      final extents = TripStoryBandExtents.forScaler(TextScaler.noScaling);
      void onTap() {}

      TripStoryBandDelegate make({TripStoryDay? day}) => TripStoryBandDelegate(
        extents: extents,
        map: map,
        dockedDay: day ?? futureDayFixture(),
        onDockedDayTap: onTap,
      );

      expect(make().shouldRebuild(make()), isFalse);
      expect(
        make(
          day: TripStoryDay(
            date: DateTime(2026, 3, 28),
            dayNumber: 4,
            kind: TripStoryDayKind.past,
          ),
        ).shouldRebuild(make()),
        isTrue,
      );
      // The docked band keeps a usable height.
      expect(make().minExtent, TripStoryBandExtents.dockedFloor);
    },
  );

  testWidgets('with no day to dock, the map keeps the full width', (
    tester,
  ) async {
    final extents = TripStoryBandExtents.forScaler(TextScaler.noScaling);
    await pumpBand(
      tester,
      shrinkOffset: extents.expanded - extents.docked,
      withDay: false,
    );

    expect(tester.getSize(find.byKey(const Key('fake-map'))).width, _bandWidth);
    expect(find.byType(TripStoryDockedDay), findsNothing);
  });
}
