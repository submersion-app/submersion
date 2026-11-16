import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/notification_service.dart';

/// A tapped reminder opens what it is about (issue #2613): a document
/// reminder its document, an equipment reminder its item.
void main() {
  test('a document reminder opens the document', () {
    expect(notificationPayloadRoute('document:abc'), '/documents/abc');
  });

  test('a document reminder that names its diver opens the document '
      '(#4609)', () {
    expect(
      notificationPayloadRoute(documentReminderPayload('abc', 'd1')),
      '/documents/abc',
    );
  });

  test('a document reminder payload carries the document and its diver; '
      'one from before carries the document alone (#4609)', () {
    expect(parseDocumentReminderPayload(documentReminderPayload('abc', 'd1')), (
      documentId: 'abc',
      diverId: 'd1',
    ));
    expect(parseDocumentReminderPayload('document:abc'), (
      documentId: 'abc',
      diverId: null,
    ));
    expect(parseDocumentReminderPayload('document:'), isNull);
    expect(parseDocumentReminderPayload('document:?diver=d1'), isNull);
    expect(parseDocumentReminderPayload('e-42'), isNull);
  });

  test('pending payloads fold into each document and the diver either '
      'stage names; other payloads are left out (#4609)', () {
    expect(
      documentRemindersFromPayloads([
        documentReminderPayload('a', 'd1'),
        'document:a',
        'document:b',
        documentReminderPayload('c', 'd2'),
        null,
        'e-42',
        'dive:x',
      ]),
      {'a': 'd1', 'b': null, 'c': 'd2'},
    );
    // The order of the stages does not matter.
    expect(
      documentRemindersFromPayloads([
        'document:a',
        documentReminderPayload('a', 'd1'),
      ]),
      {'a': 'd1'},
    );
  });

  test('an equipment reminder opens the item', () {
    expect(notificationPayloadRoute('e-42'), '/equipment/e-42');
  });

  test('an empty payload opens nothing', () {
    expect(notificationPayloadRoute(''), isNull);
    expect(notificationPayloadRoute('document:'), isNull);
  });

  test('a new Apple Watch dive opens that dive (#637)', () {
    expect(notificationPayloadRoute('dive:d1'), '/dives/d1');
    expect(notificationPayloadRoute('dive:'), isNull);
  });

  test('several new dives open the dive list', () {
    expect(notificationPayloadRoute('dives'), '/dives');
  });

  test('a workout that waits for the diver opens the Health import', () {
    expect(
      notificationPayloadRoute('healthReview'),
      '/settings/wearable-import',
    );
  });
}
