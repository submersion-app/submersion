import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/app/app_exit_guard.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/record_edit_label.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_exit_blocker.dart';

import '../../../../helpers/mock_providers.dart';

export '../../../../helpers/mock_providers.dart' show Override;

/// Where the profile pages live, as the app routes them.
const diverProfileHub = '/settings/diver-profile';

/// A diver as the tests seed it.
Diver profileDiver({
  String id = 'diver-1',
  String name = 'Alice Alpha',
  String? email,
  String? bloodType,
  String? allergies,
  String? medications,
  String medicalNotes = '',
  EmergencyContact primary = const EmergencyContact(),
  EmergencyContact secondary = const EmergencyContact(),
  String notes = '',
  int? priorDiveCount,
  int? priorDiveTimeSeconds,
  DateTime? divingSince,
  bool isDefault = false,
}) {
  final then = DateTime.utc(2026, 1, 1);
  return Diver(
    id: id,
    name: name,
    email: email,
    bloodType: bloodType,
    allergies: allergies,
    medications: medications,
    medicalNotes: medicalNotes,
    emergencyContact: primary,
    emergencyContact2: secondary,
    notes: notes,
    priorDiveCount: priorDiveCount,
    priorDiveTimeSeconds: priorDiveTimeSeconds,
    divingSince: divingSince,
    isDefault: isDefault,
    createdAt: then,
    updatedAt: then,
  );
}

/// Stores [diver] as the app would.
Future<void> seedDiver(Diver diver) => DiverRepository().createDiver(diver);

/// The diver [id] as stored now.
Future<Diver?> storedDiver(String id) => DiverRepository().getDiverById(id);

/// A profile page pushed over a stand-in hub, on a route with the app's
/// leave check, with [activeDiverId] active. With [push] false the page is
/// only routed, for the test to push. With [alone] the page is opened on
/// its own, with no page under it to go back to (a deep link). Returns the
/// router; the container is [profileContainer].
Future<GoRouter> pumpProfilePage(
  WidgetTester tester, {
  required String path,
  required Widget page,
  String activeDiverId = 'diver-1',
  List<Document> documents = const [],
  List<Override> overrides = const [],
  bool push = true,
  bool alone = false,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final pageRoute = GoRoute(
    path: alone ? '$diverProfileHub/$path' : path,
    onExit: confirmLeaveRecordSitting,
    builder: (_, _) => page,
  );
  final router = GoRouter(
    initialLocation: alone ? '$diverProfileHub/$path' : diverProfileHub,
    routes: [
      GoRoute(
        path: diverProfileHub,
        builder: (_, _) => const Scaffold(body: Text('Hub')),
        routes: [if (!alone) pageRoute],
      ),
      if (alone) pageRoute,
      GoRoute(
        path: '/documents/new',
        builder: (_, state) => Scaffold(body: Text('NEW ${state.uri.query}')),
      ),
    ],
  );
  final base = await getBaseOverrides(ownerDocuments: documents);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...base, ...overrides],
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await profileContainer(
    tester,
  ).read(currentDiverIdProvider.notifier).setCurrentDiver(activeDiverId);
  await tester.pumpAndSettle();
  if (push && !alone) {
    unawaited(router.push('$diverProfileHub/$path'));
    await tester.pumpAndSettle();
  }
  return router;
}

/// The app's provider container.
ProviderContainer profileContainer(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Navigator).first));

/// The bar's action labelled [label] (Cancel or Save).
AppBarTextAction barAction(WidgetTester tester, String label) => tester
    .widgetList<AppBarTextAction>(find.byType(AppBarTextAction))
    .firstWhere((a) => a.label == label);

/// Taps the bar's [label] action and settles.
Future<void> tapBar(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(AppBarTextAction, label));
  await tester.pumpAndSettle();
}

/// Back, as the system back gesture does.
Future<void> back(WidgetTester tester) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
  unawaited(navigator.maybePop());
  await tester.pumpAndSettle();
}

/// Types [text] into the field labelled [label].
Future<void> typeInto(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextFormField, label), text);
  await tester.pump();
}

/// A switch of the active diver as the diver switcher makes it: the app is
/// asked first (`diver_switcher_sheet.dart`).
Future<void> switchAsTheSwitcherDoes(WidgetTester tester, String id) async {
  final container = profileContainer(tester);
  final guard = container.read(appExitGuardProvider);
  final notifier = container.read(currentDiverIdProvider.notifier);
  unawaited(() async {
    if (await guard.mayLeave()) await notifier.setCurrentDiver(id);
  }());
  await tester.pumpAndSettle();
}

/// A switch of the active diver that asks nothing, as the misplaced
/// logbook banner makes it.
Future<void> switchWithoutAsking(WidgetTester tester, String id) async {
  unawaited(
    profileContainer(
      tester,
    ).read(currentDiverIdProvider.notifier).setCurrentDiver(id),
  );
  await tester.pumpAndSettle();
}

/// The editing sittings written, decoded: the setup's own writes are not
/// sittings.
Future<List<({String table, String? id, List<String> cardIds})>> sittings(
  AppDatabase db,
) async {
  final rows = await db
      .customSelect(
        "SELECT label FROM change_log_operations "
        "WHERE label LIKE 'record_edit:%'",
      )
      .get();
  return [
    for (final row in rows) RecordEditLabel.decode(row.read<String>('label'))!,
  ];
}

/// Removes diver [id] and its settings row through the database, as a sync
/// applying a delete from another device would: watchers are told.
Future<void> deleteDiverRow(AppDatabase db, String id) async {
  await (db.delete(db.diverSettings)..where((t) => t.diverId.equals(id))).go();
  await (db.delete(db.divers)..where((t) => t.id.equals(id))).go();
}
