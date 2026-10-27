import 'dart:typed_data';

/// Cuts a byte stream into Bluetooth writes or notifications. The link's
/// frame decoder reassembles on the other side, so chunks carry no header.
abstract final class BleChunker {
  /// The ATT payload an MTU leaves (3 bytes of ATT header), never below
  /// the 20 bytes every link supports.
  static int payloadSize(int? mtu) {
    final size = (mtu ?? 23) - 3;
    return size < 20 ? 20 : size;
  }

  static List<Uint8List> split(Uint8List bytes, int mtu) {
    final size = payloadSize(mtu);
    return [
      for (var start = 0; start < bytes.length; start += size)
        Uint8List.sublistView(
          bytes,
          start,
          start + size > bytes.length ? bytes.length : start + size,
        ),
    ];
  }
}
