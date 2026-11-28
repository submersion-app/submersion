import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_review_provider.dart';
import 'package:submersion/features/pop_out/domain/pop_out_messages.dart';
import 'package:submersion/features/pop_out/presentation/providers/pop_out_host.dart';
import 'package:submersion/features/pop_out/presentation/providers/pop_out_providers.dart';

/// Shares the main window's fullscreen profile cursor with the pop-out
/// (issue #5078), as `PopOutCursorBridge` does for the detail chart.
///
/// The fullscreen view keeps its cursor in dive seconds already, so a
/// received position is taken as sent. Adds nothing to [child].
class PopOutReviewBridge extends ConsumerWidget {
  const PopOutReviewBridge({
    super.key,
    required this.diveId,
    required this.child,
  });

  final String diveId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(popOutAvailableProvider)) return child;
    ref.listen<int?>(profileReviewProvider(diveId), (_, seconds) {
      ref.read(popOutHostProvider.notifier).sendCursor(diveId, seconds);
    });
    ref.listen<CursorMessage?>(popOutInboundCursorProvider, (_, message) {
      if (message == null || message.diveId != diveId) return;
      // The host noted this exact position as received: its landing here is
      // no move of the diver's.
      ref.read(profileReviewProvider(diveId).notifier).state = message.seconds;
    });
    return child;
  }
}
