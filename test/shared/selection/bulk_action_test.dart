import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/selection/bulk_action.dart';

void main() {
  BulkAction build({
    int minCount = 1,
    int? maxCount,
    bool alwaysEnabled = false,
  }) => BulkAction(
    id: 'merge',
    icon: Icons.merge_type,
    label: 'Merge',
    minCount: minCount,
    maxCount: maxCount,
    alwaysEnabled: alwaysEnabled,
    onInvoke: () {},
  );

  group('BulkAction.isEnabledFor', () {
    test('is disabled below minCount', () {
      expect(build(minCount: 2).isEnabledFor(1), isFalse);
    });

    test('is enabled at minCount', () {
      expect(build(minCount: 2).isEnabledFor(2), isTrue);
    });

    test('is enabled above minCount when there is no maximum', () {
      expect(build(minCount: 2).isEnabledFor(9), isTrue);
    });

    test('is disabled above maxCount', () {
      expect(build(minCount: 2, maxCount: 4).isEnabledFor(5), isFalse);
    });

    test('is enabled at maxCount', () {
      expect(build(minCount: 2, maxCount: 4).isEnabledFor(4), isTrue);
    });

    test('is disabled at zero regardless of configuration', () {
      expect(build(minCount: 0).isEnabledFor(0), isFalse);
    });

    test('alwaysEnabled overrides the zero-selection rule', () {
      expect(build(alwaysEnabled: true).isEnabledFor(0), isTrue);
    });

    test('alwaysEnabled overrides minCount', () {
      expect(build(minCount: 5, alwaysEnabled: true).isEnabledFor(1), isTrue);
    });

    test('an isEnabled predicate can veto an otherwise valid selection', () {
      final action = BulkAction(
        id: 'retire',
        icon: Icons.archive,
        label: 'Retire',
        onInvoke: () {},
        isEnabled: (ids) => ids.every((id) => id.startsWith('active-')),
      );
      expect(action.isEnabledForSelection(2, {'active-1', 'active-2'}), isTrue);
      expect(
        action.isEnabledForSelection(2, {'active-1', 'retired-2'}),
        isFalse,
        reason: 'a mixed selection must not enable a uniform-only action',
      );
    });

    test('isEnabled cannot rescue a count that is already invalid', () {
      final action = BulkAction(
        id: 'merge',
        icon: Icons.merge_type,
        label: 'Merge',
        minCount: 2,
        onInvoke: () {},
        isEnabled: (ids) => true,
      );
      expect(action.isEnabledForSelection(1, {'a'}), isFalse);
    });

    test('defaults to non-destructive and not always enabled', () {
      final action = build();
      expect(action.isDestructive, isFalse);
      expect(action.alwaysEnabled, isFalse);
    });
  });
}
