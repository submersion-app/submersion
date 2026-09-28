import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_ndef.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_manager_tag_service.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';

import '../../../../helpers/fake_nfc.dart';

/// Records how the service drives the plugin, and lets a test deliver tags
/// and iOS session errors.
class _FakeNfcManager implements NfcManager {
  Set<NfcPollingOption>? pollingOptions;
  bool? invalidateAfterFirstReadIos;
  void Function(NfcTag tag)? onDiscovered;
  void Function(NfcReaderSessionErrorIos error)? onSessionErrorIos;
  int stops = 0;
  String? stopAlert;
  String? stopError;
  Object? stopThrows;
  NfcAvailability availability = NfcAvailability.enabled;
  Object? availabilityThrows;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<NfcAvailability> checkAvailability() async {
    if (availabilityThrows case final error?) throw error;
    return availability;
  }

  @override
  Future<void> startSession({
    required Set<NfcPollingOption> pollingOptions,
    required void Function(NfcTag tag) onDiscovered,
    String? alertMessageIos,
    bool invalidateAfterFirstReadIos = true,
    void Function(NfcReaderSessionErrorIos)? onSessionErrorIos,
    bool noPlatformSoundsAndroid = false,
  }) async {
    this.pollingOptions = pollingOptions;
    this.invalidateAfterFirstReadIos = invalidateAfterFirstReadIos;
    this.onDiscovered = onDiscovered;
    this.onSessionErrorIos = onSessionErrorIos;
  }

  @override
  Future<void> stopSession({
    String? alertMessageIos,
    String? errorMessageIos,
  }) async {
    stops++;
    stopAlert = alertMessageIos;
    stopError = errorMessageIos;
    if (stopThrows case final error?) throw error;
  }
}

/// The plugin's public NDEF view of a tag, as the adapter reads it.
class _FakeNdef implements Ndef {
  _FakeNdef({this.cachedMessage});

  @override
  final NdefMessage? cachedMessage;

  @override
  bool get isWritable => true;

  @override
  int get maxSize => 137;

  @override
  Map<String, dynamic> get additionalData => {
    'type': 'org.nfcforum.ndef.type2',
  };

  @override
  Future<NdefMessage?> read() async => cachedMessage;

  @override
  Future<void> write({required NdefMessage message}) async {}

  @override
  Future<void> writeLock() async {}
}

