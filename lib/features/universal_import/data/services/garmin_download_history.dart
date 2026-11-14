import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/universal_import/data/services/garmin_activity_marker.dart';

/// Remembers how far each Garmin watch has been downloaded (issue #4223).
abstract interface class GarminDownloadHistory {
  /// The marker saved for the watch: on the saved computer [computerId] when
  /// given, otherwise on the saved Garmin whose serial is [serialNumber].
  /// Null when there is none, or when [computerId] belongs to a different
  /// watch than [serialNumber].
  Future<GarminActivityMarker?> markerFor({
    String? computerId,
    String? serialNumber,
  });

  /// The serial number saved on the computer [computerId], which tells
  /// which connected watch it is. Null when the computer is unknown or has
  /// no serial.
  Future<String?> serialOf(String computerId);

  /// Moves the watch's marker on to [marker], never back. The computer is
  /// [computerId], or else the saved Garmin whose serial is [watchSerial],
  /// or else one of [fitSerials] (from the imported dives, which name the
  /// computer the import just matched or created). Returns false when no
  /// computer matches.
  Future<bool> save(
    GarminActivityMarker marker, {
    String? computerId,
    String? watchSerial,
    Iterable<String> fitSerials = const [],
  });
}

/// [GarminDownloadHistory] on the saved computer's `lastDiveFingerprint`,
/// so the marker syncs, and merges with its computer, like a download
/// cursor.
class RepositoryGarminDownloadHistory implements GarminDownloadHistory {
  RepositoryGarminDownloadHistory(this._repository, {required this.diverId});

  static const _log = LoggerService('GarminDownloadHistory');

  final DiveComputerRepository _repository;

  /// The active diver, whose computers are searched.
  final Future<String?> Function() diverId;

  @override
  Future<GarminActivityMarker?> markerFor({
    String? computerId,
    String? serialNumber,
  }) async {
    final computer = await _resolve(computerId, serialNumber, const []);
    return GarminActivityMarker.fromFingerprint(computer?.lastDiveFingerprint);
  }

  @override
  Future<String?> serialOf(String computerId) async =>
      _clean((await _repository.getComputerById(computerId))?.serialNumber);

  /// The save in progress, if any. Saves run one at a time: each reads the
  /// stored marker and writes the later of the two, so two interleaved (a
  /// superseded download finishing beside its replacement) could let the
  /// one holding the older marker write last and move the marker back.
  Future<void> _saving = Future<void>.value();

  @override
  Future<bool> save(
    GarminActivityMarker marker, {
    String? computerId,
    String? watchSerial,
    Iterable<String> fitSerials = const [],
  }) {
    final result = _saving.then(
      (_) => _saveNow(marker, computerId, watchSerial, fitSerials),
    );
    // The next save waits for this one whether or not it failed.
    _saving = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<bool> _saveNow(
    GarminActivityMarker marker,
    String? computerId,
    String? watchSerial,
    Iterable<String> fitSerials,
  ) async {
    final computer = await _resolve(computerId, watchSerial, fitSerials);
    if (computer == null) {
      _log.info('No saved Garmin for this watch; download marker not saved');
      return false;
    }
    final saved = GarminActivityMarker.fromFingerprint(
      computer.lastDiveFingerprint,
    );
    final next = marker.laterOf(saved);
    if (next != saved) {
      await _repository.updateLastFingerprint(
        computer.id,
        next.toFingerprint(),
      );
    }
    return true;
  }

  Future<DiveComputer?> _resolve(
    String? computerId,
    String? watchSerial,
    Iterable<String> fitSerials,
  ) async {
    final serial = _clean(watchSerial);
    if (computerId != null) {
      final computer = await _repository.getComputerById(computerId);
      // The diver may have plugged in a different Garmin than the one whose
      // Download they chose; that watch has its own marker.
      if (computer != null && !_isOtherWatch(computer, serial)) {
        return computer;
      }
    }
    final owner = await diverId();
    for (final candidate in [serial, ...fitSerials.map(_clean)]) {
      if (candidate == null) continue;
      final computer = await _repository.findByHardwareIdentity(
        manufacturer: 'Garmin',
        serialNumber: candidate,
        diverId: owner,
      );
      if (computer != null) return computer;
    }
    return null;
  }

  static bool _isOtherWatch(DiveComputer computer, String? watchSerial) {
    final saved = _clean(computer.serialNumber);
    return saved != null && watchSerial != null && saved != watchSerial;
  }

  static String? _clean(String? serial) {
    final trimmed = serial?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
