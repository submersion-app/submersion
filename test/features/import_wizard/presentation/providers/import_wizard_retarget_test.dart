import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/import_target_choice.dart';
import 'package:submersion/features/import_wizard/domain/models/tag_selection.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';

// Issue #2050: choosing another profile on the review step re-checks the
// download against that profile's dives. Dive 0 duplicates one of
// Mitchell's dives and none of Bill's.

class _RetargetableAdapter
    implements ImportSourceAdapter, RetargetableImportAdapter {
  String target = 'mitchell';
  final targets = <String>[];
  bool failDuplicateCheck = false;
  String? failBuildFor;
  var imports = 0;

  /// When set, each duplicate check waits on the next gate in turn.
  final gates = <Completer<void>>[];
  var _checks = 0;

  @override
  Future<void> setTargetDiver(String diverId) async {
    targets.add(diverId);
    target = diverId;
  }

  @override
  Future<ImportBundle> buildBundle() async {
    if (target == failBuildFor) throw StateError('cannot build');
    return _bundleFor(target);
  }

  ImportBundle _bundleFor(String target) => ImportBundle(
    source: const ImportSourceInfo(
      type: ImportSourceType.diveComputer,
      displayName: 'Perdix 2',
    ),
    groups: {
      ImportEntityType.dives: const EntityGroup(
        items: [
          EntityItem(title: 'Dive 1', subtitle: ''),
          EntityItem(title: 'Dive 2', subtitle: ''),
        ],
      ),
    },
    targetChoice: ImportTargetChoice(
      ownerDiverId: 'mitchell',
      chosenDiverId: target,
    ),
  );

  @override
  Future<ImportBundle> checkDuplicates(ImportBundle bundle) async {
    final checking = bundle.targetChoice?.chosenDiverId;
    if (gates.isNotEmpty) await gates[_checks++].future;
    if (failDuplicateCheck) throw StateError('database is locked');
    if (checking != 'mitchell') return bundle;
    final dives = bundle.groups[ImportEntityType.dives]!;
    return ImportBundle(
      source: bundle.source,
      groups: {
        ImportEntityType.dives: EntityGroup(
          items: dives.items,
          duplicateIndices: const {0},
          matchResults: {
            0: const DiveMatchResult(
              diveId: 'mitchell-dive',
              score: 0.95,
              timeDifferenceMs: 0,
              matchedExistingSource: true,
            ),
          },
        ),
      },
      targetChoice: bundle.targetChoice,
    );
  }

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
  Set<DuplicateAction> get supportedDuplicateActions => const {
    DuplicateAction.skip,
    DuplicateAction.importAsNew,
    DuplicateAction.fillPlanned,
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
  }) async {
    imports++;
    return const UnifiedImportResult(
      importedCounts: {},
      consolidatedCount: 0,
      skippedCount: 0,
    );
  }
}

