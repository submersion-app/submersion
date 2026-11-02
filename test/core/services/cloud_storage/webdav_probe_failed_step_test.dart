import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav_storage_provider.dart';

/// Fails one named step of the probe; the others succeed.
class _StepDav extends Fake implements WebDavClient {
  _StepDav(this.failOn);

  final String? failOn;

  void _maybeFail(String step) {
    if (failOn == step) {
      throw WebDavException('$step failed', code: WebDavErrorCode.unreachable);
    }
  }

  @override
  Future<WebDavEntry?> stat(String path) async {
    _maybeFail('stat');
    return WebDavEntry(
      path: '',
      isCollection: true,
      lastModified: DateTime.utc(2026),
    );
  }

  @override
  Future<void> ensureCollection(String path) async => _maybeFail('mkcol');

  @override
  Future<void> putBytes(
    String path,
    Uint8List data, {
    String contentType = 'application/octet-stream',
  }) async => _maybeFail('put');

  @override
  Future<Uint8List> getBytes(String path) async {
    _maybeFail('get');
    return Uint8List.fromList(utf8.encode('probe'));
  }

  @override
  Future<void> delete(String path) async => _maybeFail('delete');

  @override
  void close() {}
}

/// The WebDAV probe says which kind of step failed, for a browser's
/// diagnosis (issue #4121).
void main() {
  final config = WebDavConfig(
    serverUrl: 'https://dav.example.org',
    username: 'u',
    password: 'p',
  );

  WebDavStorageProvider failing(String? step) =>
      WebDavStorageProvider(clientFactory: (_) => _StepDav(step));

  test('a failure on the root lookup is a read failure', () async {
    final provider = failing('stat');
    await expectLater(
      provider.testConnection(config),
      throwsA(isA<WebDavException>()),
    );
    expect(provider.lastProbeFailedOnWrite, isFalse);
  });

  test('a failure creating the folder or writing is a write failure', () async {
    for (final step in ['mkcol', 'put']) {
      final provider = failing(step);
      await expectLater(
        provider.testConnection(config),
        throwsA(isA<WebDavException>()),
      );
      expect(provider.lastProbeFailedOnWrite, isTrue, reason: step);
    }
  });

  test('a failure reading the probe back is a read failure', () async {
    final provider = failing('get');
    await expectLater(
      provider.testConnection(config),
      throwsA(isA<WebDavException>()),
    );
    expect(provider.lastProbeFailedOnWrite, isFalse);
  });

  test('a passing probe leaves it false', () async {
    final provider = failing(null);
    await provider.testConnection(config);
    expect(provider.lastProbeFailedOnWrite, isFalse);
  });
}
