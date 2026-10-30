import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/nearby/nearby_carrier.dart';
import 'package:submersion/core/services/nearby/nearby_frame.dart';
import 'package:submersion/core/services/nearby/nearby_hello.dart';
import 'package:submersion/core/services/nearby/nearby_peer_store.dart';
import 'package:submersion/core/services/nearby/nearby_session.dart';
import 'package:submersion/core/services/nearby/nearby_sync_protocol.dart';

import '../../../support/fake_nearby_sync_engine.dart';
import '../../../support/forwarding_nearby_endpoint.dart';
import '../../../support/in_memory_nearby_carrier.dart';
import '../../../support/memory_nearby_secrets.dart';

NearbyIdentity _id(
  String id, {
  String? epoch = 'epoch-1',
  int schema = 320,
  int floor = 308,
}) => NearbyIdentity(
  deviceId: id,
  deviceName: 'Device $id',
  appVersion: '1.8.4',
  schemaVersion: schema,
  schemaFloor: floor,
  epochId: epoch,
  hasDives: true,
);

/// One device in the room: its fake library, its paired-devices table and
/// its temp directory, all surviving across sessions.
class _Device {
  _Device(this.id, this.engine, this.db, this.temp)
    : peers = NearbyPeerStore(db);

  final String id;
  final FakeNearbySyncEngine engine;
  final AppDatabase db;
  final Directory temp;
  final NearbyPeerStore peers;
  DateTime now = DateTime.utc(2026, 10, 27, 12);
}

