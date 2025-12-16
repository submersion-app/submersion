import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/buddies/presentation/pages/buddy_list_page.dart';
import '../../features/buddies/presentation/pages/buddy_detail_page.dart';
import '../../features/buddies/presentation/pages/buddy_edit_page.dart';
import '../../features/certifications/presentation/pages/certification_list_page.dart';
import '../../features/certifications/presentation/pages/certification_detail_page.dart';
import '../../features/certifications/presentation/pages/certification_edit_page.dart';
import '../../features/dive_centers/presentation/pages/dive_center_list_page.dart';
import '../../features/dive_centers/presentation/pages/dive_center_detail_page.dart';
import '../../features/dive_centers/presentation/pages/dive_center_edit_page.dart';
import '../../features/dive_log/presentation/pages/dive_list_page.dart';
import '../../features/dive_log/presentation/pages/dive_detail_page.dart';
import '../../features/dive_log/presentation/pages/dive_edit_page.dart';
import '../../features/dive_sites/presentation/pages/site_list_page.dart';
import '../../features/dive_sites/presentation/pages/site_detail_page.dart';
import '../../features/dive_sites/presentation/pages/site_edit_page.dart';
import '../../features/dive_sites/presentation/pages/site_map_page.dart';
import '../../features/equipment/presentation/pages/equipment_list_page.dart';
import '../../features/equipment/presentation/pages/equipment_detail_page.dart';
import '../../features/equipment/presentation/pages/equipment_edit_page.dart';
import '../../features/equipment/presentation/pages/equipment_set_list_page.dart';
import '../../features/equipment/presentation/pages/equipment_set_detail_page.dart';
import '../../features/equipment/presentation/pages/equipment_set_edit_page.dart';
import '../../features/trips/presentation/pages/trip_list_page.dart';
import '../../features/trips/presentation/pages/trip_detail_page.dart';
import '../../features/trips/presentation/pages/trip_edit_page.dart';
import '../../features/statistics/presentation/pages/statistics_page.dart';
import '../../features/statistics/presentation/pages/records_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../shared/widgets/main_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dives',
    routes: [
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          // Dive Log
          GoRoute(
            path: '/dives',
            name: 'dives',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DiveListPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                name: 'newDive',
                builder: (context, state) => const DiveEditPage(),
              ),
              GoRoute(
                path: ':diveId',
                name: 'diveDetail',
                builder: (context, state) => DiveDetailPage(
                  diveId: state.pathParameters['diveId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'editDive',
                    builder: (context, state) => DiveEditPage(
                      diveId: state.pathParameters['diveId'],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Dive Sites
          GoRoute(
            path: '/sites',
            name: 'sites',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SiteListPage(),
            ),
            routes: [
              GoRoute(
                path: 'map',
                name: 'sitesMap',
                builder: (context, state) => const SiteMapPage(),
              ),
              GoRoute(
                path: 'new',
                name: 'newSite',
                builder: (context, state) => const SiteEditPage(),
              ),
              GoRoute(
                path: ':siteId',
                name: 'siteDetail',
                builder: (context, state) => SiteDetailPage(
                  siteId: state.pathParameters['siteId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'editSite',
                    builder: (context, state) => SiteEditPage(
                      siteId: state.pathParameters['siteId'],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Equipment
          GoRoute(
            path: '/equipment',
            name: 'equipment',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: EquipmentListPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                name: 'newEquipment',
                builder: (context, state) => const EquipmentEditPage(),
              ),
              GoRoute(
                path: 'sets',
                name: 'equipmentSets',
                builder: (context, state) => const EquipmentSetListPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    name: 'newEquipmentSet',
                    builder: (context, state) => const EquipmentSetEditPage(),
                  ),
                  GoRoute(
                    path: ':setId',
                    name: 'equipmentSetDetail',
                    builder: (context, state) => EquipmentSetDetailPage(
                      setId: state.pathParameters['setId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        name: 'editEquipmentSet',
                        builder: (context, state) => EquipmentSetEditPage(
                          setId: state.pathParameters['setId'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: ':equipmentId',
                name: 'equipmentDetail',
                builder: (context, state) => EquipmentDetailPage(
                  equipmentId: state.pathParameters['equipmentId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'editEquipment',
                    builder: (context, state) => EquipmentEditPage(
                      equipmentId: state.pathParameters['equipmentId'],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Buddies
          GoRoute(
            path: '/buddies',
            name: 'buddies',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BuddyListPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                name: 'newBuddy',
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return BuddyEditPage(
                    initialName: extra?['name'] as String?,
                    initialEmail: extra?['email'] as String?,
                    initialPhone: extra?['phone'] as String?,
                  );
                },
              ),
              GoRoute(
                path: ':buddyId',
                name: 'buddyDetail',
                builder: (context, state) => BuddyDetailPage(
                  buddyId: state.pathParameters['buddyId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'editBuddy',
                    builder: (context, state) => BuddyEditPage(
                      buddyId: state.pathParameters['buddyId'],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Certifications
          GoRoute(
            path: '/certifications',
            name: 'certifications',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CertificationListPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                name: 'newCertification',
                builder: (context, state) => const CertificationEditPage(),
              ),
              GoRoute(
                path: ':certificationId',
                name: 'certificationDetail',
                builder: (context, state) => CertificationDetailPage(
                  certificationId: state.pathParameters['certificationId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'editCertification',
                    builder: (context, state) => CertificationEditPage(
                      certificationId: state.pathParameters['certificationId'],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Dive Centers
          GoRoute(
            path: '/dive-centers',
            name: 'diveCenters',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DiveCenterListPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                name: 'newDiveCenter',
                builder: (context, state) => const DiveCenterEditPage(),
              ),
              GoRoute(
                path: ':centerId',
                name: 'diveCenterDetail',
                builder: (context, state) => DiveCenterDetailPage(
                  centerId: state.pathParameters['centerId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'editDiveCenter',
                    builder: (context, state) => DiveCenterEditPage(
                      centerId: state.pathParameters['centerId'],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Trips
          GoRoute(
            path: '/trips',
            name: 'trips',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TripListPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                name: 'newTrip',
                builder: (context, state) => const TripEditPage(),
              ),
              GoRoute(
                path: ':tripId',
                name: 'tripDetail',
                builder: (context, state) => TripDetailPage(
                  tripId: state.pathParameters['tripId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'editTrip',
                    builder: (context, state) => TripEditPage(
                      tripId: state.pathParameters['tripId'],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Statistics
          GoRoute(
            path: '/statistics',
            name: 'statistics',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: StatisticsPage(),
            ),
          ),

          // Records
          GoRoute(
            path: '/records',
            name: 'records',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: RecordsPage(),
            ),
          ),

          // Settings
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsPage(),
            ),
          ),
        ],
      ),
    ],
  );
});
