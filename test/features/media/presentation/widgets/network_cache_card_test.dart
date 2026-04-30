// Widget tests for the Cache management card (Phase 3c, Task 8).
//
// Adapted from plan
// `docs/superpowers/plans/2026-04-28-media-source-extension-phase3c.md`
// Task 8. The hand-rolled `_StubDiag` mirrors the pattern in
// `network_sources_providers_test.dart` (Phase 3c Task 5): implementing
// `CachedNetworkImageDiagnostics` directly is supported because the only
// public surface used by the card is `cacheSize()` / `clearCache()`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/services/cached_network_image_diagnostics.dart';
import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';
import 'package:submersion/features/media/presentation/widgets/network_cache_card.dart';

class _StubDiag implements CachedNetworkImageDiagnostics {
  _StubDiag({required this.initialSize});
  int initialSize;
  bool cleared = false;
  @override
  Future<int> cacheSize() async => cleared ? 0 : initialSize;
  @override
  Future<void> clearCache() async {
    cleared = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

Widget _wrap(_StubDiag diag) => ProviderScope(
  overrides: [cachedNetworkImageDiagnosticsProvider.overrideWithValue(diag)],
  child: const MaterialApp(home: Scaffold(body: NetworkCacheCard())),
);

void main() {
  testWidgets('shows the human-formatted cache size', (tester) async {
    await tester.pumpWidget(_wrap(_StubDiag(initialSize: 1024 * 1024 * 5)));
    await tester.pumpAndSettle();
    expect(find.textContaining('5.0 MB'), findsOneWidget);
  });

  testWidgets('clear cache empties cache and refreshes', (tester) async {
    final diag = _StubDiag(initialSize: 4096);
    await tester.pumpWidget(_wrap(diag));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear cache'));
    await tester.pumpAndSettle();
    // Confirm
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(diag.cleared, true);
    expect(find.textContaining('0 B'), findsOneWidget);
  });

  testWidgets('renders shimmer/loading row while size lookup is running', (
    tester,
  ) async {
    final diag = _StubDiag(initialSize: 0);
    await tester.pumpWidget(_wrap(diag));
    expect(find.text('Calculating cache size…'), findsOneWidget);
  });
}