void main() {
  final secret = Uint8List.fromList(List.generate(32, (i) => i));
  late InMemoryNearbyHub hub;

  setUp(() => hub = InMemoryNearbyHub());

  Future<_Device> device(
    String id, {
    required String peerId,
    NearbyIdentity? identity,
    Map<String, String> marks = const {},
    Map<String, String>? marksAfterApply,
  }) async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);
    final temp = Directory.systemTemp.createTempSync('nearby_proto_$id');
    addTearDown(() => temp.deleteSync(recursive: true));
    final d = _Device(
      id,
      FakeNearbySyncEngine(
        self: identity ?? _id(id),
        marks: marks,
        marksAfterApply: marksAfterApply,
        tempDir: temp,
      ),
      db,
      temp,
    );
    await d.peers.upsertPaired(
      peerDeviceId: peerId,
      displayName: 'Device $peerId',
      pairedAt: 1,
    );
    return d;
  }

  /// An open, paired channel from [laptop] (initiator) to [phone].
  Future<(NearbyChannel, NearbyChannel)> open(
    _Device laptop,
    _Device phone, {
    NearbyEndpoint Function(NearbyEndpoint)? wrapLaptop,
  }) async {
    final phoneCarrier = hub.carrier(phone.id) ?? hub.join(phone.id);
    final laptopCarrier = hub.carrier(laptop.id) ?? hub.join(laptop.id);
    await phoneCarrier.startAdvertising();
    final incoming = phoneCarrier.incoming.first;
    final connected = await laptopCarrier.connect(phone.id);
    final out = wrapLaptop?.call(connected) ?? connected;
    final into = await incoming;
    final accepted = NearbySession(
      endpoint: into,
      identity: await phone.engine.identity(),
      secrets: MemoryNearbySecrets({laptop.id: secret}),
    ).accept(allowPairing: false);
    final laptopChannel = await NearbySession(
      endpoint: out,
      identity: await laptop.engine.identity(),
      secrets: MemoryNearbySecrets({phone.id: secret}),
    ).openSync();
    final phoneChannel = (await accepted as NearbyIncomingSync).channel;
    return (laptopChannel, phoneChannel);
  }

  NearbySyncProtocol protocol(
    _Device d,
    NearbyChannel channel, {
    int partSize = 262144,
    Duration messageTimeout = const Duration(seconds: 60),
  }) => NearbySyncProtocol(
    channel: channel,
    engine: d.engine,
    peers: d.peers,
    tempDir: () async => d.temp,
    now: () => d.now,
    partSize: partSize,
    messageTimeout: messageTimeout,
  );

  /// One session from [laptop] (initiator) to [phone], both protocols run to
  /// completion. Returns (laptop outcome, phone outcome).
  Future<(NearbySyncOutcome, NearbySyncOutcome)> session(
    _Device laptop,
    _Device phone, {
    int partSize = 262144,
    Duration messageTimeout = const Duration(seconds: 60),
    NearbyEndpoint Function(NearbyEndpoint)? wrapLaptop,
  }) async {
    final (laptopChannel, phoneChannel) = await open(
      laptop,
      phone,
      wrapLaptop: wrapLaptop,
    );
    NearbySyncProtocol run(_Device d, NearbyChannel channel) => protocol(
      d,
      channel,
      partSize: partSize,
      messageTimeout: messageTimeout,
    );

    // Each side hangs up when its run ends, as the link manager does, so a
    // side that gave up never leaves the other waiting.
    Future<NearbySyncOutcome> runThenClose(
      _Device d,
      NearbyChannel channel,
    ) async {
      try {
        return await run(d, channel).run();
      } finally {
        await channel.close();
      }
    }

    final results = await Future.wait([
      runThenClose(laptop, laptopChannel),
      runThenClose(phone, phoneChannel),
    ]);
    return (results[0], results[1]);
  }

  test('a peer behind on one writer receives a trimmed delta; the other '
      'direction sends nothing', () async {
    final laptop = await device(
      'L',
      peerId: 'P',
      marks: {'L': fakeHlc(50, 'L')},
    );
    final phone = await device(
      'P',
      peerId: 'L',
      marks: {'L': fakeHlc(20, 'L')},
      marksAfterApply: {'L': fakeHlc(50, 'L')},
    );
    laptop.engine.delta = fakeTagsPayload([
      ('already', fakeHlc(20, 'L')),
      ('new', fakeHlc(50, 'L')),
    ]);

    final (lOut, pOut) = await session(laptop, phone);

    expect(lOut.error, isNull);
    expect(pOut.error, isNull);
    expect(laptop.engine.exportDeltaCalls, [fakeHlc(20, 'L')]);
    expect(phone.engine.appliedPayloads, hasLength(1));
    expect(phone.engine.appliedPayloads.single.data.tags.map((t) => t['id']), [
      'new',
    ], reason: 'the row the phone already had is trimmed');
    expect(laptop.engine.appliedPayloads, isEmpty);
    expect(laptop.engine.recordedAcks.single, (
      peer: 'P',
      ack: fakeHlc(50, 'L'),
    ));
    expect(phone.engine.recordedApplied.single.high, fakeHlc(50, 'L'));
    expect(pOut.applied, 1);
  });

  test(
    'a caught-up pair exchanges nothing but still records the session',
    () async {
      final marks = {'L': fakeHlc(5, 'L'), 'P': fakeHlc(7, 'P')};
      final laptop = await device('L', peerId: 'P', marks: marks);
      final phone = await device('P', peerId: 'L', marks: marks);
      final (lOut, pOut) = await session(laptop, phone);
      expect(lOut.error, isNull);
      expect(pOut.error, isNull);
      expect(laptop.engine.exportDeltaCalls, isEmpty);
      expect(phone.engine.exportDeltaCalls, isEmpty);
      expect(laptop.engine.recordedAcks, hasLength(1));
      expect(phone.engine.recordedAcks, hasLength(1));
    },
  );

  test('an empty-map peer receives a full copy in parts', () async {
    final content = incompressibleJson(700000);
    final laptop = await device(
      'L',
      peerId: 'P',
      marks: {'L': fakeHlc(5, 'L')},
    );
    laptop.engine.fullContent = content;
    final phone = await device(
      'P',
      peerId: 'L',
      marksAfterApply: {'L': fakeHlc(5, 'L')},
    );
    final (lOut, pOut) = await session(laptop, phone);
    expect(lOut.error, isNull);
    expect(pOut.error, isNull);
    expect(laptop.engine.exportFullCalls, 1);
    expect(phone.engine.appliedFiles.single, content);
    expect(lOut.sent, greaterThan(2 * 262144), reason: 'several parts');
  });

  test('a part slower than the message timeout still arrives, so a full '
      'copy over a slow link completes', () async {
    final content = incompressibleJson(700000);
    final laptop = await device(
      'L',
      peerId: 'P',
      marks: {'L': fakeHlc(5, 'L')},
    );
    laptop.engine.fullContent = content;
    final phone = await device(
      'P',
      peerId: 'L',
      marksAfterApply: {'L': fakeHlc(5, 'L')},
    );
    final (lOut, pOut) = await session(
      laptop,
      phone,
      messageTimeout: const Duration(milliseconds: 150),
      wrapLaptop: (end) => _SlowParts(end, const Duration(milliseconds: 300)),
    );
    expect(pOut.error, isNull);
    expect(lOut.error, isNull);
    expect(phone.engine.appliedFiles.single, content);
  });

  test('a delta over the blob limit goes as a full copy', () async {
    final laptop = await device(
      'L',
      peerId: 'P',
      marks: {'L': fakeHlc(50, 'L')},
    );
    laptop.engine
      ..blobBytes = 1 << 30
      ..fullContent = '{"big":true}';
    final phone = await device(
      'P',
      peerId: 'L',
      marks: {'L': fakeHlc(20, 'L')},
    );
    await session(laptop, phone);
    expect(laptop.engine.exportDeltaCalls, isEmpty);
    expect(phone.engine.appliedFiles.single, '{"big":true}');
  });

  test('a cut mid-copy resumes where it stopped and applies once', () async {
    final content = incompressibleJson(60000);
    Future<(_Device, _Device)> pair() async {
      final laptop = await device(
        'L',
        peerId: 'P',
        marks: {'L': fakeHlc(5, 'L')},
      );
      laptop.engine.fullContent = content;
      final phone = await device(
        'P',
        peerId: 'L',
        marksAfterApply: {'L': fakeHlc(5, 'L')},
      );
      return (laptop, phone);
    }

    // Measure a clean session on its own pair.
    final (cleanL, cleanP) = await pair();
    await session(cleanL, cleanP, partSize: 4096);
    final total = hub.bytesCrossed('L');

    hub = InMemoryNearbyHub();
    final (laptop, phone) = await pair();
    hub.cutAfterBytes('L', total ~/ 2);
    final (cutL, cutP) = await session(laptop, phone, partSize: 4096);
    expect(cutL.error, NearbyPeerError.unreachable);
    expect(cutP.error, NearbyPeerError.unreachable);
    expect(phone.engine.appliedFiles, isEmpty);
    final resumeAt = (await phone.peers.get('L'))!.resumePartIndex;
    expect(resumeAt, greaterThan(0));

    hub.heal('L');
    final before = hub.bytesCrossed('L');
    final (lOut, pOut) = await session(laptop, phone, partSize: 4096);
    expect(lOut.error, isNull);
    expect(pOut.error, isNull);
    expect(phone.engine.appliedFiles.single, content);
    expect(laptop.engine.exportFullCalls, 1, reason: 'the same copy reused');
    expect(
      hub.bytesCrossed('L') - before,
      lessThan(total - total ~/ 4),
      reason: 'only the rest of the parts crossed',
    );
    expect((await phone.peers.get('L'))!.resumeBaseId, isNull);
  });

  test('an offer older than 24 h starts over from part 0', () async {
    final content = incompressibleJson(60000);
    final laptop = await device(
      'L',
      peerId: 'P',
      marks: {'L': fakeHlc(5, 'L')},
    );
    laptop.engine.fullContent = content;
    final phone = await device(
      'P',
      peerId: 'L',
      marksAfterApply: {'L': fakeHlc(5, 'L')},
    );
    hub.cutAfterBytes('L', 30000);
    await session(laptop, phone, partSize: 4096);
    expect((await phone.peers.get('L'))!.resumePartIndex, isNotNull);

    hub.heal('L');
    phone.now = phone.now.add(const Duration(hours: 25));
    laptop.now = laptop.now.add(const Duration(hours: 25));
    final (lOut, pOut) = await session(laptop, phone, partSize: 4096);
    expect(pOut.error, isNull);
    expect(lOut.error, isNull);
    expect(laptop.engine.exportFullCalls, 2, reason: 'the old copy expired');
    expect(phone.engine.appliedFiles.single, content);
  });

  test(
    'a receiver below the sender floor refuses that direction only',
    () async {
      final laptop = await device(
        'L',
        peerId: 'P',
        identity: _id('L', schema: 330, floor: 325),
        marks: {'L': fakeHlc(50, 'L')},
      );
      laptop.engine.delta = fakeTagsPayload([('x', fakeHlc(50, 'L'))]);
      final phone = await device(
        'P',
        peerId: 'L',
        identity: _id('P', schema: 320),
        marks: {'L': fakeHlc(20, 'L'), 'P': fakeHlc(40, 'P')},
      );
      phone.engine.delta = fakeTagsPayload([('y', fakeHlc(40, 'P'))]);
      laptop.engine.marks = {'L': fakeHlc(50, 'L'), 'P': fakeHlc(10, 'P')};

      final (lOut, pOut) = await session(laptop, phone);
      expect(pOut.error, NearbyPeerError.newerApp);
      expect(lOut.error, NearbyPeerError.peerOlderApp);
      expect(phone.engine.appliedPayloads, isEmpty);
      // The newer laptop still takes the older phone's rows.
      expect(laptop.engine.appliedPayloads, hasLength(1));
    },
  );

  test('a null epoch adopts the peer epoch', () async {
    final laptop = await device('L', peerId: 'P', identity: _id('L'));
    final phone = await device(
      'P',
      peerId: 'L',
      identity: _id('P', epoch: null),
    );
    await session(laptop, phone);
    expect(phone.engine.adoptedEpochs, ['epoch-1']);
    expect(laptop.engine.adoptedEpochs, isEmpty);
  });

  test('two null epochs mint one shared epoch', () async {
    final laptop = await device(
      'L',
      peerId: 'P',
      identity: _id('L', epoch: null),
    );
    final phone = await device(
      'P',
      peerId: 'L',
      identity: _id('P', epoch: null),
    );
    await session(laptop, phone);
    expect(laptop.engine.adoptedEpochs, hasLength(1));
    expect(phone.engine.adoptedEpochs, laptop.engine.adoptedEpochs);
  });

  test('applied reports the lowest clock to relay from', () async {
    final laptop = await device(
      'L',
      peerId: 'P',
      marks: {'L': fakeHlc(50, 'L'), 'Z': fakeHlc(9, 'Z')},
    );
    laptop.engine.delta = fakeTagsPayload([('n', fakeHlc(50, 'L'))]);
    final phone = await device(
      'P',
      peerId: 'L',
      marks: {'L': fakeHlc(30, 'L'), 'Z': fakeHlc(9, 'Z')},
      marksAfterApply: {'L': fakeHlc(50, 'L'), 'Z': fakeHlc(9, 'Z')},
    );
    await session(laptop, phone);
    // Z did not move; L moved from 30, so the cloud must relay from there.
    expect(phone.engine.recordedApplied.single.low, fakeHlc(30, 'L'));
  });

  test('a writer new to the receiver relays from the very beginning', () async {
    final laptop = await device(
      'L',
      peerId: 'P',
      marks: {'L': fakeHlc(50, 'L')},
    );
    laptop.engine.fullContent = '{}';
    final phone = await device(
      'P',
      peerId: 'L',
      marksAfterApply: {'L': fakeHlc(50, 'L')},
    );
    await session(laptop, phone);
    expect(phone.engine.recordedApplied.single.low, '000000000000000:000000:');
  });

  test(
    'a writer new to the receiver relays from its oldest clock there',
    () async {
      final laptop = await device(
        'L',
        peerId: 'P',
        marks: {'L': fakeHlc(50, 'L')},
      );
      laptop.engine.fullContent = '{}';
      final phone = await device(
        'P',
        peerId: 'L',
        marksAfterApply: {'L': fakeHlc(50, 'L')},
      );
      phone.engine.lowestByWriter = {'L': fakeHlc(7, 'L')};
      await session(laptop, phone);
      expect(phone.engine.recordedApplied.single.low, fakeHlc(7, 'L'));
    },
  );

  test(
    'the receiver waits while a large first copy is being prepared',
    () async {
      final laptop = await device(
        'L',
        peerId: 'P',
        marks: {'L': fakeHlc(5, 'L')},
      );
      laptop.engine
        ..fullContent = '{"slow":true}'
        ..exportDelay = const Duration(milliseconds: 400);
      final phone = await device(
        'P',
        peerId: 'L',
        marksAfterApply: {'L': fakeHlc(5, 'L')},
      );
      final (lOut, pOut) = await session(
        laptop,
        phone,
        messageTimeout: const Duration(milliseconds: 150),
      );
      expect(pOut.error, isNull);
      expect(lOut.error, isNull);
      expect(phone.engine.appliedFiles.single, '{"slow":true}');
    },
  );

  test('an offer of a kind this build does not know is refused before any '
      'part is fetched, never applied as a full copy', () async {
    final laptop = await device('L', peerId: 'P');
    final phone = await device('P', peerId: 'L');
    final (laptopChannel, phoneChannel) = await open(laptop, phone);
    final phoneRun = protocol(phone, phoneChannel).run();
    final inbox = StreamIterator(laptopChannel.messages);
    expect(await inbox.moveNext(), isTrue);
    expect(inbox.current.type, NearbyMessageType.watermarks);
    await laptopChannel.send(
      NearbyMessageType.baseOffer,
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'id': 'x1',
            'kind': 'mystery',
            'parts': 1,
            'bytes': 3,
            'partSize': 3,
          }),
        ),
      ),
    );
    expect(await inbox.moveNext(), isTrue);
    expect(inbox.current.type, NearbyMessageType.error);
    await laptopChannel.close();
    expect((await phoneRun).error, NearbyPeerError.unreachable);
    expect(phone.engine.appliedFiles, isEmpty);
  });

  test('a delta whose link drops before it is applied leaves no file '
      'behind (only a full copy is kept for a resume)', () async {
    final laptop = await device(
      'L',
      peerId: 'P',
      marks: {'L': fakeHlc(50, 'L')},
    );
    laptop.engine.delta = fakeTagsPayload([('new', fakeHlc(50, 'L'))]);
    final phone = await device('P', peerId: 'L');
    final (laptopChannel, phoneChannel) = await open(laptop, phone);
    final laptopRun = protocol(laptop, laptopChannel).run();
    final inbox = StreamIterator(phoneChannel.messages);
    await phoneChannel.send(
      NearbyMessageType.watermarks,
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'high': {'L': fakeHlc(20, 'L')},
            'epoch': 'epoch-1',
          }),
        ),
      ),
    );
    expect(await inbox.moveNext(), isTrue);
    expect(inbox.current.type, NearbyMessageType.baseOffer);
    await phoneChannel.close(); // the link drops before any part

    expect((await laptopRun).error, NearbyPeerError.unreachable);
    final left = laptop.temp
        .listSync()
        .map((f) => p.basename(f.path))
        .where((n) => n.startsWith('nearby-delta-'));
    expect(left, isEmpty);
  });

  test('partial copies of an older offer are swept', () async {
    final laptop = await device(
      'L',
      peerId: 'P',
      marks: {'L': fakeHlc(5, 'L')},
    );
    laptop.engine.fullContent = '{}';
    final phone = await device(
      'P',
      peerId: 'L',
      marksAfterApply: {'L': fakeHlc(5, 'L')},
    );
    final stale = File(p.join(phone.temp.path, 'nearby-in-L-old-offer.gz'))
      ..writeAsBytesSync([1, 2, 3]);
    final ancient = File(p.join(phone.temp.path, 'nearby-out-X-dead.gz'))
      ..writeAsBytesSync([1]);
    // Aged against the session's clock, not the wall clock: the sweep's
    // cutoff comes from phone.now, fixed at 2026-10-27, so a wall-clock age
    // stopped reaching past it once the real date passed 2026-10-29.
    ancient.setLastModifiedSync(phone.now.subtract(const Duration(days: 3)));
    await session(laptop, phone);
    expect(stale.existsSync(), isFalse);
    expect(ancient.existsSync(), isFalse);
  });

  test('a full copy the peer could not use is not offered again', () async {
    final laptop = await device(
      'L',
      peerId: 'P',
      marks: {'L': fakeHlc(5, 'L')},
    );
    laptop.engine.fullContent = '{}';
    final phone = await device('P', peerId: 'L');
    phone.engine.applyError = StateError('database is locked');
    final (_, failed) = await session(laptop, phone);
    expect(failed.error, NearbyPeerError.applyFailed);

    phone.engine.applyError = null;
    final (_, retried) = await session(laptop, phone);
    expect(retried.error, isNull);
    expect(laptop.engine.exportFullCalls, 2, reason: 'a fresh copy');
  });

  test('a copy that would not apply leaves nothing of it behind', () async {
    final laptop = await device(
      'L',
      peerId: 'P',
      marks: {'L': fakeHlc(5, 'L')},
    );
    laptop.engine.fullContent = '{}';
    final phone = await device('P', peerId: 'L');
    phone.engine.applyError = StateError('database is locked');
    final (_, failed) = await session(laptop, phone);
    expect(failed.error, NearbyPeerError.applyFailed);
    expect((await phone.peers.get('L'))!.resumeBaseId, isNull);
    final left = phone.temp
        .listSync()
        .map((f) => p.basename(f.path))
        .where((n) => n.startsWith('nearby-in-'));
    expect(left, isEmpty, reason: 'the sender makes a fresh copy');
  });

  test('rows the merge could not apply fail the direction, and what did '
      'apply is still acknowledged', () async {
    final laptop = await device(
      'L',
      peerId: 'P',
      marks: {'L': fakeHlc(5, 'L')},
    );
    laptop.engine.fullContent = '{}';
    final phone = await device('P', peerId: 'L');
    phone.engine.recordsFailed = 2;
    final (_, outcome) = await session(laptop, phone);
    expect(outcome.error, NearbyPeerError.applyFailed);
    expect(phone.engine.appliedFiles, hasLength(1));
    expect(phone.engine.recordedApplied, hasLength(1), reason: 'acknowledged');
  });

  test('a copy that will not unpack fails its direction only, and nothing '
      'of it is kept for a resume', () async {
    final laptop = await device('L', peerId: 'P');
    final phone = await device('P', peerId: 'L');
    final (laptopChannel, phoneChannel) = await open(laptop, phone);
    final phoneRun = protocol(phone, phoneChannel).run();
    final inbox = StreamIterator(laptopChannel.messages);
    Future<NearbyMessageType> next() async {
      expect(
        await inbox.moveNext().timeout(const Duration(seconds: 5)),
        isTrue,
      );
      return inbox.current.type;
    }

    Uint8List json(Map<String, Object?> body) =>
        Uint8List.fromList(utf8.encode(jsonEncode(body)));
    expect(await next(), NearbyMessageType.watermarks);
    await laptopChannel.send(
      NearbyMessageType.baseOffer,
      json({
        'id': 'bad1',
        'kind': 'full',
        'parts': 1,
        'bytes': 3,
        'partSize': 3,
        'epoch': 'epoch-1',
      }),
    );
    expect(await next(), NearbyMessageType.baseRequest);
    final part = Uint8List(7);
    ByteData.sublistView(part).setUint32(0, 0);
    part.setRange(4, 7, const [1, 2, 3]); // not gzip
    await laptopChannel.send(NearbyMessageType.basePart, part);
    expect(await next(), NearbyMessageType.error);

    // The other direction still runs: the phone answers the laptop's marks.
    await laptopChannel.send(
      NearbyMessageType.watermarks,
      json({'high': <String, String>{}, 'epoch': 'epoch-1'}),
    );
    expect(await next(), NearbyMessageType.baseOffer);
    await laptopChannel.close();

    expect((await phoneRun).error, NearbyPeerError.applyFailed);
    expect(phone.engine.appliedFiles, isEmpty);
    expect((await phone.peers.get('L'))!.resumeBaseId, isNull);
    final left = phone.temp
        .listSync()
        .map((f) => p.basename(f.path))
        .where((n) => n.startsWith('nearby-in-'));
    expect(left, isEmpty);
  });
}

/// Delivers every base part [delay] late, as a slow radio link would. The
/// frame type is the fifth byte, in the clear.
class _SlowParts extends ForwardingNearbyEndpoint {
  _SlowParts(super.inner, this.delay);

  final Duration delay;

  @override
  Future<void> send(Uint8List bytes) async {
    if (bytes.length > 4 && bytes[4] == NearbyMessageType.basePart.code) {
      await Future<void>.delayed(delay);
    }
    await super.send(bytes);
  }
}
