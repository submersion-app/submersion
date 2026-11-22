import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/new_record_diver.dart';

/// The diver a new record is made for (issue #4527, phase 3, plan 11).
void main() {
  ProviderContainer container(Future<String?> Function() diver) {
    final c = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) => diver()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('is the active diver', () async {
    final c = container(() async => 'd1');

    expect(await newRecordDiverId(c.read, record: 'buddy'), 'd1');
  });

  test('is none when there is no active diver', () async {
    final c = container(() async => null);

    expect(await newRecordDiverId(c.read, record: 'buddy'), isNull);
  });

  test('is none when the diver cannot be read', () async {
    final c = container(() async => throw StateError('no database'));

    expect(await newRecordDiverId(c.read, record: 'buddy'), isNull);
  });
}
