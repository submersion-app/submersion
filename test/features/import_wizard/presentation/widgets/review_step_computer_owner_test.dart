import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/import_target_choice.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/computer_owner_notice.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/review_step.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';

// Issue #2050: the review step of a download from another profile's computer
// shows where the dives go, lets the diver pick another profile, and numbers
// the dives in the chosen profile's log.

class _Adapter implements ImportSourceAdapter, RetargetableImportAdapter {
  _Adapter({this.offersFill = false});

  final bool offersFill;
  String target = 'mitchell';

  @override
  Future<void> setTargetDiver(String diverId) async => target = diverId;

  @override
  Future<ImportBundle> buildBundle() async => _bundle(target);

  @override
  Future<ImportBundle> checkDuplicates(ImportBundle bundle) async => bundle;

  @override
  void resetState() {}
  @override
  ImportSourceType get sourceType => ImportSourceType.diveComputer;
  @override
  String get displayName => 'Perdix 2';
  @override
  String get defaultTagName => 'Perdix Import';
  @override
  List<WizardStepDef> get acquisitionSteps => const [];
  @override
  Set<DuplicateAction> get supportedDuplicateActions => {
    DuplicateAction.skip,
    DuplicateAction.importAsNew,
    if (offersFill) DuplicateAction.fillPlanned,
  };
  @override
  Set<DuplicateAction> duplicateActionsFor(ImportEntityType type) =>
      supportedDuplicateActions;
  @override
  Future<UnifiedImportResult> performImport(
    ImportBundle bundle,
    Map<ImportEntityType, Set<int>> selections,
    Map<ImportEntityType, Map<int, DuplicateAction>> duplicateActions, {
    bool retainSourceDiveNumbers = false,
    ImportProgressCallback? onProgress,
    ImportCancellationToken? cancelToken,
  }) => throw UnimplementedError();
}

ImportBundle _bundle(String? chosen) => ImportBundle(
  source: const ImportSourceInfo(
    type: ImportSourceType.diveComputer,
    displayName: 'Perdix 2',
  ),
  groups: {
    ImportEntityType.dives: const EntityGroup(
      items: [EntityItem(title: 'Dive 1', subtitle: '18 m')],
    ),
  },
  targetChoice: chosen == null
      ? null
      : ImportTargetChoice(ownerDiverId: 'mitchell', chosenDiverId: chosen),
);

Diver _diver(String id, String name) => Diver(
  id: id,
  name: name,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester,
    String? chosen, {
    bool offersFill = false,
    List<String?>? plannedFor,
  }) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final adapter = _Adapter(offersFill: offersFill);
    final container = ProviderContainer(
      overrides: [
        importWizardNotifierProvider.overrideWith(
          (ref) => ImportWizardNotifier(adapter),
        ),
        allDiversProvider.overrideWith(
          (ref) async => [
            _diver('bill', 'Bill'),
            _diver('mitchell', 'Mitchell'),
          ],
        ),
        nextDiveNumberProvider.overrideWith((ref) async => 7),
        plannedFillCandidatesProvider.overrideWith((ref, diverId) async {
          plannedFor?.add(diverId);
          return const <Dive>[];
        }),
        nextDiveNumberForDiverProvider.overrideWith(
          (ref, diverId) async => diverId == 'mitchell' ? 120 : 7,
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(importWizardNotifierProvider.notifier)
        .setBundle(_bundle(chosen));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ReviewStep(onImport: () {})),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('shows the notice for another profile\'s computer', (
    tester,
  ) async {
    await pump(tester, 'mitchell');

    expect(find.byType(ComputerOwnerNotice), findsOneWidget);
    expect(find.textContaining('belongs to Mitchell'), findsOneWidget);
  });

  testWidgets('shows no notice for an ordinary download', (tester) async {
    await pump(tester, null);

    expect(find.byType(ComputerOwnerNotice), findsNothing);
  });

  testWidgets("numbers the dives in the chosen profile's log", (tester) async {
    await pump(tester, 'mitchell');

    expect(find.text('#120'), findsOneWidget);
    expect(find.text('#7'), findsNothing);
  });

  testWidgets('picking another profile retargets the download', (tester) async {
    final container = await pump(tester, 'mitchell');

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bill').last);
    await tester.pumpAndSettle();

    final state = container.read(importWizardNotifierProvider);
    expect(state.bundle?.targetChoice?.chosenDiverId, 'bill');
    expect(find.textContaining("added to Bill's log"), findsOneWidget);
    expect(find.text('#7'), findsOneWidget);
  });
  testWidgets('holds Import while the download is re-checked', (tester) async {
    final container = await pump(tester, 'mitchell');
    final notifier = container.read(importWizardNotifierProvider.notifier);

    notifier.debugSetState(notifier.state.copyWith(isRetargeting: true));
    await tester.pump();

    final import = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Import Selected'),
    );
    expect(import.onPressed, isNull);
  });
  testWidgets("offers the chosen profile's planned dives to fill", (
    tester,
  ) async {
    final plannedFor = <String?>[];

    await pump(tester, 'mitchell', offersFill: true, plannedFor: plannedFor);

    expect(plannedFor, isNotEmpty);
    expect(plannedFor.toSet(), {'mitchell'});
  });
}
