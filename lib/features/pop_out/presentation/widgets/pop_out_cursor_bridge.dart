import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/pop_out/domain/pop_out_messages.dart';
import 'package:submersion/features/pop_out/presentation/providers/pop_out_host.dart';
import 'package:submersion/features/pop_out/presentation/providers/pop_out_providers.dart';

/// Shares [diveId]'s profile cursor with the pop-out (issue #5078).
///
/// Sits beside the dive's chart, where the series the cursor indexes is
/// known, and turns indexes into dive seconds and back: each window builds
/// its own series, so seconds are what they share. Adds nothing to [child].
class PopOutCursorBridge extends ConsumerWidget {
  const PopOutCursorBridge({
    super.key,
    required this.diveId,
    required this.chartProfile,
    required this.child,
  });

  final String diveId;
  final List<DiveProfilePoint> chartProfile;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(popOutAvailableProvider)) return child;
    ref.listen<int?>(profileTrackingIndexProvider(diveId), (_, index) {
      final seconds = index == null || index < 0 || index >= chartProfile.length
          ? null
          : chartProfile[index].timestamp;
      ref.read(popOutHostProvider.notifier).sendCursor(diveId, seconds);
    });
    ref.listen<CursorMessage?>(popOutInboundCursorProvider, (_, message) {
      if (message == null || message.diveId != diveId) return;
      setProfileCursorSeconds(ref, diveId, chartProfile, message.seconds);
    });
    return child;
  }
}