void main() {
  late _RetargetableAdapter adapter;
  late ImportWizardNotifier notifier;

  setUp(() async {
    adapter = _RetargetableAdapter();
    notifier = ImportWizardNotifier(adapter);
    notifier.setBundle(
      await adapter.checkDuplicates(await adapter.buildBundle()),
    );
    notifier.addImportTag(const TagSelection(name: 'Perdix Import'));
  });

  tearDown(() => notifier.dispose());

  test('starts with the owner and their duplicate skipped', () {
    expect(notifier.state.bundle?.targetChoice?.chosenDiverId, 'mitchell');
    expect(notifier.state.selections[ImportEntityType.dives], {1});
  });

  test('another profile re-checks the download against that profile', () async {
    await notifier.changeTargetDiver('bill');

    expect(adapter.targets, ['bill']);
    expect(notifier.state.bundle?.targetChoice?.chosenDiverId, 'bill');
    expect(notifier.state.selections[ImportEntityType.dives], {0, 1});
    expect(notifier.state.duplicateActions[ImportEntityType.dives], isNull);
    expect(notifier.state.importTags, const [
      TagSelection(name: 'Perdix Import'),
    ]);
  });

  test('a failed re-check keeps the rebuilt bundle unchecked', () async {
    adapter.failDuplicateCheck = true;

    await notifier.changeTargetDiver('bill');

    expect(notifier.state.bundle?.targetChoice?.chosenDiverId, 'bill');
    expect(notifier.state.selections[ImportEntityType.dives], {0, 1});
  });

  test('does nothing for a bundle with no choice', () async {
    notifier.setBundle(
      const ImportBundle(
        source: ImportSourceInfo(
          type: ImportSourceType.diveComputer,
          displayName: 'Perdix 2',
        ),
        groups: {},
      ),
    );

    await notifier.changeTargetDiver('bill');

    expect(adapter.targets, isEmpty);
  });
  test('a planned-fill edit keeps the choice', () {
    notifier.setPlannedFillTarget(0, 'planned-1');

    expect(notifier.state.bundle?.targetChoice?.chosenDiverId, 'mitchell');
  });

  test(
    'a choice made over edited rows resets them for the new profile',
    () async {
      notifier.setDuplicateAction(
        ImportEntityType.dives,
        0,
        DuplicateAction.importAsNew,
      );

      await notifier.changeTargetDiver('bill');

      expect(notifier.state.duplicateActions[ImportEntityType.dives], isNull);
      expect(notifier.state.selections[ImportEntityType.dives], {0, 1});
    },
  );

  test('reports that it is re-checking until the new bundle lands', () async {
    final gate = Completer<void>();
    adapter.gates.add(gate);

    final change = notifier.changeTargetDiver('bill');
    await Future<void>.delayed(Duration.zero);
    expect(notifier.state.isRetargeting, isTrue);

    gate.complete();
    await change;
    expect(notifier.state.isRetargeting, isFalse);
  });

  test('only the latest of overlapping changes lands', () async {
    final first = Completer<void>();
    final second = Completer<void>();
    adapter.gates.addAll([first, second]);

    final toBill = notifier.changeTargetDiver('bill');
    await Future<void>.delayed(Duration.zero);
    final backToMitchell = notifier.changeTargetDiver('mitchell');
    await Future<void>.delayed(Duration.zero);
    second.complete();
    await backToMitchell;
    first.complete();
    await toBill;

    expect(adapter.target, 'mitchell');
    expect(notifier.state.bundle?.targetChoice?.chosenDiverId, 'mitchell');
    expect(notifier.state.isRetargeting, isFalse);
  });

  test(
    'a failed re-check is reported, and a later success clears it',
    () async {
      adapter.failDuplicateCheck = true;
      await notifier.changeTargetDiver('bill');
      expect(notifier.state.duplicateCheckFailed, isTrue);

      adapter.failDuplicateCheck = false;
      await notifier.changeTargetDiver('mitchell');
      expect(notifier.state.duplicateCheckFailed, isFalse);
    },
  );

  test('setBundle records whether the duplicate check ran', () {
    final bundle = notifier.state.bundle!;
    notifier.setBundle(bundle, duplicateCheckFailed: true);
    expect(notifier.state.duplicateCheckFailed, isTrue);

    notifier.setBundle(bundle);
    expect(notifier.state.duplicateCheckFailed, isFalse);
  });
  test('a failed rebuild keeps the previous profile and its bundle', () async {
    adapter.failBuildFor = 'bill';

    await notifier.changeTargetDiver('bill');

    expect(adapter.target, 'mitchell');
    expect(notifier.state.bundle?.targetChoice?.chosenDiverId, 'mitchell');
    expect(notifier.state.isRetargeting, isFalse);
  });

  test('does not import while the download is re-checked', () async {
    final gate = Completer<void>();
    adapter.gates.add(gate);
    final change = notifier.changeTargetDiver('bill');
    await Future<void>.delayed(Duration.zero);

    await notifier.performImport();

    expect(adapter.imports, 0);
    gate.complete();
    await change;
  });
}