void main() {
  const tag = NfcTag(data: 'tag');
  late _FakeNfcManager manager;
  late NfcManagerTagService service;

  setUp(() {
    manager = _FakeNfcManager();
    service = NfcManagerTagService(
      manager: manager,
      handleFor: (_) => FakeTagHandle(),
    );
  });

  /// Lets the session start, so the fake has its callbacks.
  Future<void> started() => Future<void>.delayed(Duration.zero);

  test('keeps the tag connected on iOS while it is written', () async {
    // nfc_manager restarts polling after each tag when this is false, which
    // invalidates the tag before Dart can write to it.
    final session = service.withTag<int>(
      promptIos: 'Hold near',
      onTag: (_) async => 1,
    );
    await started();
    expect(manager.invalidateAfterFirstReadIos, isTrue);
    expect(manager.pollingOptions, {NfcPollingOption.iso14443});
    manager.onDiscovered!(tag);
    expect(await session, 1);
    expect(manager.stops, 1);
  });

  test('the session is active from its start until it has stopped', () async {
    expect(service.sessionActive, isFalse);
    final session = service.withTag<int>(
      promptIos: 'Hold near',
      onTag: (_) async => 1,
    );
    await started();
    expect(service.sessionActive, isTrue);
    manager.onDiscovered!(tag);
    await session;
    expect(manager.stops, 1);
    expect(service.sessionActive, isFalse);
  });

  test('a second tag while the first is handled is ignored', () async {
    final gate = Completer<void>();
    var calls = 0;
    final session = service.withTag<int>(
      promptIos: 'Hold near',
      onTag: (_) async {
        calls++;
        await gate.future;
        return calls;
      },
    );
    await started();
    manager.onDiscovered!(tag);
    manager.onDiscovered!(tag);
    gate.complete();
    expect(await session, 1);
    expect(calls, 1);
  });

  test('the iOS sheet closes as a failure when the result is one', () async {
    final session = service.withTag<bool>(
      promptIos: 'Hold near',
      onTag: (_) async => false,
      iosEnd: (ok) => ok
          ? const IosSheetEnd.success('Written')
          : const IosSheetEnd.failure('Not written'),
    );
    await started();
    manager.onDiscovered!(tag);
    expect(await session, isFalse);
    expect(manager.stopError, 'Not written');
    expect(manager.stopAlert, isNull);
  });

  test('the iOS sheet closes as a success when the result is one', () async {
    final session = service.withTag<bool>(
      promptIos: 'Hold near',
      onTag: (_) async => true,
      iosEnd: (ok) => ok
          ? const IosSheetEnd.success('Written')
          : const IosSheetEnd.failure('Not written'),
    );
    await started();
    manager.onDiscovered!(tag);
    expect(await session, isTrue);
    expect(manager.stopAlert, 'Written');
    expect(manager.stopError, isNull);
  });

  test('a throwing tag handler closes as a failure and rethrows', () async {
    final session = service.withTag<int>(
      promptIos: 'Hold near',
      onTag: (_) async => throw StateError('lost'),
      iosFailure: 'Could not read',
    );
    await started();
    manager.onDiscovered!(tag);
    await expectLater(session, throwsA(isA<StateError>()));
    expect(manager.stopError, 'Could not read');
  });

  test('cancel while waiting ends the session as cancelled', () async {
    final session = service.withTag<int>(
      promptIos: 'Hold near',
      onTag: (_) async => 1,
    );
    await started();
    await service.cancel();
    await expectLater(session, throwsA(isA<NfcSessionCancelled>()));
    expect(manager.stops, 1);
  });

  test('the diver dismissing the iOS sheet ends quietly', () async {
    final session = service.withTag<int>(
      promptIos: 'Hold near',
      onTag: (_) async => 1,
      iosFailure: 'Could not read',
    );
    await started();
    manager.onSessionErrorIos!(
      const NfcReaderSessionErrorIos(
        code: NfcReaderErrorCodeIos.readerSessionInvalidationErrorUserCanceled,
        message: 'Session invalidated by user',
      ),
    );
    await expectLater(session, throwsA(isA<NfcSessionCancelled>()));
    expect(manager.stopError, isNull);
  });

  test(
    'a session the system already closed does not hide the result',
    () async {
      manager.stopThrows = StateError('no session');
      final session = service.withTag<int>(
        promptIos: 'Hold near',
        onTag: (_) async => 7,
      );
      await started();
      manager.onDiscovered!(tag);
      expect(await session, 7);
    },
  );

  group('support', () {
    for (final (availability, expected) in [
      (NfcAvailability.enabled, NfcSupport.enabled),
      (NfcAvailability.disabled, NfcSupport.disabled),
      (NfcAvailability.unsupported, NfcSupport.unsupported),
    ]) {
      test('$availability is $expected', () async {
        manager.availability = availability;
        expect(await service.support(), expected);
      });
    }

    test('a failed availability check is unsupported', () async {
      manager.availabilityThrows = StateError('no NFC');
      expect(await service.support(), NfcSupport.unsupported);
    });
  });

  test('an iOS session that ends on its own fails, not cancels', () async {
    final session = service.withTag<int>(
      promptIos: 'Hold near',
      onTag: (_) async => 1,
    );
    await started();
    manager.onSessionErrorIos!(
      const NfcReaderSessionErrorIos(
        code:
            NfcReaderErrorCodeIos.readerSessionInvalidationErrorSessionTimeout,
        message: 'Session timeout',
      ),
    );
    await expectLater(session, throwsA(isA<NfcSessionFailed>()));
  });

  test('cancel while a tag is being written lets the write finish', () async {
    final gate = Completer<void>();
    final session = service.withTag<int>(
      promptIos: 'Hold near',
      onTag: (_) async {
        await gate.future;
        return 5;
      },
    );
    await started();
    manager.onDiscovered!(tag);
    await service.cancel();
    await started();
    // Stopping now would cut the write off half way.
    expect(manager.stops, 0);
    gate.complete();
    expect(await session, 5);
    expect(manager.stops, 1);
  });

  group('a cancel left over from the previous iOS session', () {
    var now = DateTime(2026, 9, 28, 10);
    const userCanceled = NfcReaderSessionErrorIos(
      code: NfcReaderErrorCodeIos.readerSessionInvalidationErrorUserCanceled,
      message: 'Session invalidated by user',
    );

    setUp(() {
      now = DateTime(2026, 9, 28, 10);
      service = NfcManagerTagService(
        manager: manager,
        handleFor: (_) => FakeTagHandle(),
        clock: () => now,
      );
    });

    Future<void> finishOneSession() async {
      final first = service.withTag<int>(
        promptIos: 'Hold near',
        onTag: (_) async => 1,
      );
      await started();
      manager.onDiscovered!(tag);
      await first;
    }

    test('does not end a Retry started right after it', () async {
      // nfc_manager hands the old session's late invalidation to whichever
      // callback is registered, and Retry has just registered a new one.
      await finishOneSession();
      now = now.add(const Duration(seconds: 1));
      var done = false;
      final retry = service.withTag<int>(
        promptIos: 'Hold near',
        onTag: (_) async => 2,
      )..whenComplete(() => done = true).ignore();
      await started();
      manager.onSessionErrorIos!(userCanceled);
      await started();
      expect(done, isFalse);
      manager.onDiscovered!(tag);
      expect(await retry, 2);
    });

    test(
      'once the old session is long gone, a cancel is the diver\'s',
      () async {
        await finishOneSession();
        now = now.add(const Duration(seconds: 10));
        final next = service.withTag<int>(
          promptIos: 'Hold near',
          onTag: (_) async => 2,
        );
        await started();
        manager.onSessionErrorIos!(userCanceled);
        await expectLater(next, throwsA(isA<NfcSessionCancelled>()));
      },
    );
  });

  group('handleOf', () {
    const url =
        'https://submersion.app/c#f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

    test('a tag that cannot hold NDEF reaches the handler as none', () {
      // iOS hands out an Ndef for such a tag, not writable, which would
      // otherwise read as a locked tag.
      expect(
        NfcManagerTagService.handleOf(_FakeNdef(), iosNdefUnsupported: true),
        isNull,
      );
      expect(NfcManagerTagService.handleOf(null), isNull);
    });

    test('an NDEF tag reports what it held when it was found', () {
      final message = NdefMessage(records: [uriRecord(url)]);
      final handle = NfcManagerTagService.handleOf(
        _FakeNdef(cachedMessage: message),
      )!;
      expect(handle.isWritable, isTrue);
      expect(handle.maxMessageBytes, 137);
      expect(handle.typeLabel, 'org.nfcforum.ndef.type2');
      expect(firstPassportUri(handle.discoveredMessage!), url);
    });
  });
}
