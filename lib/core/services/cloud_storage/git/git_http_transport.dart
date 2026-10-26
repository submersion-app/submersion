import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';
import 'package:submersion/core/services/cloud_storage/git/git_push_refusal.dart';
import 'package:submersion/core/services/cloud_storage/git/git_remote.dart';
import 'package:submersion/core/services/cloud_storage/git/git_pack_spool.dart';
import 'package:submersion/core/services/cloud_storage/git/pkt_line.dart';
import 'package:submersion/core/services/cloud_storage/http_timeouts.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_tls.dart';

/// What `ls-refs` (or the v0 advertisement) said about the repository.
final class GitRefAdvertisement {
  const GitRefAdvertisement({
    required this.protocolVersion,
    required this.headSymref,
    required this.branchTip,
    required this.isEmpty,
    required this.supportsFilter,
    required this.supportsShallow,
  });

  /// 2, or 0 for a host that only speaks the original protocol.
  final int protocolVersion;

  /// The ref HEAD points at (`refs/heads/main`), or null when not reported.
  final String? headSymref;

  /// The requested branch's tip, or null when the branch does not exist.
  final GitObjectId? branchTip;

  /// True when the repository has no branches at all.
  final bool isEmpty;
  final bool supportsFilter;
  final bool supportsShallow;
}

/// Capabilities learned from upload-pack discovery. Stable for a transport's
/// lifetime, so learned once.
final class _UploadPackCaps {
  const _UploadPackCaps({
    required this.version,
    required this.filter,
    required this.shallow,
    required this.unborn,
  });

  final int version;
  final bool filter;
  final bool shallow;
  final bool unborn;
}

/// The smart-HTTP Git protocol, the narrow part Submersion needs: list refs,
/// fetch (shallow, optionally without blobs), fetch single blobs, and push one
/// ref update with a pack. Protocol v2 is used for reads where offered, v0
/// otherwise; pushes are always v0, as in stock Git.
class GitHttpTransport {
  GitHttpTransport(
    this.remote, {
    http.Client? client,
    this.pushDeadline = pushDeadlineFor,
    Directory? spoolDirectory,
  }) : _spoolDirectory = spoolDirectory,
       _recorder = client == null
           ? CertificateTrustRecorder(
               expectedHost: remote.host,
               expectedPort: remote.port,
               pinnedSha256: remote.pinnedCertSha256,
             )
           : null {
    _client = client ?? createWebDavHttpClient(_recorder!);
  }

  final GitRemote remote;

  /// How long a push of a pack of that many bytes may take.
  final Duration Function(int packBytes) pushDeadline;

  /// Where a fetched pack is written as it arrives; unless given,
  /// [defaultGitSpoolDirectory].
  final Directory? _spoolDirectory;
  final CertificateTrustRecorder? _recorder;
  late final http.Client _client;
  _UploadPackCaps? _caps;

  static const String _userAgent = 'git/submersion';
  static const String _agent = 'agent=git/submersion';

  /// Slowest upload rate a push deadline allows for (1 Mbit/s), as for
  /// WebDAV uploads.
  static const int minPushBytesPerSecond = 128 * 1024;

  /// The upload deadline, or longer for a pack too large to send within it
  /// at 1 Mbit/s.
  static Duration pushDeadlineFor(int packBytes) =>
      deadlineAtLeast(TimeoutHttpClient.defaultUploadTimeout, packBytes);

  /// [floor], or the time [bytes] take at [minPushBytesPerSecond] when that
  /// is longer.
  static Duration deadlineAtLeast(Duration floor, int bytes) {
    final scaled = Duration(seconds: bytes ~/ minPushBytesPerSecond);
    return scaled > floor ? scaled : floor;
  }

  void close() => _client.close();

  // ---- HTTP plumbing ------------------------------------------------------

  Uri _endpoint(String suffix, [String? service]) {
    var path = remote.cloneUrl.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return remote.cloneUrl.replace(
      path: '$path/$suffix',
      query: service == null ? null : 'service=$service',
    );
  }

  Map<String, String> _headers({bool auth = true, bool v2 = false}) => {
    HttpHeaders.userAgentHeader: _userAgent,
    if (auth)
      HttpHeaders.authorizationHeader:
          'Basic ${base64.encode(utf8.encode('${remote.username}:${remote.token}'))}',
    if (v2) 'Git-Protocol': 'version=2',
  };

