import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/notification_service.dart';

/// A tapped reminder opens what it is about (issue #2613): a document
/// reminder its document, an equipment reminder its item.
void main() {
  test('a document reminder opens the document', () {
    expect(notificationPayloadRoute('document:abc'), '/documents/abc');
  });

  test('an equipment reminder opens the item', () {
    expect(notificationPayloadRoute('e-42'), '/equipment/e-42');
  });

  test('an empty payload opens nothing', () {
    expect(notificationPayloadRoute(''), isNull);
    expect(notificationPayloadRoute('document:'), isNull);
  });
}
