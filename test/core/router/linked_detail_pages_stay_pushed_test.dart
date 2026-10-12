import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_detail_page.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_detail_page.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_detail_page.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/pages/trip_detail_page.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/mock_providers.dart';

/// Regression coverage for #3292: an item opened from a dive's details is
/// PUSHED. At desktop width each of these pages used to redirect itself into
/// its section's master-detail split with `go`, erasing the dive underneath
/// and its back arrow. Pushed, they must stay put; a root visit (deep link,
/// sidebar) still redirects.
class _Case {
  final String name;
  final String section;
  final Widget Function(String id) page;
  final Override Function(String id) loading;

  const _Case(this.name, this.section, this.page, this.loading);
}

final _cases = <_Case>[
  _Case(
    'equipment',
    '/equipment',
    (id) => EquipmentDetailPage(equipmentId: id),
    (id) => equipmentItemProvider(
      id,
    ).overrideWith((ref) => Completer<EquipmentItem?>().future),
  ),
  _Case(
    'buddy',
    '/buddies',
    (id) => BuddyDetailPage(buddyId: id),
    (id) =>
        buddyByIdProvider(id).overrideWith((ref) => Completer<Buddy?>().future),
  ),
  _Case(
    'trip',
    '/trips',
    (id) => TripDetailPage(tripId: id),
    (id) => tripWithStatsProvider(
      id,
    ).overrideWith((ref) => Completer<TripWithStats>().future),
  ),
  _Case(
    'dive center',
    '/dive-centers',
    (id) => DiveCenterDetailPage(centerId: id),
    (id) => diveCenterByIdProvider(
      id,
    ).overrideWith((ref) => Completer<DiveCenter?>().future),
  ),
  _Case(
    'certification',
    '/certifications',
    (id) => CertificationDetailPage(certificationId: id),
    (id) => certificationByIdProvider(
      id,
    ).overrideWith((ref) => Completer<Certification?>().future),
  ),
];

void main() {
  const desktop = Size(1200, 800);
  const id = 'x1';

  Future<GoRouter> pumpCase(
    WidgetTester tester,
    _Case c, {
    required String initial,
    required List<String> locations,
  }) async {
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: '/root',
          builder: (_, _) => const Scaffold(body: Text('ROOT')),
        ),
        // Shaped like the app: the detail route is a child of its list, so
        // a go() to it builds the list underneath as well.
        GoRoute(
          path: c.section,
          builder: (_, state) {
            locations.add(state.uri.toString());
            return const Scaffold(body: Text('SECTION'));
          },
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, state) {
                locations.add(state.uri.toString());
                return c.page(state.pathParameters['id']!);
              },
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    final originalOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.toString().contains('overflowed')) return;
      originalOnError?.call(d);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [...overrides, c.loading(id)],
        child: MediaQuery(
          data: const MediaQueryData(size: desktop),
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return router;
  }

  for (final c in _cases) {
    testWidgets('${c.name}: pushed at desktop width stays on the stack', (
      tester,
    ) async {
      final locations = <String>[];
      final router = await pumpCase(
        tester,
        c,
        initial: '/root',
        locations: locations,
      );

      // push() completes only when the pushed route is popped; hold the
      // future and await it after the pop so it is never left dangling.
      final pushed = router.push('${c.section}/$id');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        locations.where((l) => l.startsWith('${c.section}?selected=')),
        isEmpty,
        reason:
            'a pushed ${c.name} page must not redirect into its section '
            'and erase the page it was opened from',
      );
      expect(router.canPop(), isTrue);

      router.pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await pushed;
      expect(find.text('ROOT'), findsOneWidget);
      // The page rebuilds while it animates out, after its push has left the
      // router's stack; it must not take that for a URL visit and redirect.
      expect(
        locations.where((l) => l.startsWith('${c.section}?selected=')),
        isEmpty,
        reason: 'popping the ${c.name} page must not redirect',
      );
    });

    testWidgets('${c.name}: a go() to its URL at desktop width redirects', (
      tester,
    ) async {
      final locations = <String>[];
      await pumpCase(
        tester,
        c,
        initial: '${c.section}/$id',
        locations: locations,
      );

      expect(locations.last, '${c.section}?selected=$id');
    });
  }
}
