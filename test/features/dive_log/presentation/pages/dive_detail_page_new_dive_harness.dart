import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/new_dive_request.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_edit_save_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_shortcuts.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_exit_blocker.dart';

import '../../../../helpers/mock_providers.dart';
import 'dive_detail_page_unlock_harness.dart';

/// What [pumpNewDivePage] hands back: the router, the fake save service,
/// and what the pane's callbacks were told.
typedef NewDivePage = ({
  GoRouter router,
  FakeSave save,
  List<String> created,
  List<String> cancelled,
});

/// Pumps a new dive's page (issue #4527, plan 8) pushed over a home route,
/// as `/dives/new` is, or in the pane with [embedded]. Only [visible]'s
/// sections are shown by the diver's settings.
Future<NewDivePage> pumpNewDivePage(
  WidgetTester tester, {
  NewDiveRequest request = const NewDiveRequest(),
  bool embedded = false,
  Size size = const Size(700, 1400),
  Set<DiveDetailSectionId> visible = const {
    DiveDetailSectionId.tanks,
    DiveDetailSectionId.buddies,
    DiveDetailSectionId.notes,
    DiveDetailSectionId.tags,
  },
  bool shortcuts = false,
  bool realSave = false,
  List<Override> extra = const [],
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final save = FakeSave(Dive(id: '', dateTime: DateTime.utc(2026)));
  final created = <String>[];
  final cancelled = <String>[];
  final overrides = await tester.runAsync(
    () => getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(
        AppSettings(
          hasAcceptedPlanningDisclaimer: true,
          diveDetailSections: [
            for (final id in DiveDetailSectionId.values)
              DiveDetailSectionConfig(id: id, visible: visible.contains(id)),
          ],
        ),
      ),
    ),
  );
  Widget page() => DiveDetailPage.newDive(
    request: request,
    embedded: embedded,
    onCreated: embedded ? created.add : null,
    onCreateCancelled: embedded ? () => cancelled.add('cancel') : null,
  );
  final router = GoRouter(
    initialLocation: '/home/new',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('HOME')),
        routes: [
          GoRoute(
            path: 'new',
            onExit: confirmLeaveRecordSitting,
            builder: (context, state) =>
                embedded ? Scaffold(body: page()) : page(),
          ),
        ],
      ),
      GoRoute(
        path: '/dives',
        builder: (context, state) => const Scaffold(body: Text('DIVES')),
      ),
      GoRoute(
        path: '/dives/:id',
        builder: (context, state) =>
            Scaffold(body: Text('CREATED ${state.pathParameters['id']}')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides!,
        if (!realSave) diveEditSaveServiceProvider.overrideWithValue(save),
        ...extra,
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: shortcuts
            ? (context, child) => RecordEditShortcuts(child: child!)
            : null,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  // The seed reads the database before the page unlocks.
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await settle(tester);
  }
  return (router: router, save: save, created: created, cancelled: cancelled);
}

/// The new dive page's editing controller, read off its scope without
/// making the test a dependent of it.
RecordEditController<Dive> newDiveController(WidgetTester tester) => tester
    .widget<RecordEditScope<Dive>>(find.byType(RecordEditScope<Dive>).first)
    .notifier!;
