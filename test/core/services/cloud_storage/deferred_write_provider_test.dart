import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/deferred_write_provider.dart';
import 'package:submersion/core/services/cloud_storage/encrypting_cloud_storage_provider.dart';

/// Records flush and reset calls; every other member is unused here.
class _Deferring extends Fake
    implements CloudStorageProvider, DeferredWriteProvider, HistoryResettable {
  final calls = <String>[];
  final timeouts = <Duration?>[];

  @override
  Future<void> flush({Duration? timeout}) async {
    calls.add('flush');
    timeouts.add(timeout);
  }

  @override
  Future<void> resetHistoryNow() async => calls.add('reset');
}

class _Plain extends Fake implements CloudStorageProvider {}

void main() {
  test('flushDeferredWrites flushes a deferring provider', () async {
    final p = _Deferring();
    await flushDeferredWrites(p);
    expect(p.calls, ['flush']);
  });

  test(
    'flushDeferredWrites and the reset helper ignore other providers',
    () async {
      await flushDeferredWrites(_Plain());
      await resetHistoryNowIfSupported(_Plain());
    },
  );

  test('resetHistoryNowIfSupported resets a resettable provider', () async {
    final p = _Deferring();
    await resetHistoryNowIfSupported(p);
    expect(p.calls, ['reset']);
  });

  test(
    'the encrypting wrapper passes both through to its inner provider',
    () async {
      final inner = _Deferring();
      final wrapped = EncryptingCloudStorageProvider(
        inner,
        dataKey: SecretKey(List.filled(32, 7)),
        libraryKeyId: 'lib',
      );
      await flushDeferredWrites(wrapped);
      await resetHistoryNowIfSupported(wrapped);
      expect(inner.calls, ['flush', 'reset']);
    },
  );

  test('a flush timeout reaches the provider through the wrapper', () async {
    final inner = _Deferring();
    final wrapped = EncryptingCloudStorageProvider(
      inner,
      dataKey: SecretKey(List.filled(32, 7)),
      libraryKeyId: 'lib',
    );
    await flushDeferredWrites(wrapped, timeout: const Duration(seconds: 20));
    expect(inner.timeouts, [const Duration(seconds: 20)]);
  });
}
