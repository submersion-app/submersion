import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';

/// Issue #2002: the review step's defaults and guards for the fill-planned
/// action. Only [ImportWizardNotifier.setBundle], [applyBulkAction] and
/// [setDuplicateAction] are exercised, so the adapter answers only what
/// they read and throws on anything else.
class _FillAdapter implements ImportSourceAdapter {
  @override
  String get defaultTagName => 'Test Import';

  @override
  Set<DuplicateAction> get supportedDuplicateActions => const {
    DuplicateAction.skip,
    DuplicateAction.importAsNew,
    DuplicateAction.consolidate,
    DuplicateAction.replaceSource,
    DuplicateAction.fillPlanned,
  };

  @override
  Set<DuplicateAction> duplicateActionsFor(ImportEntityType type) =>
      supportedDuplicateActions;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

ImportBundle _bundle(Map<int, DiveMatchResult> matches) {
  return ImportBundle(
    source: const ImportSourceInfo(
      type: ImportSourceType.diveComputer,
      displayName: 'Perdix',
    ),
    groups: {
      ImportEntityType.dives: EntityGroup(
        items: [
          for (var i = 0; i < 3; i++)
            EntityItem(title: 'Dive $i', subtitle: ''),
        ],
        duplicateIndices: matches.keys.toSet(),
        matchResults: matches,
      ),
    },
  );
}

const _plannedMatch = DiveMatchResult(
  diveId: 'p1',
  score: 1,
  timeDifferenceMs: 0,
  plannedDiveId: 'p1',
);

const _fuzzyMatch = DiveMatchResult(
  diveId: 'existing',
  score: 0.85,
  timeDifferenceMs: 0,
);

void main() {
  late ProviderContainer container;
  late ImportWizardNotifier notifier;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        importWizardNotifierProvider.overrideWith(
          (ref) => ImportWizardNotifier(_FillAdapter()),
        ),
      ],
    );
    addTearDown(container.dispose);
    notifier = container.read(importWizardNotifierProvider.notifier);
  });

  ImportWizardState state() => container.read(importWizardNotifierProvider);

  test('setBundle pre-selects fillPlanned and keeps the row selected', () {
    notifier.setBundle(_bundle({0: _plannedMatch}));

    expect(
      state().duplicateActions[ImportEntityType.dives]![0],
      DuplicateAction.fillPlanned,
    );
    expect(state().selections[ImportEntityType.dives], contains(0));
    expect(state().pendingFor(ImportEntityType.dives), isEmpty);
  });

  test('a fuzzy match still needs a decision', () {
    notifier.setBundle(_bundle({0: _plannedMatch, 1: _fuzzyMatch}));

    expect(state().pendingFor(ImportEntityType.dives), {1});
    expect(
      state().duplicateActions[ImportEntityType.dives]!.containsKey(1),
      isFalse,
    );
  });

  test('applyBulkAction never applies fillPlanned', () {
    notifier.setBundle(_bundle({1: _fuzzyMatch, 2: _fuzzyMatch}));

    notifier.applyBulkAction(
      ImportEntityType.dives,
      DuplicateAction.fillPlanned,
    );

    expect(state().pendingFor(ImportEntityType.dives), {1, 2});
    expect(state().duplicateActions[ImportEntityType.dives] ?? {}, isEmpty);
  });

  test('switching a fill row to import-as-new keeps it selected', () {
    notifier.setBundle(_bundle({0: _plannedMatch}));

    notifier.setDuplicateAction(
      ImportEntityType.dives,
      0,
      DuplicateAction.importAsNew,
    );

    expect(
      state().duplicateActions[ImportEntityType.dives]![0],
      DuplicateAction.importAsNew,
    );
    expect(state().selections[ImportEntityType.dives], contains(0));
  });

  test('setPlannedFillTarget repoints the row and keeps fillPlanned', () {
    notifier.setBundle(_bundle({0: _plannedMatch}));

    notifier.setPlannedFillTarget(0, 'p2');

    final match =
        state().bundle!.groups[ImportEntityType.dives]!.matchResults![0]!;
    expect(match.plannedDiveId, 'p2');
    expect(match.diveId, 'p2');
    expect(
      state().duplicateActions[ImportEntityType.dives]![0],
      DuplicateAction.fillPlanned,
    );
  });

  test('setPlannedFillTarget(null) turns the row into a plain new import', () {
    notifier.setBundle(_bundle({0: _plannedMatch}));

    notifier.setPlannedFillTarget(0, null);

    // Not a match any more: an empty dive id would read as an in-batch
    // duplicate on the comparison card, so the match is removed outright.
    final group = state().bundle!.groups[ImportEntityType.dives]!;
    expect(group.matchResults!.containsKey(0), isFalse);
    expect(group.duplicateIndices, isNot(contains(0)));
    expect(
      state().duplicateActions[ImportEntityType.dives]?.containsKey(0) ?? false,
      isFalse,
    );
    expect(state().selections[ImportEntityType.dives], contains(0));
    expect(state().pendingFor(ImportEntityType.dives), isEmpty);
  });

  test('clearing one fill row leaves the others untouched', () {
    notifier.setBundle(_bundle({0: _plannedMatch, 1: _plannedMatch}));

    notifier.setPlannedFillTarget(0, null);

    final group = state().bundle!.groups[ImportEntityType.dives]!;
    expect(group.matchResults![1]!.plannedDiveId, 'p1');
    expect(
      state().duplicateActions[ImportEntityType.dives]![1],
      DuplicateAction.fillPlanned,
    );
  });
}
