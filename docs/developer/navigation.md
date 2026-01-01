# Navigation

Submersion uses go_router for declarative navigation with persistent bottom navigation.

## Overview

| Concept | Implementation |
|---------|----------------|
| **Package** | go_router 14.x |
| **Pattern** | ShellRoute for persistent navigation |
| **State** | Riverpod Provider |
| **Transitions** | NoTransitionPage for tab switches |

## Router Provider

The router is provided via Riverpod:

```dart
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dives',
    redirect: (context, state) async {
      final hasDivers = await ref.read(hasAnyDiversProvider.future);
      final isOnWelcome = state.matchedLocation == '/welcome';

      // First-run: redirect to welcome if no divers
      if (!hasDivers && !isOnWelcome) {
        return '/welcome';
      }

      // After onboarding: redirect to dives
      if (hasDivers && isOnWelcome) {
        return '/dives';
      }

      return null; // No redirect
    },
    routes: [
      // Route definitions...
    ],
  );
});
```

## ShellRoute Pattern

The ShellRoute wraps all main screens with persistent navigation:

```dart
ShellRoute(
  builder: (context, state, child) => MainScaffold(child: child),
  routes: [
    // All main routes here
  ],
),
```

### MainScaffold

The `MainScaffold` widget provides:
- Bottom navigation bar (mobile)
- Navigation rail (desktop)
- Consistent layout across screens

## Route Structure

### Primary Routes

| Route | Screen | Description |
|-------|--------|-------------|
| `/dives` | DiveListPage | Dive log list |
| `/sites` | SiteListPage | Dive sites |
| `/equipment` | EquipmentListPage | Gear inventory |
| `/buddies` | BuddyListPage | Dive buddies |
| `/statistics` | StatisticsPage | Analytics |
| `/settings` | SettingsPage | Configuration |

### Nested Routes

Each primary route has nested routes for CRUD:

```
/dives
├── /dives/new           → Create dive
├── /dives/:diveId       → View dive detail
└── /dives/:diveId/edit  → Edit dive
```

### Route Example

```dart
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
```

## All Routes Reference

### Dives

| Path | Name | Screen |
|------|------|--------|
| `/dives` | dives | DiveListPage |
| `/dives/new` | newDive | DiveEditPage |
| `/dives/:diveId` | diveDetail | DiveDetailPage |
| `/dives/:diveId/edit` | editDive | DiveEditPage |

### Sites

| Path | Name | Screen |
|------|------|--------|
| `/sites` | sites | SiteListPage |
| `/sites/map` | sitesMap | SiteMapPage |
| `/sites/import` | importSite | SiteImportPage |
| `/sites/new` | newSite | SiteEditPage |
| `/sites/:siteId` | siteDetail | SiteDetailPage |
| `/sites/:siteId/edit` | editSite | SiteEditPage |

### Equipment

| Path | Name | Screen |
|------|------|--------|
| `/equipment` | equipment | EquipmentListPage |
| `/equipment/new` | newEquipment | EquipmentEditPage |
| `/equipment/sets` | equipmentSets | EquipmentSetListPage |
| `/equipment/sets/new` | newEquipmentSet | EquipmentSetEditPage |
| `/equipment/sets/:setId` | equipmentSetDetail | EquipmentSetDetailPage |
| `/equipment/:equipmentId` | equipmentDetail | EquipmentDetailPage |

### Buddies

| Path | Name | Screen |
|------|------|--------|
| `/buddies` | buddies | BuddyListPage |
| `/buddies/new` | newBuddy | BuddyEditPage |
| `/buddies/:buddyId` | buddyDetail | BuddyDetailPage |
| `/buddies/:buddyId/edit` | editBuddy | BuddyEditPage |

### Divers

| Path | Name | Screen |
|------|------|--------|
| `/divers` | divers | DiverListPage |
| `/divers/new` | newDiver | DiverEditPage |
| `/divers/:diverId` | diverDetail | DiverDetailPage |
| `/divers/:diverId/edit` | editDiver | DiverEditPage |

### Certifications

| Path | Name | Screen |
|------|------|--------|
| `/certifications` | certifications | CertificationListPage |
| `/certifications/new` | newCertification | CertificationEditPage |
| `/certifications/:certificationId` | certificationDetail | CertificationDetailPage |

### Dive Centers

| Path | Name | Screen |
|------|------|--------|
| `/dive-centers` | diveCenters | DiveCenterListPage |
| `/dive-centers/new` | newDiveCenter | DiveCenterEditPage |
| `/dive-centers/:centerId` | diveCenterDetail | DiveCenterDetailPage |

### Trips

