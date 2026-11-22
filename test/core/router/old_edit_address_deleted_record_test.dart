import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/buddies/presentation/pages/buddy_detail_page.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_routes.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_detail_page.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_edit_routes.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/pages/course_detail_page.dart';
import 'package:submersion/features/courses/presentation/pages/course_edit_routes.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_detail_page.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_edit_routes.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/documents/presentation/pages/document_detail_page.dart';
import 'package:submersion/features/documents/presentation/pages/document_edit_routes.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/providers/document_record_provider.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_routes.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_edit_routes.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/marine_life/presentation/pages/species_detail_page.dart';
import 'package:submersion/features/marine_life/presentation/pages/species_edit_routes.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/trips/presentation/pages/trip_edit_routes.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';

/// One type's old edit address, its page and what makes the record gone.
typedef _OldAddress = ({
  String name,
  String path,
  RouteBase route,
  List<Override> gone,
});

bool _unlocked(GoRouterState state) =>
    state.uri.queryParameters['mode'] == 'edit';

/// The page route at [path] with its old `edit` address beneath it, its
/// id in the path parameter [param], as the app's router names it.
GoRoute _withEdit(
  String path,
  String param,
  Widget Function(String id, bool openUnlocked) page,
  GoRouterRedirect redirect,
) => GoRoute(
  path: '$path/:$param',
  builder: (_, state) => page(state.pathParameters[param]!, _unlocked(state)),
  routes: [GoRoute(path: 'edit', redirect: redirect)],
);

/// Review Focus 1 (issue #4527, plan 12): an old bookmark to a record that
/// is gone lands on the page, which says so, stays locked and throws
/// nothing, for every phase 3 type.
void main() {
  final addresses = <_OldAddress>[
    (
      name: 'buddy',
      path: '/buddies',
      route: _withEdit(
        '/buddies',
        'buddyId',
        (id, open) => BuddyDetailPage(buddyId: id, openUnlocked: open),
        buddyEditRedirect,
      ),
      gone: [buddyByIdProvider('gone').overrideWith((ref) async => null)],
    ),
    (
      name: 'dive centre',
      path: '/dive-centers',
      route: _withEdit(
        '/dive-centers',
        'centerId',
        (id, open) => DiveCenterDetailPage(centerId: id, openUnlocked: open),
        diveCenterEditRedirect,
      ),
      gone: [diveCenterByIdProvider('gone').overrideWith((ref) async => null)],
    ),
    (
      name: 'certification',
      path: '/certifications',
      route: _withEdit(
        '/certifications',
        'certificationId',
        (id, open) =>
            CertificationDetailPage(certificationId: id, openUnlocked: open),
        certificationEditRedirect,
      ),
      gone: [
        certificationByIdProvider('gone').overrideWith((ref) async => null),
      ],
    ),
    (
      name: 'course',
      path: '/courses',
      route: _withEdit(
        '/courses',
        'courseId',
        (id, open) => CourseDetailPage(courseId: id, openUnlocked: open),
        courseEditRedirect,
      ),
      gone: [courseByIdProvider('gone').overrideWith((ref) async => null)],
    ),
    (
      name: 'document',
      path: '/documents',
      route: _withEdit(
        '/documents',
        'documentId',
        (id, open) => DocumentDetailPage(documentId: id, openUnlocked: open),
        documentEditRedirect,
      ),
      gone: [
        documentEntryProvider('gone').overrideWith((ref) async => null),
        documentRecordProvider('gone').overrideWith((ref) async => null),
      ],
    ),
    (
      name: 'gear item',
      path: '/equipment',
      route: _withEdit(
        '/equipment',
        'equipmentId',
        (id, open) => EquipmentDetailPage(equipmentId: id, openUnlocked: open),
        gearItemEditRedirect,
      ),
      gone: [equipmentItemProvider('gone').overrideWith((ref) async => null)],
    ),
    (
      name: 'equipment set',
      path: '/equipment/sets',
      route: _withEdit(
        '/equipment/sets',
        'setId',
        (id, open) => EquipmentSetDetailPage(setId: id, openUnlocked: open),
        equipmentSetEditRedirect,
      ),
      gone: [equipmentSetProvider('gone').overrideWith((ref) async => null)],
    ),
    (
      name: 'trip',
      path: '/trips',
      route: GoRoute(
        path: '/trips/:tripId',
        builder: tripDetailRoutePage,
        routes: [GoRoute(path: 'edit', redirect: tripEditRedirect)],
      ),
      gone: [
        tripByIdProvider('gone').overrideWith((ref) async => null),
        tripWithStatsProvider(
          'gone',
        ).overrideWith((ref) async => throw StateError('Trip not found')),
      ],
    ),
    (
      name: 'species',
      path: '/species',
      route: GoRoute(
        path: '/species',
        builder: (_, _) => const SizedBox(),
        routes: [
          GoRoute(
            path: ':speciesId',
            builder: (_, state) => SpeciesDetailPage(
              speciesId: state.pathParameters['speciesId']!,
              openUnlocked: _unlocked(state),
            ),
          ),
          GoRoute(path: ':speciesId/edit', redirect: speciesEditRedirect),
        ],
      ),
      gone: [speciesProvider('gone').overrideWith((ref) async => null)],
    ),
  ];

  for (final address in addresses) {
    testWidgets('an old edit address for a deleted ${address.name} shows the '
        'page, locked', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '${address.path}/gone/edit',
        routes: [address.route],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        testAppRouter(
          router: router,
          overrides: [...await getBaseOverrides(), ...address.gone],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(router.state.uri.toString(), '${address.path}/gone?mode=edit');
      // Nothing to unlock: no lock, no editing bar.
      expect(find.byIcon(Icons.lock_outline), findsNothing);
      expect(find.byIcon(Icons.lock_open), findsNothing);
    });
  }
}
