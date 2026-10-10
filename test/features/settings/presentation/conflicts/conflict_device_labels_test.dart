import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_device_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  ConflictDeviceLabels labels({
    String? localName = 'Pixel 8',
    String? localId = 'local-id',
    Map<String, String> peers = const {'peer-id': 'Windows PC'},
    String? hlc = '1786556582600:0:peer-id',
  }) => conflictDeviceLabels(
    l10n: l10n,
    localName: localName,
    localDeviceId: localId,
    peerNames: peers,
    remoteData: {'hlc': ?hlc},
  );

  test('names both devices', () {
    final l = labels();
    expect(l.local, 'Pixel 8');
    expect(l.remote, 'Windows PC');
    expect(l.localKind, ConflictDeviceKind.named);
    expect(l.remoteKind, ConflictDeviceKind.named);
  });

  test('a generic label says which generic side it is', () {
    // Sentences need the kind to word "this device" and "the other device"
    // grammatically instead of splicing in the capitalised label.
    final l = labels(localName: null, peers: const {});
    expect(l.localKind, ConflictDeviceKind.thisDevice);
    expect(l.remoteKind, ConflictDeviceKind.otherDevice);
  });

  test('one side can be generic while the other is named', () {
    final l = labels(peers: const {});
    expect(l.localKind, ConflictDeviceKind.named);
    expect(l.remoteKind, ConflictDeviceKind.otherDevice);
  });

  test('an unknown peer is the other device', () {
    expect(labels(peers: const {}).remote, 'Other device');
  });

  test('a missing local name is this device', () {
    expect(labels(localName: null).local, 'This device');
    expect(labels(localName: '  ').local, 'This device');
  });

  test('an unparseable or missing hlc is the other device', () {
    expect(labels(hlc: 'garbage').remote, 'Other device');
    expect(labels(hlc: 'x:y:peer-id').remote, 'Other device');
    expect(labels(hlc: null).remote, 'Other device');
  });

  test('a remote row last written by this device does not borrow a name', () {
    final l = labels(
      hlc: '1786556582600:0:local-id',
      peers: const {'local-id': 'Pixel 8'},
    );
    expect(l.local, 'This device');
    expect(l.remote, 'Other device');
    expect(l.localKind, ConflictDeviceKind.thisDevice);
    expect(l.remoteKind, ConflictDeviceKind.otherDevice);
  });

  test('two devices with the same name fall back to generic labels', () {
    final l = labels(peers: const {'peer-id': 'pixel 8 '});
    expect(l.local, 'This device');
    expect(l.remote, 'Other device');
  });
}
