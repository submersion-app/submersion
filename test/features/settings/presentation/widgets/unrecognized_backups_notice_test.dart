import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/settings/presentation/widgets/unrecognized_backups_notice.dart';

class _Holder extends ConsumerWidget {
  const _Holder({required this.capture});

  final void Function(BuildContext context, WidgetRef ref) capture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    capture(context, ref);
    return const SizedBox.shrink();
  }
}

void main() {
  testWidgets('the refresh is a no-op once the page it belongs to is gone', (
    tester,
  ) async {
    // The notice awaits a push, so the refresh runs an unbounded time later.
    // A WidgetRef whose element has been unmounted throws StateError on
    // invalidate, which would surface as an unhandled error from a tap the
    // user made on a page they have already left.
    late BuildContext context;
    late WidgetRef ref;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: _Holder(
            capture: (c, r) {
              context = c;
              ref = r;
            },
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SizedBox.shrink())),
    );
    expect(context.mounted, isFalse);

    expect(() => refreshAfterUnrecognizedReview(context, ref), returnsNormally);
  });
}
