import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

/// One download's evidence that [serial] sat in [slot] (0 based) on computer
/// [computerId] on the dive dated [date] (issue #4347).
class SlotObservation {
  final String computerId;
  final int slot;
  final DateTime date;
  final String serial;

  const SlotObservation({
    required this.computerId,
    required this.slot,
    required this.date,
    required this.serial,
  });
}

/// Which serial a slot resolves to on a date, and how sure that is.
class SlotResolution {
  /// The serial that held the slot, or null when none did or it is unknown.
  final String? serial;

  /// True when the date is before every download that showed the slot, so
  /// the serial rests on the pairing not having changed since.
  final bool olderThanFirstDownload;

  /// True when downloads before and after the date show different serials:
  /// the slot changed hands somewhere in that gap.
  final bool changedHands;

  /// The first download that showed the slot, set when
  /// [olderThanFirstDownload] is.
  final DateTime? firstDownload;

  const SlotResolution({
    this.serial,
    this.olderThanFirstDownload = false,
    this.changedHands = false,
    this.firstDownload,
  });

  static const none = SlotResolution();
}

/// For each (computer, slot), the serials its downloads showed over time.
class TransmitterSlotTimeline {
  final Map<(String, int), List<SlotObservation>> _byKey;

  TransmitterSlotTimeline._(this._byKey);

  factory TransmitterSlotTimeline(Iterable<SlotObservation> observations) {
    final byKey = <(String, int), List<SlotObservation>>{};
    for (final o in observations) {
      final serial = normalizeTransmitterSerial(o.serial);
      if (serial == null) continue;
      byKey
          .putIfAbsent((o.computerId, o.slot), () => [])
          .add(
            SlotObservation(
              computerId: o.computerId,
              slot: o.slot,
              date: o.date,
              serial: serial,
            ),
          );
    }
    for (final list in byKey.values) {
      list.sort((a, b) => a.date.compareTo(b.date));
    }
    return TransmitterSlotTimeline._(byKey);
  }

  /// The serial in [slot] on [computerId] on [date]: the downloads on either
  /// side agree, or the date lies outside them and the nearest one decides.
  SlotResolution resolve(String computerId, int slot, DateTime date) {
    final list = _byKey[(computerId, slot)];
    if (list == null || list.isEmpty) return SlotResolution.none;
    SlotObservation? prev;
    SlotObservation? next;
    for (final o in list) {
      if (!o.date.isAfter(date)) prev = o;
      if (next == null && !o.date.isBefore(date)) next = o;
    }
    if (prev != null && next != null) {
      return prev.serial == next.serial
          ? SlotResolution(serial: prev.serial)
          : const SlotResolution(changedHands: true);
    }
    if (prev != null) return SlotResolution(serial: prev.serial);
    return SlotResolution(
      serial: next!.serial,
      olderThanFirstDownload: true,
      firstDownload: next.date,
    );
  }
}
