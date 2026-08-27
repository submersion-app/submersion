import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/services/default_service_cost_resolver.dart';

ServiceKind kind(String id, {ServiceCategory? category}) {
  final now = DateTime(2026, 1, 1);
  return ServiceKind(
    id: id,
    name: id,
    defaultCategory: category,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('returns the kind default', () {
    expect(
      resolveDefaultServiceCategory(
        serviceKindId: 'hydro',
        kinds: [kind('hydro', category: ServiceCategory.inspection)],
      ),
      ServiceCategory.inspection,
    );
  });

  test('returns null for a kind with no default', () {
    expect(
      resolveDefaultServiceCategory(
        serviceKindId: 'disinfect',
        kinds: [kind('disinfect')],
      ),
      isNull,
    );
  });

  test('returns null when no kind is selected', () {
    expect(
      resolveDefaultServiceCategory(
        serviceKindId: null,
        kinds: [kind('hydro', category: ServiceCategory.inspection)],
      ),
      isNull,
    );
  });

  test('returns null for an id absent from the catalog', () {
    expect(
      resolveDefaultServiceCategory(
        serviceKindId: 'deleted-kind',
        kinds: [kind('hydro', category: ServiceCategory.inspection)],
      ),
      isNull,
    );
  });

  test('picks the matching kind out of several', () {
    expect(
      resolveDefaultServiceCategory(
        serviceKindId: 'o2-clean',
        kinds: [
          kind('hydro', category: ServiceCategory.inspection),
          kind('o2-clean', category: ServiceCategory.cleaning),
          kind('drysuit-seals', category: ServiceCategory.repair),
        ],
      ),
      ServiceCategory.cleaning,
    );
  });
}
