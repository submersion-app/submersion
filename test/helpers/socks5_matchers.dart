import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/socks5_connector.dart';

/// Throws a [Socks5Exception] with [failure].
Matcher throwsSocks5(Socks5Failure failure) => throwsA(
  isA<Socks5Exception>().having((e) => e.failure, 'failure', failure),
);
