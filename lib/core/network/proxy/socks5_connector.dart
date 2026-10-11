import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

enum Socks5Failure {
  proxyUnreachable,
  noAcceptableAuth,
  authRejected,
  generalFailure,
  notAllowed,
  networkUnreachable,
  hostUnreachable,
  connectionRefused,
  ttlExpired,
  commandNotSupported,
  addressTypeNotSupported,
  protocolError,
  hostnameTooLong,
  handshakeTimeout,
}

/// A SOCKS5 failure. A [SocketException], so every caller that already treats
/// socket errors as "the network is down" keeps doing so.
class Socks5Exception extends SocketException {
  const Socks5Exception(this.failure, {String? detail})
    : super(detail ?? 'SOCKS5 proxy error');

  final Socks5Failure failure;

  @override
  String toString() => 'Socks5Exception(${failure.name}): $message';
}

const _replyFailures = {
  1: Socks5Failure.generalFailure,
  2: Socks5Failure.notAllowed,
  3: Socks5Failure.networkUnreachable,
  4: Socks5Failure.hostUnreachable,
  5: Socks5Failure.connectionRefused,
  6: Socks5Failure.ttlExpired,
  7: Socks5Failure.commandNotSupported,
  8: Socks5Failure.addressTypeNotSupported,
};

/// Opens a TCP connection to [targetHost]:[targetPort] through the SOCKS5
/// server at [proxyHost]:[proxyPort] (RFC 1928), authenticating with RFC 1929
/// username and password when [username] is set.
///
/// A hostname target is sent as a name, so the proxy resolves DNS (some
/// networks only resolve public names at the proxy). IP literals go as
/// address types 1 and 4.
///
/// The handshake uses the socket's only listener; see [Socks5Tunnel] for
/// how https and http each take the open tunnel over.
///
/// The handshake has its own [handshakeTimeout]: most clients set no
/// connection timeout, and a port that accepts TCP but never answers would
/// otherwise hold the request forever.
Future<Socks5Tunnel> connectViaSocks5({
  required String proxyHost,
  required int proxyPort,
  required String targetHost,
  required int targetPort,
  String? username,
  String? password,
  Duration handshakeTimeout = const Duration(seconds: 30),
}) async {
  var host = targetHost;
  if (host.startsWith('[') && host.endsWith(']')) {
    host = host.substring(1, host.length - 1);
  }
  final literal = InternetAddress.tryParse(host);
  final nameBytes = utf8.encode(host);
  if (literal == null && nameBytes.length > 255) {
    throw const Socks5Exception(Socks5Failure.hostnameTooLong);
  }

  // One deadline for the TCP connect and the handshake together: an
  // unreachable proxy host would otherwise wait for the OS connect timeout,
  // and a slow connect must not restart the clock for the handshake.
  final deadline = DateTime.now().add(handshakeTimeout);
  final Socket socket;
  try {
    socket = await Socket.connect(
      proxyHost,
      proxyPort,
      timeout: handshakeTimeout,
    );
  } on SocketException catch (e) {
    throw Socks5Exception(
      Socks5Failure.proxyUnreachable,
      detail:
          'Could not reach SOCKS5 proxy $proxyHost:$proxyPort: ${e.message}',
    );
  }

  final pending = <int>[];
  var waiter = Completer<void>();
  var closed = false;
  void wake() {
    if (!waiter.isCompleted) waiter.complete();
  }

  final sub = socket.listen(
    (data) {
      pending.addAll(data);
      wake();
    },
    onDone: () {
      closed = true;
      wake();
    },
    onError: (Object _) {
      closed = true;
      wake();
    },
  );

  Future<List<int>> need(int n) async {
    while (pending.length < n) {
      if (closed) {
        throw const Socks5Exception(
          Socks5Failure.protocolError,
          detail: 'SOCKS5 proxy closed the connection',
        );
      }
      waiter = Completer<void>();
      final left = deadline.difference(DateTime.now());
      try {
        await waiter.future.timeout(left.isNegative ? Duration.zero : left);
      } on TimeoutException {
        throw Socks5Exception(
          Socks5Failure.handshakeTimeout,
          detail: 'SOCKS5 proxy $proxyHost:$proxyPort did not answer',
        );
      }
    }
    final out = pending.sublist(0, n);
    pending.removeRange(0, n);
    return out;
  }

  try {
    final withAuth = username != null && username.isNotEmpty;
    socket.add(withAuth ? [5, 2, 0, 2] : [5, 1, 0]);
    final choice = await need(2);
    if (choice[0] != 5) {
      throw const Socks5Exception(Socks5Failure.protocolError);
    }
    if (choice[1] == 0xff) {
      throw const Socks5Exception(Socks5Failure.noAcceptableAuth);
    }
    if (choice[1] == 2) {
      if (!withAuth) {
        throw const Socks5Exception(Socks5Failure.noAcceptableAuth);
      }
      final u = utf8.encode(username);
      final p = utf8.encode(password ?? '');
      socket.add([1, u.length, ...u, p.length, ...p]);
      final status = await need(2);
      if (status[1] != 0) {
        throw const Socks5Exception(Socks5Failure.authRejected);
      }
    } else if (choice[1] != 0) {
      throw const Socks5Exception(Socks5Failure.protocolError);
    }

    final List<int> address;
    if (literal == null) {
      address = [3, nameBytes.length, ...nameBytes];
    } else {
      address = [
        literal.type == InternetAddressType.IPv6 ? 4 : 1,
        ...literal.rawAddress,
      ];
    }
    socket.add([5, 1, 0, ...address, targetPort >> 8, targetPort & 0xff]);

    final head = await need(4);
    if (head[0] != 5) throw const Socks5Exception(Socks5Failure.protocolError);
    if (head[1] != 0) {
      throw Socks5Exception(
        _replyFailures[head[1]] ?? Socks5Failure.protocolError,
        detail: 'SOCKS5 proxy refused the connection (reply ${head[1]})',
      );
    }
    switch (head[3]) {
      case 1:
        await need(4 + 2);
      case 4:
        await need(16 + 2);
      case 3:
        await need((await need(1))[0] + 2);
      default:
        throw const Socks5Exception(Socks5Failure.protocolError);
    }
    sub.pause();
    // A server can send its first bytes in the same read as the reply; they
    // belong to the tunnel's reader, not the handshake.
    return Socks5Tunnel._(socket, sub, List<int>.unmodifiable(pending));
  } catch (_) {
    socket.destroy();
    rethrow;
  }
}

