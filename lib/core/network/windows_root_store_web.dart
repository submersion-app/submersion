import 'dart:typed_data';

/// Browser variant: the browser verifies certificates itself, so there is no
/// store to read and nothing to hand to a `SecurityContext`.
List<Uint8List> readWindowsRootCertificates() => const [];
