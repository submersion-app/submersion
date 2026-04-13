import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';

/// Regression test for https://github.com/submersion-app/submersion/issues/200.
///
/// Suspected-duplicate rows (probable OR possible) must not receive a silent
/// default action. The Import button stays gated until the user explicitly
/// decides for every flagged duplicate.
///
/// Before this fix:
///   - Probable duplicates (score >= 0.7) auto-defaulted to skip.
///   - Possible duplicates (0.5 <= score < 0.7) auto-defaulted to importAsNew.
/// After the fix:
///   - Both enter pendingDuplicateReview and receive NO default action.
///   - The user must call setDuplicateAction or applyBulkAction to resolve.
///
/// This file inlines its fixtures so it is not affected by helper refactors
/// in other test files.
void main() {
  group('issue #200: suspected duplicates require explicit selection', () {
    test('probable duplicate is pending and has NO default action', () {
      final container = _freshContainer();
      final notifier = container.read(importWizardNotifierProvider.notifier);

      notifier.setBundle(_bundleWithProbableDuplicate());

      final state = container.read(importWizardNotifierProvider);
      expect(state.pendingFor(ImportEntityType.dives), {0});
      expect(
        state.duplicateActions[ImportEntityType.dives],
        anyOf(isNull, isEmpty),
        reason:
            'No auto-default skip/importAsNew may be recorded — this would '
            're-introduce the issue #200 silent-default bug.',
      );
    });

    test('possible duplicate is pending and has NO default action', () {
      final container = _freshContainer();
      final notifier = container.read(importWizardNotifierProvider.notifier);

      notifier.setBundle(_bundleWithPossibleDuplicate());

      final state = container.read(importWizardNotifierProvider);
      expect(state.pendingFor(ImportEntityType.dives), {0});
      expect(
        state.duplicateActions[ImportEntityType.dives],
        anyOf(isNull, isEmpty),
      );
    });

    test('explicit skip resolves pending', () {
      final container = _freshContainer();
      final notifier = container.read(importWizardNotifierProvider.notifier);

      notifier.setBundle(_bundleWithProbableDuplicate());
      expect(
        container.read(importWizardNotifierProvider).hasPendingReviews,
        isTrue,
      );

      notifier.setDuplicateAction(
        ImportEntityType.dives,
        0,
        DuplicateAction.skip,
      );

      final state = container.read(importWizardNotifierProvider);
      expect(state.hasPendingReviews, isFalse);
      expect(
        state.duplicateActions[ImportEntityType.dives]?[0],
        DuplicateAction.skip,
      );
    });

    test('bulk skip resolves pending', () {
      final container = _freshContainer();
      final notifier = container.read(importWizardNotifierProvider.notifier);

      notifier.setBundle(_bundleWithProbableDuplicate());
      notifier.applyBulkAction(ImportEntityType.dives, DuplicateAction.skip);

      final state = container.read(importWizardNotifierProvider);
      expect(state.hasPendingReviews, isFalse);
    });

    test('importAsNew resolves pending and selects the dive', () {
      final container = _freshContainer();
      final notifier = container.read(importWizardNotifierProvider.notifier);

      notifier.setBundle(_bundleWithProbableDuplicate());
      notifier.setDuplicateAction(
        ImportEntityType.dives,
        0,
        DuplicateAction.importAsNew,
      );

      final state = container.read(importWizardNotifierProvider);
      expect(state.hasPendingReviews, isFalse);
      expect(state.selections[ImportEntityType.dives], contains(0));
    });
  });
}

ProviderContainer _freshContainer() {
  final container = ProviderContainer(
    overrides: [
      importWizardNotifierProvider.overrideWith(
        (ref) => ImportWizardNotifier(_TestAdapter()),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

ImportBundle _bundleWithProbableDuplicate() {
  return const ImportBundle(
    source: ImportSourceInfo(
      type: ImportSourceType.uddf,
      displayName: 'probable.uddf',
    ),
    groups: {
      ImportEntityType.dives: EntityGroup(
        items: [EntityItem(title: 'Dive 1', subtitle: '')],
        duplicateIndices: {0},
        matchResults: {
          0: DiveMatchResult(
            diveId: 'existing-1',
            score: 0.9,
            timeDifferenceMs: 0,
            depthDifferenceMeters: 0.0,
            durationDifferenceSeconds: 0,
          ),
        },
      ),
    },
  );
}

ImportBundle _bundleWithPossibleDuplicate() {
  return const ImportBundle(
    source: ImportSourceInfo(
      type: ImportSourceType.uddf,
      displayName: 'possible.uddf',
    ),
    groups: {
      ImportEntityType.dives: EntityGroup(
        items: [EntityItem(title: 'Dive 1', subtitle: '')],
        duplicateIndices: {0},
        matchResults: {
          0: DiveMatchResult(
            diveId: 'existing-1',
            score: 0.55,
            timeDifferenceMs: 600000,
            depthDifferenceMeters: 3.0,
            durationDifferenceSeconds: 480,
          ),
        },
      ),
    },
  );
}

class _TestAdapter implements ImportSourceAdapter {
  @override
  String get defaultTagName => 'Test Import';

  @override
  Set<DuplicateAction> get supportedDuplicateActions => const {
    DuplicateAction.skip,
    DuplicateAction.importAsNew,
    DuplicateAction.consolidate,
  };

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
