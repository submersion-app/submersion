import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
// The plugin's own tag data, so a test can hand the service an iOS tag.
// ignore: implementation_imports
import 'package:nfc_manager/src/nfc_manager_ios/pigeon.g.dart';
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

  group('iOS tags', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      service = NfcManagerTagService(manager: manager);
    });

    NfcTag iosTag(NdefStatusPigeon status, {NdefMessagePigeon? cached}) =>
        NfcTag(
          data: TagPigeon(
            handle: 'h',
            ndef: NdefPigeon(
              status: status,
              capacity: status == NdefStatusPigeon.notSupported ? 0 : 137,
              cachedNdefMessage: cached,
            ),
          ),
        );

    Future<NdefTagHandle?> handleOf(NfcTag nfcTag) async {
      final session = service.withTag<NdefTagHandle?>(
        promptIos: 'Hold near',
        onTag: (handle) async => handle,
      );
      await started();
      manager.onDiscovered!(nfcTag);
      return session;
    }

    test('a tag that cannot hold NDEF reaches the handler as none', () async {
      expect(await handleOf(iosTag(NdefStatusPigeon.notSupported)), isNull);
    });

    test('an NDEF tag reports what it held when it was found', () async {
      const url =
          'https://submersion.app/c#f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
      final record = uriRecord(url);
      final handle = await handleOf(
        iosTag(
          NdefStatusPigeon.readWrite,
          cached: NdefMessagePigeon(
            records: [
              NdefPayloadPigeon(
                typeNameFormat: TypeNameFormatPigeon.wellKnown,
                type: record.type,
                identifier: Uint8List(0),
                payload: record.payload,
              ),
            ],
          ),
        ),
      );
      expect(handle, isNotNull);
      expect(handle!.isWritable, isTrue);
      expect(handle.maxMessageBytes, 137);
      expect(firstPassportUri(handle.discoveredMessage!), url);
    });
  });
}