  Future<http.StreamedResponse> _send(
    http.BaseRequest request, {
    Duration timeout = TimeoutHttpClient.defaultResponseTimeout,
  }) async {
    try {
      return await _client.send(request).timeout(timeout);
    } on Object catch (e) {
      final rejected = _recorder?.takeRejected();
      if (rejected != null) {
        throw GitUntrustedCertificateException(rejected, cause: e);
      }
      if (e is SocketException ||
          e is TimeoutException ||
          e is http.ClientException ||
          e is HandshakeException ||
          e is TlsException) {
        throw GitException(
          'Could not reach ${remote.host}.',
          code: GitErrorCode.unreachable,
          host: remote.host,
          cause: e,
        );
      }
      rethrow;
    }
  }

  /// The body as it arrives, with a dropped or stalled connection as a
  /// [GitErrorCode.unreachable] error.
  Stream<List<int>> _bodyStream(http.StreamedResponse response) async* {
    try {
      // Not yield*: that would pass errors on unmapped.
      await for (final chunk in response.stream.timeout(
        TimeoutHttpClient.defaultIdleTimeout,
      )) {
        yield chunk;
      }
    } on Object catch (e) {
      if (e is GitException) rethrow;
      throw GitException(
        'The connection to ${remote.host} dropped.',
        code: GitErrorCode.unreachable,
        host: remote.host,
        cause: e,
      );
    }
  }

  Future<Uint8List> _readBody(http.StreamedResponse response) async {
    final out = BytesBuilder(copy: false);
    await _bodyStream(response).forEach(out.add);
    return out.takeBytes();
  }

