import 'package:equatable/equatable.dart';

import 'package:submersion/features/documents/domain/entities/document.dart';

enum DocumentExpiryKind { none, ok, dueSoon, expired }

class DocumentExpiryStatus extends Equatable {
  final DocumentExpiryKind kind;

  /// Calendar days from today to the expiry day; negative once expired.
  /// Null for [DocumentExpiryKind.none].
  final int? daysLeft;

  const DocumentExpiryStatus(this.kind, this.daysLeft);

  static const none = DocumentExpiryStatus(DocumentExpiryKind.none, null);

  bool get needsAttention =>
      kind == DocumentExpiryKind.dueSoon || kind == DocumentExpiryKind.expired;

  @override
  List<Object?> get props => [kind, daysLeft];
}

/// The one rule chips, badges and the notification scheduler share.
///
/// Days are counted between calendar dates in UTC, so a DST change between
/// [now] and the expiry cannot shift the count by an hour into the wrong
/// day. The expiry day itself is "due, 0 days left", not expired.
DocumentExpiryStatus documentExpiryStatus(Document document, DateTime now) {
  final expiry = document.expiryDate;
  if (!document.remindsOnExpiry || expiry == null) {
    return DocumentExpiryStatus.none;
  }
  final today = DateTime.utc(now.year, now.month, now.day);
  final expiryDay = DateTime.utc(expiry.year, expiry.month, expiry.day);
  final daysLeft = expiryDay.difference(today).inDays;
  if (daysLeft < 0) {
    return DocumentExpiryStatus(DocumentExpiryKind.expired, daysLeft);
  }
  // A 0-day lead still makes the expiry day itself due: it drops only the
  // early reminder, and the expiry-day notification still fires.
  if (daysLeft <= document.effectiveReminderLeadDays) {
    return DocumentExpiryStatus(DocumentExpiryKind.dueSoon, daysLeft);
  }
  return DocumentExpiryStatus(DocumentExpiryKind.ok, daysLeft);
}
