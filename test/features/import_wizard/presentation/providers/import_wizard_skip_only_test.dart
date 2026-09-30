import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';

/// A duplicate whose only possible action is Skip needs no decision: it is
/// skipped by default and never holds the Import button (cylinder
/// passports phase 5, where a fill already here can only be skipped).
class _SkipOnlyFillsAdapter implements ImportSourceAdapter {
  @override
  String get defaultTagName => 'Test Import';

  @override
  Set<DuplicateAction> get supportedDuplicateActions => const {
    DuplicateAction.skip,
    DuplicateAction.importAsNew,
  };

  @override
  Set<DuplicateAction> duplicateActionsFor(ImportEntityType type) =>
      type == ImportEntityType.fills
      ? const {DuplicateAction.skip}
      : supportedDuplicateActions;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

EntityGroup _group(int count, Set<int> duplicates) => EntityGroup(
  items: [
    for (var i = 0; i < count; i++) EntityItem(title: '$i', subtitle: ''),
  ],
  duplicateIndices: duplicates,
);

void main() {
  late ImportWizardNotifier notifier;
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        importWizardNotifierProvider.overrideWith(
          (ref) => ImportWizardNotifier(_SkipOnlyFillsAdapter()),
        ),
      ],
    );
    addTearDown(container.dispose);
    notifier = container.read(importWizardNotifierProvider.notifier);
  });

  test('a fill already here defaults to Skip and leaves Import open', () {
    notifier.setBundle(
      ImportBundle(
        source: const ImportSourceInfo(
          type: ImportSourceType.uddf,
          displayName: 'fills.csv',
        ),
        groups: {
          ImportEntityType.fills: _group(3, {0, 2}),
        },
      ),
    );

    final state = container.read(importWizardNotifierProvider);
    expect(state.hasPendingReviews, isFalse);
    expect(state.selections[ImportEntityType.fills], {1});
    expect(state.duplicateActions[ImportEntityType.fills], {
      0: DuplicateAction.skip,
      2: DuplicateAction.skip,
    });
  });

  test('a type with a real choice still waits for a decision', () {
    notifier.setBundle(
      ImportBundle(
        source: const ImportSourceInfo(
          type: ImportSourceType.uddf,
          displayName: 'sites.csv',
        ),
        groups: {
          ImportEntityType.sites: _group(2, {1}),
        },
      ),
    );

    final state = container.read(importWizardNotifierProvider);
    expect(state.pendingDuplicateReview[ImportEntityType.sites], {1});
  });
}
