import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

void main() {
  Future<DiveNeighbors> neighborsFor(List<String> ids, String id) async {
    final container = ProviderContainer(
      overrides: [orderedDiveIdsProvider.overrideWith((ref) async => ids)],
    );
    addTearDown(container.dispose);
    await container.read(orderedDiveIdsProvider.future);
    return container.read(diveNeighborsProvider(id));
  }

  test('middle item has both neighbors', () async {
    expect(await neighborsFor(['a', 'b', 'c'], 'b'), (
      previousId: 'a',
      nextId: 'c',
    ));
  });

  test('first item has no previous', () async {
    expect(await neighborsFor(['a', 'b', 'c'], 'a'), (
      previousId: null,
      nextId: 'b',
    ));
  });

  test('last item has no next', () async {
    expect(await neighborsFor(['a', 'b', 'c'], 'c'), (
      previousId: 'b',
      nextId: null,
    ));
  });

  test('id not in list has no neighbors', () async {
    expect(await neighborsFor(['a', 'b', 'c'], 'z'), (
      previousId: null,
      nextId: null,
    ));
  });

  test('single item has no neighbors', () async {
    expect(await neighborsFor(['only'], 'only'), (
      previousId: null,
      nextId: null,
    ));
  });
}
