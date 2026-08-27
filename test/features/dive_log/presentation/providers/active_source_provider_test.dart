import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';

void main() {
  test('defaults to null (primary) and is settable per dive', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(activeDiveSourceProvider('dive-1')), isNull);
    container.read(activeDiveSourceProvider('dive-1').notifier).state = 'src-b';
    expect(container.read(activeDiveSourceProvider('dive-1')), 'src-b');
    expect(container.read(activeDiveSourceProvider('dive-2')), isNull);
  });

  test('overlay set defaults empty and toggles per dive', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(overlaySourcesProvider('dive-1')), isEmpty);
    container.read(overlaySourcesProvider('dive-1').notifier).state = {'src-b'};
    expect(container.read(overlaySourcesProvider('dive-1')), {'src-b'});
    expect(container.read(overlaySourcesProvider('dive-2')), isEmpty);
  });
}