/// An open SOCKS5 tunnel.
///
/// A Socket is single-subscription and the handshake already used its
/// listener (paused, nothing buffered). For https, hand [socket] to
/// SecureSocket.secure, which detaches the raw socket and needs the real
/// dart:io Socket. For http, use [asPlainSocket].
class Socks5Tunnel {
  Socks5Tunnel._(this.socket, this._subscription, this._earlyData);

  final Socket socket;
  final StreamSubscription<Uint8List> _subscription;
  final List<int> _earlyData;

  /// Whether the target sent bytes before the caller wrote anything. A TLS
  /// server never does (the client speaks first), so https treats it as a
  /// protocol error; http hands the bytes to the reader.
  bool get hasEarlyData => _earlyData.isNotEmpty;

  Socket asPlainSocket() => _TunnelSocket(socket, _subscription, _earlyData);
}

/// A Socket whose reads come from the handshake's paused subscription and
/// whose writes and options go to the real socket.
class _TunnelSocket extends Stream<Uint8List> implements Socket {
  _TunnelSocket(this._inner, this._subscription, this._earlyData);

  final Socket _inner;
  final StreamSubscription<Uint8List> _subscription;
  final List<int> _earlyData;
  var _listened = false;

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    if (_listened) throw StateError('Stream has already been listened to.');
    _listened = true;
    final controller = StreamController<Uint8List>(
      sync: true,
      onPause: _subscription.pause,
      onResume: _subscription.resume,
      onCancel: _subscription.cancel,
    );
    _subscription
      ..onData(controller.add)
      ..onError(controller.addError)
      ..onDone(controller.close);
    final sub = controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    // Not inside listen(): a stream must not deliver before listen returns
    // (Stream.first sets its handler afterwards and would drop the bytes).
    // The early bytes go first, then the socket resumes behind them.
    scheduleMicrotask(() {
      if (_earlyData.isNotEmpty) {
        controller.add(Uint8List.fromList(_earlyData));
      }
      _subscription.resume();
    });
    return sub;
  }

  @override
  Encoding get encoding => _inner.encoding;
  @override
  set encoding(Encoding value) => _inner.encoding = value;
  @override
  void add(List<int> data) => _inner.add(data);
  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);
  @override
  Future<void> addStream(Stream<List<int>> stream) => _inner.addStream(stream);
  @override
  Future<void> close() => _inner.close();
  @override
  Future<void> get done => _inner.done;
  @override
  Future<void> flush() => _inner.flush();
  @override
  void write(Object? object) => _inner.write(object);
  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _inner.writeAll(objects, separator);
  @override
  void writeCharCode(int charCode) => _inner.writeCharCode(charCode);
  @override
  void writeln([Object? object = '']) => _inner.writeln(object);
  @override
  InternetAddress get address => _inner.address;
  @override
  InternetAddress get remoteAddress => _inner.remoteAddress;
  @override
  int get port => _inner.port;
  @override
  int get remotePort => _inner.remotePort;
  @override
  bool setOption(SocketOption option, bool enabled) =>
      _inner.setOption(option, enabled);
  @override
  Uint8List getRawOption(RawSocketOption option) => _inner.getRawOption(option);
  @override
  void setRawOption(RawSocketOption option) => _inner.setRawOption(option);
  @override
  void destroy() => _inner.destroy();
}
