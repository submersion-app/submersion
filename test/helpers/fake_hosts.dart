import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'blocked_network.dart';

/// Hosts a test answers from memory instead of the network.
///
/// The harness refuses every request that leaves the machine
/// (test/helpers/blocked_network.dart). A test that runs code which calls a
/// public service declares that host here, and the harness's HttpClient
/// answers it with a canned [FakeResponse]: a 503 "offline" by default, which
/// is what the code would meet without a network, or whatever the test gives.
/// The answer comes from memory, so it arrives inside a widget test's fake
/// clock too, and nothing is left pending when the test ends.
///
/// Declarations last for one test: `test/flutter_test_config.dart` calls
/// [resetFakeHosts] before every test.

/// A canned answer from a fake host.
class FakeResponse {
  const FakeResponse(
    this.statusCode, {
    this.body = '',
    this.contentType = 'text/plain; charset=utf-8',
  });

  /// [data] encoded as JSON, with a JSON content type.
  FakeResponse.json(Object? data, {this.statusCode = 200})
    : body = jsonEncode(data),
      contentType = 'application/json; charset=utf-8';

  /// What a service answers when it is unavailable.
  static const offline = FakeResponse(503, body: 'Offline: a fake host.');

  final int statusCode;
  final String body;
  final String contentType;
}

/// A request a fake host answered.
typedef FakeHostRequest = ({String method, Uri url, String body});

var _hosts = const <String, FakeResponse Function(FakeHostRequest)>{};
var _requests = const <FakeHostRequest>[];

/// Answers every request to [host] with [response] for the rest of the test.
void serveFakeHost(
  String host, [
  FakeResponse response = FakeResponse.offline,
]) => serveFakeHostWith(host, (_) => response);

/// Answers every request to [host] with what [respond] returns for it.
void serveFakeHostWith(
  String host,
  FakeResponse Function(FakeHostRequest request) respond,
) {
  _hosts = {..._hosts, host.toLowerCase(): respond};
}

/// The requests fake hosts have answered in this test, oldest first.
List<FakeHostRequest> get fakeHostRequests => _requests;

/// Forgets every declared fake host and the requests they answered.
void resetFakeHosts() {
  _hosts = const {};
  _requests = const [];
}

/// Whether [host] is declared as a fake host in this test.
bool isFakeHost(String host) => _hosts.containsKey(host.toLowerCase());

/// A request to a fake host, answered from memory when it is closed.
class FakeHostClientRequest implements HttpClientRequest {
  FakeHostClientRequest(this.method, this.uri);

  @override
  final String method;

  @override
  final Uri uri;

  @override
  final HttpHeaders headers = _FakeHeaders();

  @override
  bool persistentConnection = true;

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = -1;

  @override
  bool bufferOutput = true;

  @override
  Encoding encoding = utf8;

  final _body = BytesBuilder(copy: false);
  final _done = Completer<HttpClientResponse>();

  @override
  Future<HttpClientResponse> get done => _done.future;

  @override
  void add(List<int> data) => _body.add(data);

  @override
  void write(Object? object) => _body.add(encoding.encode('$object'));

  @override
  void writeln([Object? object = '']) => write('$object\n');

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      write(objects.join(separator));

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));

  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.forEach(add);

  @override
  Future<void> flush() async {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    if (!_done.isCompleted) _done.completeError(error, stackTrace);
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) =>
      addError(exception ?? const HttpException('aborted'), stackTrace);

  @override
  Future<HttpClientResponse> close() {
    if (!_done.isCompleted) {
      final respond = _hosts[uri.host.toLowerCase()];
      if (respond == null) {
        // The host stopped being a fake after the request opened: the
        // registry was reset for the next test, so this is leftover network
        // use, refused like any other.
        _done.completeError(refuseNetwork('$uri'));
        return _done.future;
      }
      final request = (
        method: method,
        url: uri,
        body: utf8.decode(_body.takeBytes(), allowMalformed: true),
      );
      _requests = [..._requests, request];
      try {
        _done.complete(_FakeHostResponse(respond(request)));
      } catch (error, stackTrace) {
        _done.completeError(error, stackTrace);
      }
    }
    return _done.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'A fake host request does not support ${invocation.memberName}.',
  );
}

class _FakeHostResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHostResponse(FakeResponse answer)
    : statusCode = answer.statusCode,
      _bytes = utf8.encode(answer.body) {
    headers.set(HttpHeaders.contentTypeHeader, answer.contentType);
    headers.set(HttpHeaders.contentLengthHeader, '${_bytes.length}');
  }

  final List<int> _bytes;

  @override
  final int statusCode;

  @override
  final HttpHeaders headers = _FakeHeaders();

  @override
  String get reasonPhrase => statusCode == 200 ? 'OK' : 'Fake $statusCode';

  @override
  int get contentLength => _bytes.length;

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  List<Cookie> get cookies => const [];

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(_bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'A fake host response does not support ${invocation.memberName}.',
  );
}

class _FakeHeaders implements HttpHeaders {
  var _values = const <String, List<String>>{};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values = {
      ..._values,
      name.toLowerCase(): ['$value'],
    };
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    final key = name.toLowerCase();
    _values = {
      ..._values,
      key: [...?_values[key], '$value'],
    };
  }

  @override
  void remove(String name, Object value) {
    final key = name.toLowerCase();
    _values = {
      ..._values,
      key: [...?_values[key]]..remove('$value'),
    };
  }

  @override
  void removeAll(String name) {
    _values = {..._values}..remove(name.toLowerCase());
  }

  @override
  List<String>? operator [](String name) => _values[name.toLowerCase()];

  @override
  String? value(String name) => _values[name.toLowerCase()]?.join(', ');

  @override
  void forEach(void Function(String name, List<String> values) action) =>
      _values.forEach(action);

  @override
  ContentType? get contentType {
    final raw = value(HttpHeaders.contentTypeHeader);
    return raw == null ? null : ContentType.parse(raw);
  }

  @override
  set contentType(ContentType? type) {
    if (type != null) set(HttpHeaders.contentTypeHeader, '$type');
  }

  @override
  int get contentLength =>
      int.tryParse(value(HttpHeaders.contentLengthHeader) ?? '') ?? -1;

  @override
  set contentLength(int length) =>
      set(HttpHeaders.contentLengthHeader, '$length');

  /// A setter the fake does not model is accepted and ignored; anything else
  /// fails loudly rather than handing back a null the caller cannot use.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isSetter) return null;
    throw UnsupportedError(
      'Fake host headers do not support ${invocation.memberName}.',
    );
  }
}
