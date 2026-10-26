import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';

/// A Set up this device progress for widget tests, from the facts that
/// matter to them; [everything] settles every step by doing it.
SetUpProgress setUpProgressOf({
  bool accountHere = false,
  bool syncEstablished = false,
  bool backups = false,
  bool photosAttached = false,
  bool photosSkipped = false,
  bool hidden = false,
  bool everything = false,
}) => setUpProgress(
  SetUpInputs(
    accountHere: accountHere || everything,
    syncEstablished: syncEstablished || everything,
    customFolder: false,
    backupsAuto: backups || everything,
    backupOffDevice: backups || everything,
    photosAttached: photosAttached || everything,
    photosSkipped: photosSkipped,
    hidden: hidden,
  ),
);
