import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_list_page.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_list_content.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/table_mode_layout/table_mode_layout.dart';

import '../../../../helpers/mock_providers.dart';

// ---------------------------------------------------------------------------
// Mock notifiers
// ---------------------------------------------------------------------------

class _MockBuddyListNotifier extends StateNotifier<AsyncValue<List<Buddy>>>
    implements BuddyListNotifier {
  _MockBuddyListNotifier() : super(const AsyncValue.data(<Buddy>[]));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _TestBuddyTableConfigNotifier
    extends EntityTableConfigNotifier<BuddyField> {
  _TestBuddyTableConfigNotifier()
    : super(
        defaultConfig: EntityTableViewConfig<BuddyField>(
          columns: [
            EntityTableColumnConfig(
              field: BuddyField.buddyName,
              isPinned: true,
            ),
          ],
        ),
        fieldFromName: BuddyFieldAdapter.instance.fieldFromName,
      );
}

// ---------------------------------------------------------------------------
// Helper to build the widget under test inside a GoRouter
// ---------------------------------------------------------------------------

Widget _buildTestWidget({required List<Override> overrides}) {
  final router = GoRouter(
    initialLocation: '/buddies',
    routes: [
      GoRoute(
        path: '/buddies',
        builder: (context, state) => const BuddyListPage(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const Scaffold(body: Text('new')),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) => const Scaffold(body: Text('detail')),
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('BuddyListPage', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    List<Override> baseOverrides({
      ListViewMode viewMode = ListViewMode.detailed,
    }) {
      return [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        allBuddiesWithDiveCountProvider.overrideWith(
          (ref) => <BuddyWithDiveCount>[],
        ),
        buddyListNotifierProvider.overrideWith(
          (ref) => _MockBuddyListNotifier(),
        ),
        buddyListViewModeProvider.overrideWith((ref) => viewMode),
        buddyTableConfigProvider.overrideWith(
          (ref) => _TestBuddyTableConfigNotifier(),
        ),
      ];
    }

    testWidgets('renders BuddyListContent in mobile mode', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestWidget(overrides: baseOverrides()));
      await tester.pumpAndSettle();

      expect(find.byType(BuddyListContent), findsOneWidget);
      expect(find.byType(TableModeLayout), findsNothing);
      expect(find.byType(MasterDetailScaffold), findsNothing);
    });

    testWidgets('renders TableModeLayout in table mode', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: baseOverrides(viewMode: ListViewMode.table),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TableModeLayout), findsOneWidget);
      expect(find.byType(MasterDetailScaffold), findsNothing);
    });

    testWidgets('renders MasterDetailScaffold in desktop mode', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: baseOverrides(viewMode: ListViewMode.detailed),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MasterDetailScaffold), findsOneWidget);
      expect(find.byType(TableModeLayout), findsNothing);
    });
  });
}
