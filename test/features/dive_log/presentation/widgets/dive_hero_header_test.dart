import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_hero_header.dart';
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
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diveTypesProvider.overrideWith(
            (ref) async => const <DiveTypeEntity>[],
          ),
          showCountryFlagsProvider.overrideWithValue(flags),
        ],
        child: localizedMaterialApp(
          locale: const Locale('en'),
          home: Scaffold(body: header),
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
}
