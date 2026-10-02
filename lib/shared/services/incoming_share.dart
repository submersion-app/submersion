import 'dart:typed_data';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/services/navigation_ready_gate.dart';

/// What arrived through the share sheet, held as data so that whichever app
/// root is current once it can be opened is the one that opens it.
sealed class IncomingShare {
  const IncomingShare();
}

/// One shared file, already read.
final class SharedFile extends IncomingShare {
  const SharedFile(this.bytes, this.fileName);

  final Uint8List bytes;
  final String fileName;
}

/// Several files shared at once, imported as one batch (#1635).
final class SharedFileBatch extends IncomingShare {
  const SharedFileBatch(this.paths);

  final List<String> paths;
}

/// Where share-sheet files wait until the app can open the page they lead
/// to (#2690).
///
/// A fresh gate per container by default, which is what tests of the app
/// root get. The app overrides it with one gate made once per process (see
/// `SubmersionRestart`), so a share held when `restartApp` replaces the
/// container (a restore from the setup wizard, say) still opens afterwards.
final incomingShareGateProvider = Provider<NavigationReadyGate<IncomingShare>>(
  (ref) => NavigationReadyGate<IncomingShare>(),
);
