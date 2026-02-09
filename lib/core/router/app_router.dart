import 'package:flutter/widgets.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_list_page.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/onboarding/presentation/pages/welcome_page.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_detail_page.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_page.dart';
import 'package:submersion/features/divers/presentation/pages/diver_list_page.dart';
import 'package:submersion/features/divers/presentation/pages/diver_detail_page.dart';
import 'package:submersion/features/divers/presentation/pages/diver_edit_page.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_list_page.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_detail_page.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_edit_page.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_wallet_page.dart';
import 'package:submersion/features/courses/presentation/pages/course_list_page.dart';
import 'package:submersion/features/courses/presentation/pages/course_detail_page.dart';
import 'package:submersion/features/courses/presentation/pages/course_edit_page.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_detail_page.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_edit_page.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_import_page.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_list_page.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_map_page.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_search_page.dart';
import 'package:submersion/features/maps/presentation/pages/dive_activity_map_page.dart';
import 'package:submersion/features/maps/presentation/pages/offline_maps_page.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_list_page.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_import_page.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_map_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_list_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_edit_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_list_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_edit_page.dart';
import 'package:submersion/features/trips/presentation/pages/trip_list_page.dart';
import 'package:submersion/features/trips/presentation/pages/trip_detail_page.dart';
import 'package:submersion/features/trips/presentation/pages/trip_edit_page.dart';
import 'package:submersion/features/trips/presentation/pages/trip_gallery_page.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_page.dart';
import 'package:submersion/features/statistics/presentation/pages/records_page.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_gas_page.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_progression_page.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_conditions_page.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_social_page.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_geographic_page.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_marine_life_page.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_time_patterns_page.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_equipment_page.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_profile_page.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/pages/appearance_page.dart';
import 'package:submersion/features/settings/presentation/pages/cloud_sync_page.dart';
import 'package:submersion/features/settings/presentation/pages/storage_settings_page.dart';
import 'package:submersion/features/transfer/presentation/pages/transfer_page.dart';
import 'package:submersion/features/dive_types/presentation/pages/dive_types_page.dart';
import 'package:submersion/features/tank_presets/presentation/pages/tank_presets_page.dart';
import 'package:submersion/features/tank_presets/presentation/pages/tank_preset_edit_page.dart';
import 'package:submersion/features/marine_life/presentation/pages/species_manage_page.dart';
import 'package:submersion/features/marine_life/presentation/pages/species_edit_page.dart';
import 'package:submersion/features/marine_life/presentation/pages/species_detail_page.dart';
import 'package:submersion/features/planning/presentation/pages/planning_page.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_shell.dart';
import 'package:submersion/features/planning/presentation/widgets/planning_welcome.dart';
import 'package:submersion/features/tools/presentation/pages/weight_calculator_page.dart';
import 'package:submersion/features/deco_calculator/presentation/pages/deco_calculator_page.dart';
import 'package:submersion/features/gas_calculators/presentation/pages/gas_calculators_page.dart';
import 'package:submersion/features/dive_computer/presentation/pages/device_list_page.dart';
import 'package:submersion/features/dive_computer/presentation/pages/device_detail_page.dart';
import 'package:submersion/features/dive_computer/presentation/pages/device_download_page.dart';
import 'package:submersion/features/dive_computer/presentation/pages/device_discovery_page.dart';
import 'package:submersion/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:submersion/features/dive_planner/presentation/pages/dive_planner_page.dart';
import 'package:submersion/features/surface_interval_tool/presentation/pages/surface_interval_tool_page.dart';
import 'package:submersion/features/dive_import/presentation/pages/fit_import_page.dart';
import 'package:submersion/features/dive_import/presentation/pages/healthkit_import_page.dart';
import 'package:submersion/features/dive_import/presentation/pages/uddf_import_page.dart';
import 'package:submersion/shared/widgets/main_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) async {
      // Skip redirect logic during database migration to prevent deadlock
      if (DatabaseService.instance.isMigrating) {
        return null;
      }

      final hasDivers = await ref.read(hasAnyDiversProvider.future);
      final isOnWelcome = state.matchedLocation == '/welcome';

      // If no divers and not already on welcome, redirect to welcome
      if (!hasDivers && !isOnWelcome) {
        // Clear any pending notification to prevent confusion after onboarding
        NotificationService.instance.selectedEquipmentId; // consume and discard
        return '/welcome';
      }

      // Check for notification deep link (reading clears the value)
      final equipmentId = NotificationService.instance.selectedEquipmentId;
      if (equipmentId != null) {
        return '/equipment/$equipmentId';
      }

      // If has divers and on welcome, redirect to dashboard
      if (hasDivers && isOnWelcome) {
        return '/dashboard';
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
          // Dashboard (Home)
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const DashboardPage(),
            ),
          ),

          // Planning Hub with ShellRoute for master/detail on wide screens
          ShellRoute(
            pageBuilder: (context, state, child) => NoTransitionPage(
              key: state.pageKey,
              child: PlanningShell(child: child),
            ),
            routes: [
              GoRoute(
                path: '/planning',
                name: 'planning',
                pageBuilder: (context, state) {
                  // On wide screens show welcome placeholder, on mobile show hub
                  final isWide = MediaQuery.of(context).size.width >= 900;
                  return NoTransitionPage(
                    key: state.pageKey,
                    child: isWide
                        ? const PlanningWelcome()
                        : const PlanningPage(),
                  );
                },
                routes: [
                  GoRoute(
                    path: 'dive-planner',
                    name: 'divePlanner',
                    builder: (context, state) => const DivePlannerPage(),
                    routes: [
                      GoRoute(
                        path: ':planId',
                        name: 'editPlan',
                        builder: (context, state) => DivePlannerPage(
                          planId: state.pathParameters['planId'],
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'deco-calculator',
                    name: 'decoCalculator',
                    builder: (context, state) => const DecoCalculatorPage(),
                  ),
                  GoRoute(
                    path: 'gas-calculators',
                    name: 'gasCalculators',
                    builder: (context, state) => const GasCalculatorsPage(),
                  ),
                  GoRoute(
                    path: 'weight-calculator',
                    name: 'weightCalculator',
                    builder: (context, state) => const WeightCalculatorPage(),
                  ),
                  GoRoute(
                    path: 'surface-interval',
                    name: 'surfaceInterval',
                    builder: (context, state) =>
                        const SurfaceIntervalToolPage(),
                  ),
                ],
              ),
            ],
          ),

          // Dive Log
          GoRoute(
            path: '/dives',
            name: 'dives',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const DiveListPage(),
            ),
            routes: [
              GoRoute(
                path: 'activity',
                name: 'diveActivity',
                builder: (context, state) => const DiveActivityMapPage(),
              ),
              GoRoute(
                path: 'new',
                name: 'newDive',
                builder: (context, state) => const DiveEditPage(),
              ),
              GoRoute(
                path: 'search',
                name: 'diveSearch',
                builder: (context, state) => const DiveSearchPage(),
              ),
              GoRoute(
                path: ':diveId',
                name: 'diveDetail',
                builder: (context, state) =>
                    DiveDetailPage(diveId: state.pathParameters['diveId']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'editDive',
                    builder: (context, state) =>
                        DiveEditPage(diveId: state.pathParameters['diveId']),
                  ),
                ],
              ),
            ],
          ),

          // Dive Sites
          GoRoute(
            path: '/sites',
            name: 'sites',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const SiteListPage(),
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
                builder: (context, state) =>
                    SiteDetailPage(siteId: state.pathParameters['siteId']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'editSite',
                    builder: (context, state) =>
                        SiteEditPage(siteId: state.pathParameters['siteId']),
                  ),
                ],
              ),
            ],
          ),

          // Equipment
          GoRoute(
            path: '/equipment',
            name: 'equipment',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const EquipmentListPage(),
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
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const BuddyListPage(),
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
                builder: (context, state) =>
                    BuddyDetailPage(buddyId: state.pathParameters['buddyId']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'editBuddy',
                    builder: (context, state) =>
                        BuddyEditPage(buddyId: state.pathParameters['buddyId']),
                  ),
                ],
              ),
            ],
          ),

          // Divers
          GoRoute(
            path: '/divers',
            name: 'divers',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const DiverListPage(),
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
                builder: (context, state) =>
                    DiverDetailPage(diverId: state.pathParameters['diverId']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'editDiver',
                    builder: (context, state) =>
                        DiverEditPage(diverId: state.pathParameters['diverId']),
                  ),
                ],
              ),
            ],
          ),

          // Certifications
          GoRoute(
            path: '/certifications',
            name: 'certifications',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const CertificationListPage(),
            ),
            routes: [
              GoRoute(
                path: 'wallet',
                name: 'certificationWallet',
                builder: (context, state) => const CertificationWalletPage(),
              ),
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

          // Training Courses
          GoRoute(
            path: '/courses',
            name: 'courses',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const CourseListPage(),
            ),
            routes: [
              GoRoute(
                path: 'new',
                name: 'newCourse',
                builder: (context, state) => const CourseEditPage(),
              ),
              GoRoute(
                path: ':courseId',
                name: 'courseDetail',
                builder: (context, state) => CourseDetailPage(
                  courseId: state.pathParameters['courseId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'editCourse',
                    builder: (context, state) => CourseEditPage(
                      courseId: state.pathParameters['courseId'],
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
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const DiveCenterListPage(),
            ),
            routes: [
              GoRoute(
                path: 'map',
                name: 'diveCentersMap',
                builder: (context, state) => const DiveCenterMapPage(),
              ),
              GoRoute(
                path: 'import',
                name: 'importDiveCenter',
                builder: (context, state) => const DiveCenterImportPage(),
              ),
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
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const TripListPage(),
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
                builder: (context, state) =>
                    TripDetailPage(tripId: state.pathParameters['tripId']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'editTrip',
                    builder: (context, state) =>
                        TripEditPage(tripId: state.pathParameters['tripId']),
                  ),
                  GoRoute(
                    path: 'gallery',
                    name: 'tripGallery',
                    builder: (context, state) => TripGalleryPage(
                      tripId: state.pathParameters['tripId']!,
                      initialMediaId: state.uri.queryParameters['mediaId'],
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
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const StatisticsPage(),
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
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const RecordsPage(),
            ),
          ),

          // Transfer (Import/Export/Dive Computers)
          GoRoute(
            path: '/transfer',
            name: 'transfer',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const TransferPage(),
            ),
            routes: [
              GoRoute(
                path: 'fit-import',
                name: 'fitImport',
                builder: (context, state) => const FitImportPage(),
              ),
              GoRoute(
                path: 'uddf-import',
                name: 'uddfImport',
                builder: (context, state) => const UddfImportPage(),
              ),
            ],
          ),

          // Settings
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const SettingsPage(),
            ),
            routes: [
              GoRoute(
                path: 'cloud-sync',
                name: 'cloudSync',
                builder: (context, state) => const CloudSyncPage(),
              ),
              GoRoute(
                path: 'storage',
                name: 'storageSettings',
                builder: (context, state) => const StorageSettingsPage(),
              ),
              GoRoute(
                path: 'appearance',
                name: 'appearance',
                builder: (context, state) => const AppearancePage(),
              ),
              GoRoute(
                path: 'offline-maps',
                name: 'offlineMaps',
                builder: (context, state) => const OfflineMapsPage(),
              ),
              GoRoute(
                path: 'wearable-import',
                name: 'wearableImport',
                builder: (context, state) => const HealthKitImportPage(),
              ),
            ],
          ),

          // Dive Types Management
          GoRoute(
            path: '/dive-types',
            name: 'diveTypes',
            builder: (context, state) => const DiveTypesPage(),
          ),

          // Tank Presets Management
          GoRoute(
            path: '/tank-presets',
            name: 'tankPresets',
            builder: (context, state) => const TankPresetsPage(),
            routes: [
              GoRoute(
                path: 'new',
                name: 'newTankPreset',
                builder: (context, state) => const TankPresetEditPage(),
              ),
              GoRoute(
                path: ':presetId/edit',
                name: 'editTankPreset',
                builder: (context, state) => TankPresetEditPage(
                  presetId: state.pathParameters['presetId'],
                ),
              ),
            ],
          ),

          // Species Management
          GoRoute(
            path: '/species',
            name: 'speciesManage',
            builder: (context, state) => const SpeciesManagePage(),
            routes: [
              GoRoute(
                path: 'new',
                name: 'newSpecies',
                builder: (context, state) => const SpeciesEditPage(),
              ),
              GoRoute(
                path: ':speciesId',
                name: 'speciesDetail',
                builder: (context, state) => SpeciesDetailPage(
                  speciesId: state.pathParameters['speciesId']!,
                ),
              ),
              GoRoute(
                path: ':speciesId/edit',
                name: 'editSpecies',
                builder: (context, state) => SpeciesEditPage(
                  speciesId: state.pathParameters['speciesId'],
                ),
              ),
            ],
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
        ],
      ),
    ],
  );
});
