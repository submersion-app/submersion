import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_query_providers.dart';

/// The certification a list returned to reopens: its last-opened one, while the
/// list still shows it (#3301).
void main() {
  AsyncValue<String?> remembered(String? highlighted) {
    final container = ProviderContainer(
      overrides: [
        filteredCertificationsProvider.overrideWithValue(
          AsyncData([
            Certification(
              id: 'r1',
              name: 'Open Water',
              agency: 'padi',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(highlightedCertificationIdProvider.notifier).state =
        highlighted;
    return container.read(rememberedCertificationIdProvider);
  }

  test('a listed certification is remembered', () {
    expect(remembered('r1'), const AsyncData<String?>('r1'));
  });

  test('a certification the list does not show is not', () {
    expect(remembered('gone'), const AsyncData<String?>(null));
  });
}
