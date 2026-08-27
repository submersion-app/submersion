import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';

void main() {
  group('ImportWizardState.pendingDuplicateReview', () {
    test('defaults to empty map', () {
      const state = ImportWizardState();
      expect(state.pendingDuplicateReview, isEmpty);
    });

    test('hasPendingReviews false when all sets empty', () {
      const state = ImportWizardState(
        pendingDuplicateReview: {
          ImportEntityType.dives: <int>{},
          ImportEntityType.sites: <int>{},
        },
      );
      expect(state.hasPendingReviews, isFalse);
    });

    test('hasPendingReviews true when any set non-empty', () {
      const state = ImportWizardState(
        pendingDuplicateReview: {
          ImportEntityType.dives: <int>{},
          ImportEntityType.sites: {3},
        },
      );
      expect(state.hasPendingReviews, isTrue);
    });

    test('totalPending sums across types', () {
      const state = ImportWizardState(
        pendingDuplicateReview: {
          ImportEntityType.dives: {0, 1, 2},
          ImportEntityType.sites: {5},
        },
      );
      expect(state.totalPending, 4);
    });

    test('pendingFor returns empty for missing type', () {
      const state = ImportWizardState();
      expect(state.pendingFor(ImportEntityType.dives), isEmpty);
    });

    test('pendingFor returns set for present type', () {
      const state = ImportWizardState(
        pendingDuplicateReview: {
          ImportEntityType.dives: {1, 4},
        },
      );
      expect(state.pendingFor(ImportEntityType.dives), {1, 4});
    });

    test('copyWith updates pendingDuplicateReview', () {
      const state = ImportWizardState();
      final updated = state.copyWith(
        pendingDuplicateReview: {
          ImportEntityType.dives: {0, 1},
        },
      );
      expect(updated.pendingDuplicateReview[ImportEntityType.dives], {0, 1});
    });

    test('copyWith preserves pendingDuplicateReview when not passed', () {
      const state = ImportWizardState(
        pendingDuplicateReview: {
          ImportEntityType.dives: {2},
        },
      );
      final updated = state.copyWith(currentStep: 1);
      expect(updated.pendingDuplicateReview[ImportEntityType.dives], {2});
    });
  });
}
