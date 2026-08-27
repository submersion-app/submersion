import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/media_store/media_object_store.dart';

class _FakeS3Adapter extends AccountProviderAdapter
    implements MediaStoreCapable {
  @override
  AccountKind get kind => AccountKind.s3;

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async =>
      AccountStatus.signedIn;

  @override
  Future<void> disconnect(domain.ConnectedAccount account) async {}

  @override
  Future<MediaObjectStore?> mediaObjectStore(
    domain.ConnectedAccount account,
  ) async => null;
}

class _FakeLightroomAdapter extends AccountProviderAdapter
    implements MediaSourceCapable {
  @override
  AccountKind get kind => AccountKind.adobeLightroom;

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async =>
      AccountStatus.needsSignIn;

  @override
  Future<void> disconnect(domain.ConnectedAccount account) async {}
}

void main() {
  final registry = AccountProviderRegistry([
    _FakeS3Adapter(),
    _FakeLightroomAdapter(),
  ]);

  test('adapterFor returns the adapter registered for the kind', () {
    expect(registry.adapterFor(AccountKind.s3), isA<_FakeS3Adapter>());
    expect(
      registry.adapterFor(AccountKind.adobeLightroom),
      isA<_FakeLightroomAdapter>(),
    );
  });

  test('adapterFor throws StateError for an unregistered kind', () {
    expect(() => registry.adapterFor(AccountKind.dropbox), throwsStateError);
  });

  test('capabilityFor returns the adapter as the capability or null', () {
    expect(
      registry.capabilityFor<MediaStoreCapable>(AccountKind.s3),
      isNotNull,
    );
    expect(
      registry.capabilityFor<MediaStoreCapable>(AccountKind.adobeLightroom),
      isNull,
      reason: 'Lightroom lacks MediaStoreCapable',
    );
    expect(
      registry.capabilityFor<MediaSourceCapable>(AccountKind.adobeLightroom),
      isNotNull,
    );
    expect(
      registry.capabilityFor<SyncCapable>(AccountKind.dropbox),
      isNull,
      reason: 'unregistered kind yields null capability',
    );
  });
}
