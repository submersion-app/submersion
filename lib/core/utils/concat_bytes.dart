import 'dart:typed_data';

/// [a] followed by [b] in one new buffer, without boxing a byte.
///
/// A spread into a growable list (`[...a, ...b]`) allocates every byte as
/// an object before copying it, which on an 8 MiB sync part is tens of
/// megabytes of garbage on the UI isolate.
Uint8List concatBytes(List<int> a, List<int> b) =>
    Uint8List(a.length + b.length)
      ..setAll(0, a)
      ..setAll(a.length, b);