| Path | Name | Screen |
|------|------|--------|
| `/trips` | trips | TripListPage |
| `/trips/new` | newTrip | TripEditPage |
| `/trips/:tripId` | tripDetail | TripDetailPage |
| `/trips/:tripId/edit` | editTrip | TripEditPage |

### Statistics

| Path | Name | Screen |
|------|------|--------|
| `/statistics` | statistics | StatisticsPage |
| `/statistics/gas` | statisticsGas | StatisticsGasPage |
| `/statistics/progression` | statisticsProgression | StatisticsProgressionPage |
| `/statistics/conditions` | statisticsConditions | StatisticsConditionsPage |
| `/statistics/social` | statisticsSocial | StatisticsSocialPage |
| `/statistics/geographic` | statisticsGeographic | StatisticsGeographicPage |
| `/statistics/marine-life` | statisticsMarineLife | StatisticsMarineLifePage |
| `/statistics/time-patterns` | statisticsTimePatterns | StatisticsTimePatternsPage |
| `/statistics/equipment` | statisticsEquipment | StatisticsEquipmentPage |
| `/statistics/profile` | statisticsProfile | StatisticsProfilePage |

### Settings

| Path | Name | Screen |
|------|------|--------|
| `/settings` | settings | SettingsPage |
| `/settings/api-keys` | apiKeys | ApiKeysPage |
| `/settings/cloud-sync` | cloudSync | CloudSyncPage |

### Dive Computers

| Path | Name | Screen |
|------|------|--------|
| `/dive-computers` | diveComputers | DeviceListPage |
| `/dive-computers/discover` | discoverDevice | DeviceDiscoveryPage |
| `/dive-computers/:computerId` | computerDetail | DeviceDetailPage |
| `/dive-computers/:computerId/download` | computerDownload | DeviceDownloadPage |

### Tools

| Path | Name | Screen |
|------|------|--------|
| `/tools/weight-calculator` | weightCalculator | WeightCalculatorPage |

### Onboarding

| Path | Name | Screen |
|------|------|--------|
| `/welcome` | welcome | WelcomePage |

## Navigation Patterns

### Programmatic Navigation

```dart
// Named route
context.goNamed('diveDetail', pathParameters: {'diveId': dive.id});

// Path-based
context.go('/dives/${dive.id}');

// Push (adds to stack)
context.push('/dives/new');

// Pop (go back)
context.pop();
```

### Passing Data

```dart
// Via path parameters
context.goNamed('diveDetail', pathParameters: {'diveId': '123'});

// Via extra
context.goNamed('newBuddy', extra: {
  'name': 'John',
  'email': 'john@example.com',
});

// Receiving extra
final extra = state.extra as Map<String, dynamic>?;
final name = extra?['name'] as String?;
```

### Result Handling

For edit screens that need to return data:

```dart
// In edit page
context.pop(savedDive);

// In calling page
final result = await context.push<Dive>('/dives/new');
if (result != null) {
  // Handle saved dive
}
```

## NoTransitionPage

Tab switches use `NoTransitionPage` to prevent animation:

```dart
pageBuilder: (context, state) => const NoTransitionPage(
  child: DiveListPage(),
),
```

This provides instant transitions between main tabs, matching platform conventions.

## Route Guards

### First-Run Guard

The router redirects to onboarding if no divers exist:

```dart
redirect: (context, state) async {
  final hasDivers = await ref.read(hasAnyDiversProvider.future);
  if (!hasDivers && state.matchedLocation != '/welcome') {
    return '/welcome';
  }
  return null;
},
```

### Auth Guards (Future)

When authentication is added:

```dart
redirect: (context, state) async {
  final isAuthenticated = await ref.read(authProvider.future);
  final isAuthRoute = state.matchedLocation.startsWith('/auth');

  if (!isAuthenticated && !isAuthRoute) {
    return '/auth/login';
  }
  return null;
},
```

## Deep Linking

go_router supports deep linking out of the box:

- iOS: Universal Links
- Android: App Links
- Web: Standard URLs

Configure in platform-specific files for production use.

## Testing Navigation

```dart
testWidgets('navigates to dive detail', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: testRouter,
      ),
    ),
  );

  // Find and tap a dive
  await tester.tap(find.text('Test Dive'));
  await tester.pumpAndSettle();

  // Verify navigation
  expect(find.byType(DiveDetailPage), findsOneWidget);
});
```

## Best Practices

1. **Use named routes** - Easier refactoring than path strings
2. **NoTransitionPage for tabs** - Instant tab switching
3. **Path parameters for IDs** - `/dives/:diveId` not query params
4. **Extra for complex data** - When path params aren't enough
5. **Guard at router level** - Centralized auth/onboarding logic
6. **Test navigation paths** - Ensure all routes work correctly

