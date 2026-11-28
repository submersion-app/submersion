import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_hero_header.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_mode_badge.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_badge_row.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/country_flag.dart';

import '../../../../helpers/l10n_test_helpers.dart';

void main() {
  const units = UnitFormatter(AppSettings());
  final dive = Dive(
    id: 'd1',
    diveNumber: 7,
    name: 'Shark Point',
    dateTime: DateTime.utc(2026, 5, 1, 9),
    runtime: const Duration(minutes: 52),
    bottomTime: const Duration(minutes: 41, seconds: 30),
  );

  Future<void> pump(
    WidgetTester tester,
    DiveHeroHeader header, {
    bool flags = true,
    TextDirection textDirection = TextDirection.ltr,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diveTypesProvider.overrideWith(
            (ref) async => const <DiveTypeEntity>[],
          ),
          showDiveCountryFlagsProvider.overrideWithValue(flags),
        ],
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: Directionality(
            textDirection: textDirection,
            child: Scaffold(body: header),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('country flag (issue #4426)', () {
    testWidgets('a stored code shows its flag for unread text', (tester) async {
      final korea = Dive(
        id: 'd3',
        diveNumber: 9,
        dateTime: DateTime.utc(2026, 5, 3, 9),
        site: const DiveSite(
          id: 's2',
          name: 'Munseom',
          country: 'Korea',
          countryCode: 'KR',
        ),
      );
      await pump(tester, DiveHeroHeader(dive: korea, units: units));

      expect(tester.widget<CountryFlag>(find.byType(CountryFlag)).code, 'KR');
    });

    final atSite = Dive(
      id: 'd2',
      diveNumber: 8,
      dateTime: DateTime.utc(2026, 5, 2, 9),
      site: const DiveSite(
        id: 's1',
        name: 'Shark Point',
        region: 'New Jersey',
        country: 'United States',
      ),
    );

    testWidgets('the site location line carries the flag', (tester) async {
      await pump(tester, DiveHeroHeader(dive: atSite, units: units));

      expect(tester.widget<CountryFlag>(find.byType(CountryFlag)).code, 'US');
      expect(find.text('New Jersey, United States'), findsOneWidget);
    });

    testWidgets('no flag when flags are off', (tester) async {
      await pump(
        tester,
        DiveHeroHeader(dive: atSite, units: units),
        flags: false,
      );

      expect(find.byType(CountryFlag), findsNothing);
      expect(find.text('New Jersey, United States'), findsOneWidget);
    });
  });

  testWidgets('falls back to the dive\'s own runtime and bottom time', (
    tester,
  ) async {
    await pump(tester, DiveHeroHeader(dive: dive, units: units));

    expect(find.text('#7'), findsOneWidget);
    expect(find.text('Shark Point'), findsOneWidget);
    expect(find.text('52 min'), findsOneWidget);
    expect(find.text('41 min'), findsOneWidget);
  });

  testWidgets('shows the stat values and title slot it is given', (
    tester,
  ) async {
    await pump(
      tester,
      DiveHeroHeader(
        dive: dive,
        units: units,
        runtimeText: '60 min',
        bottomTimeText: '45 min',
        belowTitle: const Text('2 findings'),
      ),
    );

    expect(find.text('60 min'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);
    expect(find.text('52 min'), findsNothing);
    expect(find.text('2 findings'), findsOneWidget);
  });

  group('formatRuntime', () {
    final start = DateTime.utc(2026, 5, 1, 9);

    test('reads a profile when nothing else measured the dive', () {
      final sampled = Dive(
        id: 'sampled',
        dateTime: start,
        profile: const [
          DiveProfilePoint(timestamp: 0, depth: 0),
          DiveProfilePoint(timestamp: 1200, depth: 0),
        ],
      );
      expect(DiveHeroHeader.formatRuntime(sampled), '20 min');
    });

    test('ignores an exit that is not after the entry', () {
      final backwards = Dive(
        id: 'backwards',
        dateTime: start,
        entryTime: start.add(const Duration(hours: 1)),
        exitTime: start,
      );
      expect(DiveHeroHeader.formatRuntime(backwards), '--');
    });

    test('never reports a bottom time', () {
      final logged = Dive(
        id: 'logged',
        dateTime: start,
        bottomTime: const Duration(minutes: 30),
      );
      expect(DiveHeroHeader.formatRuntime(logged), '--');
    });
  });

  // The dive page puts the header card's pencil here: at the far right of
  // the card like every other card's pencil, not after the name (#4888).
  group('trailing (issue #4888)', () {
    const trailingKey = Key('trailing');
    const trailingIcon = Icon(Icons.edit_outlined, key: trailingKey);

    Rect trailingRect(WidgetTester tester) =>
        tester.getRect(find.byKey(trailingKey));

    // The Card's own surface, inside its margin.
    Rect cardRect(WidgetTester tester) => tester.getRect(
      find
          .descendant(of: find.byType(Card), matching: find.byType(Material))
          .first,
    );

    Dive rated(String name, {DiveSite? site, List<String>? types}) => Dive(
      id: 'd4',
      diveNumber: 12,
      name: name,
      dateTime: DateTime.utc(2026, 5, 4, 9),
      rating: 4,
      diveMode: DiveMode.ccr,
      diveTypeIds: types ?? const ['technical', 'wreck', 'deep'],
      site: site,
    );

    // Narrow enough to squeeze the header's columns, wide enough for the
    // stat row under it: the test font's wide glyphs overflow that row,
    // which this change does not touch, at a 360 point phone width.
    void narrowWidth(WidgetTester tester) {
      tester.view.physicalSize = const Size(520, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('sits at the top right, right of the rating and mode badge', (
      tester,
    ) async {
      await pump(
        tester,
        DiveHeroHeader(
          dive: rated('Shark Point'),
          units: units,
          trailing: trailingIcon,
          trailingSize: const Size.square(24),
        ),
      );

      final trailing = trailingRect(tester);
      final badge = tester.getRect(find.byType(DiveModeBadge));
      final star = tester.getRect(find.byIcon(Icons.star));
      final title = tester.getRect(find.text('Shark Point'));
      final card = cardRect(tester);

      expect(trailing.left, greaterThanOrEqualTo(badge.right));
      expect(trailing.left, greaterThan(star.right));
      // At the card's top right corner, inside its 16 px padding.
      expect(card.right - trailing.right, closeTo(16, 0.5));
      expect(trailing.top - card.top, closeTo(16, 0.5));
      // On the title's line, not centred in the header.
      expect(trailing.top, lessThanOrEqualTo(title.center.dy));
    });

    testWidgets("does not move with the name's length", (tester) async {
      await pump(
        tester,
        DiveHeroHeader(
          dive: rated('Bay'),
          units: units,
          trailing: trailingIcon,
          trailingSize: const Size.square(24),
        ),
      );
      final short = trailingRect(tester);

      await pump(
        tester,
        DiveHeroHeader(
          dive: rated('The long drift along the outer reef wall'),
          units: units,
          trailing: trailingIcon,
          trailingSize: const Size.square(24),
        ),
      );
      final long = trailingRect(tester);

      expect(long.right, short.right);
      expect(long.top, short.top);
    });

    testWidgets('stays at the top when the badge column is the taller', (
      tester,
    ) async {
      narrowWidth(tester);
      await pump(
        tester,
        DiveHeroHeader(
          dive: rated(
            'Bay',
            types: const ['technical', 'wreck', 'deep', 'drift', 'night'],
          ),
          units: units,
          trailing: trailingIcon,
          trailingSize: const Size.square(24),
        ),
      );

      final trailing = trailingRect(tester);
      final badge = tester.getRect(find.byType(DiveModeBadge));
      expect(trailing.top - cardRect(tester).top, closeTo(16, 0.5));
      // Clear of the rating/mode row it shares the corner with, and of the
      // type badges under that row.
      expect(trailing.left, greaterThanOrEqualTo(badge.right));
      expect(
        tester.getRect(find.byType(DiveTypeBadgeRow)).top,
        greaterThanOrEqualTo(trailing.bottom),
      );
    });

    testWidgets('right to left, at the top left, clear of the badges', (
      tester,
    ) async {
      await pump(
        tester,
        DiveHeroHeader(
          dive: rated('Shark Point'),
          units: units,
          trailing: trailingIcon,
          trailingSize: const Size.square(24),
        ),
        textDirection: TextDirection.rtl,
      );

      final trailing = trailingRect(tester);
      final card = cardRect(tester);
      expect(trailing.left - card.left, closeTo(16, 0.5));
      expect(trailing.top - card.top, closeTo(16, 0.5));
      expect(
        trailing.right,
        lessThanOrEqualTo(tester.getRect(find.byType(DiveModeBadge)).left),
      );
      expect(
        trailing.right,
        lessThan(tester.getRect(find.text('Shark Point')).left),
      );
    });

    testWidgets('fits a narrow width with a long name and every badge', (
      tester,
    ) async {
      narrowWidth(tester);
      await pump(
        tester,
        DiveHeroHeader(
          dive: rated('The long drift along the outer reef wall'),
          units: units,
          trailing: trailingIcon,
          trailingSize: const Size.square(24),
        ),
      );

      expect(tester.takeException(), isNull);
      final trailing = trailingRect(tester);
      final badge = tester.getRect(find.byType(DiveModeBadge));
      expect(trailing.left, greaterThanOrEqualTo(badge.right));
      expect(cardRect(tester).right - trailing.right, closeTo(16, 0.5));
    });

    // Unlocking must not wrap the site, location or time lines: only the
    // rating/mode row gives up the trailing widget's width.
    testWidgets('leaves the text lines their width at a narrow width', (
      tester,
    ) async {
      narrowWidth(tester);
      // Open circuit and unrated, so the type badges, not the rating/mode
      // row with the trailing widget's room, set the badge column's width.
      final atSite = Dive(
        id: 'd5',
        diveNumber: 13,
        name: 'The long drift along the outer reef wall',
        dateTime: DateTime.utc(2026, 5, 5, 9),
        diveTypeIds: const ['technical', 'wreck', 'deep'],
        site: const DiveSite(
          id: 's3',
          name: 'Outer reef wall north',
          region: 'Northern Province',
          country: 'United States',
        ),
      );
      final location = find.text(atSite.site!.locationString);

      await pump(tester, DiveHeroHeader(dive: atSite, units: units));
      final heightWithout = cardRect(tester).height;
      final locationWithout = tester.getRect(location).width;

      await pump(
        tester,
        DiveHeroHeader(
          dive: atSite,
          units: units,
          trailing: trailingIcon,
          trailingSize: const Size.square(24),
        ),
      );

      expect(cardRect(tester).height, heightWithout);
      expect(tester.getRect(location).width, locationWithout);
    });
  });
}