  /// Throws for a non-success status or a reply that is not Git's.
  Future<void> _check(
    http.StreamedResponse response,
    String expectedContentType,
  ) async {
    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      final type = response.headers[HttpHeaders.contentTypeHeader] ?? '';
      if (!type.startsWith(expectedContentType)) {
        await response.stream.drain<void>();
        throw GitException(
          'The address is not a Git repository.',
          code: GitErrorCode.notGit,
          statusCode: status,
        );
      }
      return;
    }
    final body = await _readBody(response).catchError((_) => Uint8List(0));
    final excerpt = utf8.decode(
      body.length > 300 ? body.sublist(0, 300) : body,
      allowMalformed: true,
    );
    final retryAfter = response.headers['retry-after'];
    final (code, message) = switch (status) {
      401 => (
        GitErrorCode.unauthorized,
        'The Git host rejected the username or token.',
      ),
      403 when retryAfter != null => (
        GitErrorCode.rateLimited,
        'The Git host is limiting requests.',
      ),
      403 => (GitErrorCode.forbidden, 'The token cannot use this repository.'),
      404 => (GitErrorCode.notFound, 'The repository was not found.'),
      413 => (
        GitErrorCode.tooLarge,
        'The Git host refused a file as too large.',
      ),
      429 => (GitErrorCode.rateLimited, 'The Git host is limiting requests.'),
      >= 500 => (GitErrorCode.server, 'The Git host reported an error.'),
      _ => (GitErrorCode.unexpected, 'The Git host gave an unexpected reply.'),
    };
    throw GitException(
      message,
      code: code,
      statusCode: status,
      serverReason: excerpt.trim().isEmpty ? null : excerpt.trim(),
    );
  }

  /// With [stream], the reply is read as it arrives; the caller cancels it.
  Future<PktLineReader> _post(
    String service,
    List<int> body, {
    bool v2 = false,
    bool stream = false,
  }) async {
    final request = http.Request('POST', _endpoint(service))
      ..headers.addAll(_headers(v2: v2))
      ..headers[HttpHeaders.contentTypeHeader] =
          'application/x-$service-request'
      ..headers[HttpHeaders.acceptHeader] = 'application/x-$service-result'
      ..bodyBytes = body;
    final response = await _send(request);
    await _check(response, 'application/x-$service-result');
    if (stream) return PktLineReader(_bodyStream(response));
    return PktLineReader(Stream.value(await _readBody(response)));
  }

  static GitException _protocol(String what) => GitException(
    'The Git host gave an unexpected reply ($what).',
    code: GitErrorCode.unexpected,
  );

  // ---- Discovery ------------------------------------------------------------

  /// Upload-pack discovery, asking for protocol v2.
  Future<({PktLineReader reader, Pkt? first})> _uploadPackDiscovery({
    required bool auth,
  }) => _discovery('git-upload-pack', auth: auth, v2: true);

  /// GET info/refs for [service]. Returns the reader positioned after the
  /// `# service=` preamble, with the first packet of the advertisement
  /// itself. A v0 reply carries the preamble; a v2 reply (asked for with
  /// [v2]) starts directly at `version 2`.
  Future<({PktLineReader reader, Pkt? first})> _discovery(
    String service, {
    required bool auth,
    bool v2 = false,
  }) async {
    final request = http.Request('GET', _endpoint('info/refs', service))
      ..headers.addAll(_headers(auth: auth, v2: v2));
    final response = await _send(request);
    await _check(response, 'application/x-$service-advertisement');
    final reader = PktLineReader(Stream.value(await _readBody(response)));
    var first = await reader.next();
    if (first is PktData && first.text.startsWith('# service=')) {
      final flush = await reader.next();
      if (flush is! PktFlush) throw _protocol('no flush after service line');
      first = await reader.next();
    }
    return (reader: reader, first: first);
  }

  Future<_UploadPackCaps> _capabilities() async {
    final known = _caps;
    if (known != null) return known;
    final (:reader, :first) = await _uploadPackDiscovery(auth: true);
    if (first is PktData && first.text == 'version 2') {
      var filter = false;
      var shallow = false;
      var unborn = false;
      while (true) {
        final pkt = await reader.next();
        if (pkt == null || pkt is PktFlush) break;
        if (pkt is! PktData) continue;
        final line = pkt.text;
        if (line.startsWith('fetch=')) {
          final features = line.substring(6).split(' ');
          filter = features.contains('filter');
          shallow = features.contains('shallow');
        } else if (line.startsWith('ls-refs=')) {
          unborn = line.substring(8).split(' ').contains('unborn');
        }
      }
      return _caps = _UploadPackCaps(
        version: 2,
        filter: filter,
        shallow: shallow,
        unborn: unborn,
      );
    }
    final caps = _v0Caps(first);
    return _caps = _UploadPackCaps(
      version: 0,
      filter: caps.contains('filter'),
      shallow: caps.contains('shallow'),
      unborn: false,
    );
  }

  static Set<String> _v0Caps(Pkt? firstRefLine) {
    if (firstRefLine is! PktData) return const {};
    final bytes = firstRefLine.bytes;
    final nul = bytes.indexOf(0);
    if (nul < 0) return const {};
    return utf8
        .decode(bytes.sublist(nul + 1), allowMalformed: true)
        .trim()
        .split(' ')
        .toSet();
  }

  /// Lists the repository's branches and HEAD, and reports [branch]'s tip.
  Future<GitRefAdvertisement> lsRefs(String branch) async {
    final caps = await _capabilities();
    final wanted = 'refs/heads/$branch';
    if (caps.version == 0) return _lsRefsV0(wanted, caps);
    final body = BytesBuilder(copy: false)
      ..add(pktText('command=ls-refs'))
      ..add(pktText(_agent))
      ..add(pktDelimBytes)
      ..add(pktText('symrefs'))
      ..add(caps.unborn ? pktText('unborn') : Uint8List(0))
      ..add(pktText('ref-prefix HEAD'))
      ..add(pktText('ref-prefix refs/heads/'))
      ..add(pktFlushBytes);
    final reader = await _post('git-upload-pack', body.takeBytes(), v2: true);
    String? head;
    GitObjectId? tip;
    var anyBranch = false;
    while (true) {
      final pkt = await reader.next();
      if (pkt == null || pkt is PktFlush) break;
      if (pkt is! PktData) continue;
      final parts = pkt.text.split(' ');
      if (parts.length < 2) continue;
      final name = parts[1];
      if (name == 'HEAD') {
        for (final attr in parts.skip(2)) {
          if (attr.startsWith('symref-target:')) {
            head = attr.substring('symref-target:'.length);
          }
        }
      } else if (name.startsWith('refs/heads/')) {
        anyBranch = true;
        if (name == wanted) tip = GitObjectId.fromHex(parts[0]);
      }
    }
    return GitRefAdvertisement(
      protocolVersion: 2,
      headSymref: head,
      branchTip: tip,
      isEmpty: !anyBranch,
      supportsFilter: caps.filter,
      supportsShallow: caps.shallow,
    );
  }

  Future<GitRefAdvertisement> _lsRefsV0(
    String wanted,
    _UploadPackCaps caps,
  ) async {
    final discovery = await _uploadPackDiscovery(auth: true);
    final reader = discovery.reader;
    String? head;
    GitObjectId? tip;
    var anyBranch = false;
    var first = true;
    Pkt? pending = discovery.first;
    while (true) {
      final pkt = pending ?? await reader.next();
      pending = null;
      if (pkt == null || pkt is PktFlush) break;
      if (pkt is! PktData) continue;
      final bytes = pkt.bytes;
      final nul = bytes.indexOf(0);
      final refPart = utf8
          .decode(nul < 0 ? bytes : bytes.sublist(0, nul))
          .trim();
      if (first) {
        for (final cap in _v0Caps(pkt)) {
          if (cap.startsWith('symref=HEAD:')) head = cap.substring(12);
        }
        first = false;
      }
      final space = refPart.indexOf(' ');
      if (space < 0) continue;
      final name = refPart.substring(space + 1);
      if (name.startsWith('refs/heads/')) {
        anyBranch = true;
        if (name == wanted) {
          tip = GitObjectId.fromHex(refPart.substring(0, space));
        }
      }
    }
    return GitRefAdvertisement(
      protocolVersion: 0,
      headSymref: head,
      branchTip: tip,
      isEmpty: !anyBranch,
      supportsFilter: caps.filter,
      supportsShallow: caps.shallow,
    );
  }

  // ---- Fetch ----------------------------------------------------------------

  /// Fetches [wants] (shallow to [depth] where the host supports it, and
  /// without blobs when [blobless] and the host supports filters) into
  /// [into].
  Future<void> fetch(
    List<GitObjectId> wants,
    GitObjectStore into, {
    int depth = 1,
    bool blobless = false,
    Set<GitObjectId> haves = const {},
  }) async {
    final caps = await _capabilities();
    final deepen = depth > 0 && caps.shallow ? depth : null;
    final filter = blobless && caps.filter;
    // Haves go with shallow lines (see [_fetch]), which only a host that
    // supports shallow fetches accepts.
    final shallowHaves = caps.shallow ? haves : const <GitObjectId>{};
    try {
      await _fetch(
        caps,
        wants,
        into,
        deepen: deepen,
        filter: filter,
        haves: shallowHaves,
      );
    } on GitDeltaBaseMissingException {
      // The thin pack deltas against an object behind a have that this
      // device does not hold; without haves the host sends whole objects.
      if (shallowHaves.isEmpty) rethrow;
      await _fetch(caps, wants, into, deepen: deepen, filter: filter);
    }
  }

  /// Fetches individual blobs by id (the on-demand half of a blobless
  /// clone). Throws [GitErrorCode.unexpected] when the host refuses wants it
  /// did not advertise; the caller then refetches the tip with blobs.
  Future<void> fetchBlobs(List<GitObjectId> ids, GitObjectStore into) async {
    final caps = await _capabilities();
    await _fetch(caps, ids, into, deepen: null, filter: false);
  }

  Future<void> _fetch(
    _UploadPackCaps caps,
    List<GitObjectId> wants,
    GitObjectStore into, {
    required int? deepen,
    required bool filter,
    Set<GitObjectId> haves = const {},
  }) async {
    if (wants.isEmpty) return;
    if (caps.version == 2) {
      final body = BytesBuilder(copy: false)
        ..add(pktText('command=fetch'))
        ..add(pktText(_agent))
        ..add(pktDelimBytes)
        ..add(pktText('thin-pack'))
        ..add(pktText('ofs-delta'))
        ..add(pktText('no-progress'));
      if (deepen != null) body.add(pktText('deepen $deepen'));
      if (filter) body.add(pktText('filter blob:none'));
      for (final id in wants) {
        body.add(pktText('want ${id.hex}'));
      }
      // Every commit this client has is shallow (it keeps no history), so
      // each have is also declared shallow. Without that the host would
      // assume the ancestors are here too and send deltas against objects
      // this client never fetched.
      for (final id in haves) {
        body.add(pktText('shallow ${id.hex}'));
      }
      for (final id in haves) {
        body.add(pktText('have ${id.hex}'));
      }
      body
        ..add(pktText('done'))
        ..add(pktFlushBytes);
      final reader = await _post(
        'git-upload-pack',
        body.takeBytes(),
        v2: true,
        stream: true,
      );
      try {
        await _readV2FetchResponse(reader, into);
      } finally {
        await reader.cancel();
      }
      return;
    }
    final body = BytesBuilder(copy: false);
    for (var i = 0; i < wants.length; i++) {
      body.add(
        pktText(
          i == 0
              ? 'want ${wants[i].hex} side-band-64k thin-pack ofs-delta '
                    'no-progress${caps.shallow ? ' shallow' : ''}'
                    '${filter ? ' filter' : ''} $_agent'
              : 'want ${wants[i].hex}',
        ),
      );
    }
    for (final id in haves) {
      body.add(pktText('shallow ${id.hex}'));
    }
    if (deepen != null) body.add(pktText('deepen $deepen'));
    if (filter) body.add(pktText('filter blob:none'));
    body.add(pktFlushBytes);
    for (final id in haves) {
      body.add(pktText('have ${id.hex}'));
    }
    body.add(pktText('done'));
    final reader = await _post(
      'git-upload-pack',
      body.takeBytes(),
      stream: true,
    );
    try {
      if (deepen != null) {
        while (true) {
          final pkt = await reader.next();
          if (pkt == null) throw _protocol('fetch ended before the pack');
          if (pkt is PktFlush) break;
          _throwIfErr(pkt);
        }
      }
      final ack = await reader.next();
      _throwIfErr(ack);
      if (ack is! PktData ||
          !(ack.text.startsWith('NAK') || ack.text.startsWith('ACK'))) {
        throw _protocol('no ACK or NAK');
      }
      await _readSideBandPack(reader, into);
    } finally {
      await reader.cancel();
    }
  }

  static void _throwIfErr(Pkt? pkt) {
    if (pkt is PktData && pkt.text.startsWith('ERR ')) {
      throw GitException(
        'The Git host refused the request.',
        code: GitErrorCode.unexpected,
        serverReason: pkt.text.substring(4),
      );
    }
  }

  Future<void> _readV2FetchResponse(
    PktLineReader reader,
    GitObjectStore into,
  ) async {
    while (true) {
      final header = await reader.next();
      if (header == null) throw _protocol('fetch ended before the pack');
      _throwIfErr(header);
      if (header is! PktData) continue;
      if (header.text == 'packfile') {
        await _readSideBandPack(reader, into);
        return;
      }
      // acknowledgments, shallow-info, wanted-refs, packfile-uris: skip to
      // the end of the section.
      while (true) {
        final pkt = await reader.next();
        if (pkt == null) throw _protocol('fetch ended inside a section');
        if (pkt is PktDelim) break;
        if (pkt is PktFlush) throw _protocol('fetch ended without a pack');
        _throwIfErr(pkt);
      }
    }
  }

  /// Spools the pack to disk as it arrives, so it is never held in memory.
  Future<void> _readSideBandPack(
    PktLineReader reader,
    GitObjectStore into,
  ) async {
    await readSpooledPack(
      demuxSideBand(reader),
      into,
      directory: _spoolDirectory,
    );
  }

  // ---- Push -----------------------------------------------------------------

  /// Updates `refs/heads/[branch]` from [oldTip] (null: create it) to
  /// [newTip], sending [pack] (the objects the host lacks, [packBytes] of
  /// them before compression, which sets the deadline). A push still running
  /// at its deadline is aborted rather than left to land unseen.
  ///
  /// The host applies the update only if the ref still points at [oldTip],
  /// so this is a compare-and-swap; a history reset is just a push whose
  /// [newTip] does not descend from [oldTip]. Throws [GitException] with
  /// [GitErrorCode.staleTip] when the ref moved, [GitErrorCode.protectedBranch]
  /// when a branch rule forbids the update, [GitErrorCode.tooLarge] when a
  /// size limit refused it.
  Future<void> push({
    required String branch,
    required GitObjectId? oldTip,
    required GitObjectId newTip,
    required Stream<List<int>> pack,
    int packBytes = 0,
  }) async {
    final caps = await _receivePackCaps();
    final sideBand = caps.contains('side-band-64k');
    final ref = 'refs/heads/$branch';
    final command = '${(oldTip ?? GitObjectId.zero).hex} ${newTip.hex} $ref';
    final capList = [
      'report-status',
      if (sideBand) 'side-band-64k',
      _agent,
    ].join(' ');
    final abort = Completer<void>();
    final request =
        http.AbortableStreamedRequest(
            'POST',
            _endpoint('git-receive-pack'),
            abortTrigger: abort.future,
          )
          ..headers.addAll(_headers())
          ..headers[HttpHeaders.contentTypeHeader] =
              'application/x-git-receive-pack-request'
          ..headers[HttpHeaders.acceptHeader] =
              'application/x-git-receive-pack-result';
    final sending = _send(request, timeout: pushDeadline(packBytes));
    // The body is written in its own future. When the connection fails
    // before the client reads the body, the sink's close never completes;
    // awaiting it first would hang the push, and the caller's write lock,
    // for good. The response settles either way, so it is awaited first,
    // and a body error is turned into a value rather than left unhandled.
    final body = _writePushBody(request, command, capList, pack);
    final http.StreamedResponse response;
    try {
      response = await sending;
    } on Object {
      // Past its deadline the body would keep streaming, and the push could
      // land after the caller was told it failed.
      if (!abort.isCompleted) abort.complete();
      rethrow;
    }
    final bodyError = await body;
    if (bodyError != null) {
      throw GitException(
        'The push could not be sent.',
        code: GitErrorCode.unexpected,
        cause: bodyError,
      );
    }
    await _check(response, 'application/x-git-receive-pack-result');
    final reply = await _readBody(response);
    var reader = PktLineReader(Stream.value(reply));
    final remoteLines = <String>[];
    if (sideBand) {
      final status = BytesBuilder(copy: false);
      await for (final chunk in demuxSideBand(
        reader,
        onProgress: remoteLines.add,
      )) {
        status.add(chunk);
      }
      reader = PktLineReader(Stream.value(status.takeBytes()));
    }
    await _readReportStatus(reader, ref, remoteLines);
  }

  /// Writes the ref update and [pack] into [request]. Completes with the
  /// error instead of throwing it.
  static Future<Object?> _writePushBody(
    http.StreamedRequest request,
    String command,
    String capList,
    Stream<List<int>> pack,
  ) async {
    try {
      request.sink
        ..add(pktData([...utf8.encode(command), 0, ...utf8.encode(capList)]))
        ..add(pktFlushBytes);
      await request.sink.addStream(pack);
      await request.sink.close();
      return null;
    } on Object catch (e) {
      try {
        await request.sink.close();
      } on Object {
        // Already closed or failed; the original error is what matters.
      }
      return e;
    }
  }

  Future<Set<String>> _receivePackCaps() async =>
      _v0Caps((await _discovery('git-receive-pack', auth: true)).first);

  Future<void> _readReportStatus(
    PktLineReader reader,
    String ref,
    List<String> remoteLines,
  ) async {
    String? unpack;
    String? refResult;
    while (true) {
      final pkt = await reader.next();
      if (pkt == null || pkt is PktFlush) break;
      if (pkt is! PktData) continue;
      final line = pkt.text;
      if (line.startsWith('unpack ')) {
        unpack = line.substring(7);
      } else if (line.startsWith('ok ') || line.startsWith('ng ')) {
        refResult = line;
      }
    }
    if (unpack != null && unpack != 'ok') {
      throw classifyPushRefusal(unpack, remoteLines);
    }
    if (refResult == null) throw _protocol('no status for $ref');
    if (refResult.startsWith('ok ')) return;
    final rest = refResult.substring(3);
    final reason = rest.startsWith('$ref ')
        ? rest.substring(ref.length + 1)
        : rest;
    throw classifyPushRefusal(reason, remoteLines);
  }

  // ---- Access checks --------------------------------------------------------

  /// Succeeds when the credentials may push: receive-pack discovery needs
  /// push permission on every major host.
  Future<void> checkPushAccess() async {
    await _receivePackCaps();
  }

  /// True when anyone can read the repository without signing in; false when
  /// an anonymous request is refused or answered with something that is not
  /// Git. Rethrows the [GitException] of an answer that says neither (rate
  /// limit, server error, unreachable host, or a Git reply too malformed to
  /// read, which was still served without credentials).
  Future<bool> checkPubliclyReadable() async {
    try {
      await _uploadPackDiscovery(auth: false);
      return true;
    } on GitException catch (e) {
      return switch (e.code) {
        GitErrorCode.rateLimited ||
        GitErrorCode.server ||
        GitErrorCode.unreachable ||
        GitErrorCode.untrustedCertificate => throw e,
        // A protocol error carries no status: the reply was a 2xx from Git.
        GitErrorCode.unexpected when e.statusCode == null => throw e,
        _ => false,
      };
    }
  }

  /// [checkPubliclyReadable], with null for an unclear answer.
  Future<bool?> isPubliclyReadable() async {
    try {
      return await checkPubliclyReadable();
    } on GitException {
      return null;
    }
  }
}
