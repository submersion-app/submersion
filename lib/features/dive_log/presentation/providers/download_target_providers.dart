import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';

/// The computer a draft's "Download now" opens (issue #637): the one the
/// diver downloaded from most recently, never the Apple Watch (its dives
/// come from Health, not a download), or null when none has been.
DiveComputer? pickDownloadTarget(List<DiveComputer> computers) {
  DiveComputer? best;
  for (final computer in computers) {
    final last = computer.lastDownload;
    if (last == null || computer.isAppleWatch) continue;
    if (best == null || last.isAfter(best.lastDownload!)) best = computer;
  }
  return best;
}

/// Where "Download now" goes: [computer]'s download, or the computer
/// picker when there is none.
String downloadRouteFor(DiveComputer? computer) => computer == null
    ? '/dive-computers'
    : '/dive-computers/${computer.id}/download';

/// [pickDownloadTarget] over the current diver's computers. Not autoDispose:
/// the draft banner reads its future once, with no listener.
final downloadTargetComputerProvider = FutureProvider<DiveComputer?>(
  (ref) async =>
      pickDownloadTarget(await ref.watch(allDiveComputersProvider.future)),
);
