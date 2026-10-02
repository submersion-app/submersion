import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';

void main() {
  const service = UnsupportedNfcTagService();

  test('reports no NFC', () async {
    expect(await service.support(), NfcSupport.unsupported);
  });

  test('refuses to start a session', () async {
    await expectLater(
      service.withTag<int>(promptIos: 'Hold near', onTag: (_) async => 1),
      throwsA(isA<StateError>()),
    );
  });

  test('has nothing to cancel', () async {
    await expectLater(service.cancel(), completes);
  });
}
