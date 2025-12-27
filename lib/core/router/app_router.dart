import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/buddies/presentation/pages/buddy_list_page.dart';
import '../../features/divers/presentation/providers/diver_providers.dart';
import '../../features/onboarding/presentation/pages/welcome_page.dart';
import '../../features/buddies/presentation/pages/buddy_detail_page.dart';
import '../../features/buddies/presentation/pages/buddy_edit_page.dart';
import '../../features/divers/presentation/pages/diver_list_page.dart';
import '../../features/divers/presentation/pages/diver_detail_page.dart';
import '../../features/divers/presentation/pages/diver_edit_page.dart';
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
import '../../features/dive_sites/presentation/pages/site_import_page.dart';
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
import '../../features/statistics/presentation/pages/statistics_gas_page.dart';
import '../../features/statistics/presentation/pages/statistics_progression_page.dart';
import '../../features/statistics/presentation/pages/statistics_conditions_page.dart';
import '../../features/statistics/presentation/pages/statistics_social_page.dart';
import '../../features/statistics/presentation/pages/statistics_geographic_page.dart';
import '../../features/statistics/presentation/pages/statistics_marine_life_page.dart';
import '../../features/statistics/presentation/pages/statistics_time_patterns_page.dart';
import '../../features/statistics/presentation/pages/statistics_equipment_page.dart';
import '../../features/statistics/presentation/pages/statistics_profile_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/presentation/pages/api_keys_page.dart';
import '../../features/dive_types/presentation/pages/dive_types_page.dart';
import '../../features/tools/presentation/pages/weight_calculator_page.dart';
import '../../features/dive_computer/presentation/pages/device_list_page.dart';
import '../../features/dive_computer/presentation/pages/device_detail_page.dart';
import '../../features/dive_computer/presentation/pages/device_download_page.dart';
import '../../features/dive_computer/presentation/pages/device_discovery_page.dart';
import '../../shared/widgets/main_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dives',
    redirect: (context, state) async {
      final hasDivers = await ref.read(hasAnyDiversProvider.future);
      final isOnWelcome = state.matchedLocation == '/welcome';

      // If no divers and not already on welcome, redirect to welcome
      if (!hasDivers && !isOnWelcome) {
        return '/welcome';
      }

      // If has divers and on welcome, redirect to dives
      if (hasDivers && isOnWelcome) {
        return '/dives';
      }

      return null;
    },
    routes: [
      // Welcome/Onboarding route (outside ShellRoute - no bottom nav)
      GoRoute(
        path: '/welcome',
        name: 'welcome',
        builder: (context, state) => const WelcomePage(),
      ),
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
                path: 'import',
                name: 'importSite',
                builder: (context, state) => const SiteImportPage(),
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

          // Divers
          GoRoute(
            path: '/divers',
            name: 'divers',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DiverListPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                name: 'newDiver',
                builder: (context, state) => const DiverEditPage(),
              ),
              GoRoute(
                path: ':diverId',
                name: 'diverDetail',
                builder: (context, state) => DiverDetailPage(
                  diverId: state.pathParameters['diverId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'editDiver',
                    builder: (context, state) => DiverEditPage(
                      diverId: state.pathParameters['diverId'],
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
            routes: [
              GoRoute(
                path: 'gas',
                name: 'statisticsGas',
                builder: (context, state) => const StatisticsGasPage(),
              ),
              GoRoute(
                path: 'progression',
                name: 'statisticsProgression',
                builder: (context, state) => const StatisticsProgressionPage(),
              ),
              GoRoute(
                path: 'conditions',
                name: 'statisticsConditions',
                builder: (context, state) => const StatisticsConditionsPage(),
              ),
              GoRoute(
                path: 'social',
                name: 'statisticsSocial',
                builder: (context, state) => const StatisticsSocialPage(),
              ),
              GoRoute(
                path: 'geographic',
                name: 'statisticsGeographic',
                builder: (context, state) => const StatisticsGeographicPage(),
              ),
              GoRoute(
                path: 'marine-life',
                name: 'statisticsMarineLife',
                builder: (context, state) => const StatisticsMarineLifePage(),
              ),
              GoRoute(
                path: 'time-patterns',
                name: 'statisticsTimePatterns',
                builder: (context, state) => const StatisticsTimePatternsPage(),
              ),
              GoRoute(
                path: 'equipment',
                name: 'statisticsEquipment',
                builder: (context, state) => const StatisticsEquipmentPage(),
              ),
              GoRoute(
                path: 'profile',
                name: 'statisticsProfile',
                builder: (context, state) => const StatisticsProfilePage(),
              ),
            ],
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
            routes: [
              GoRoute(
                path: 'api-keys',
                name: 'apiKeys',
                builder: (context, state) => const ApiKeysPage(),
              ),
            ],
          ),

          // Dive Types Management
          GoRoute(
            path: '/dive-types',
            name: 'diveTypes',
            builder: (context, state) => const DiveTypesPage(),
          ),

          // Dive Computers
          GoRoute(
            path: '/dive-computers',
            name: 'diveComputers',
            builder: (context, state) => const DeviceListPage(),
            routes: [
              GoRoute(
                path: 'discover',
                name: 'discoverDevice',
                builder: (context, state) => const DeviceDiscoveryPage(),
              ),
              GoRoute(
                path: ':computerId',
                name: 'computerDetail',
                builder: (context, state) => DeviceDetailPage(
                  computerId: state.pathParameters['computerId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'download',
                    name: 'computerDownload',
                    builder: (context, state) => DeviceDownloadPage(
                      computerId: state.pathParameters['computerId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Tools
          GoRoute(
            path: '/tools/weight-calculator',
            name: 'weightCalculator',
            builder: (context, state) => const WeightCalculatorPage(),
          ),
        ],
      ),
    ],
  );
});
