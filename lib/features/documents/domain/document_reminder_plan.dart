import 'package:flutter/material.dart' show TimeOfDay;

import 'package:submersion/features/documents/domain/entities/document.dart';

enum DocumentReminderStage { lead, expiryDay }

typedef DocumentReminder = ({
  DocumentReminderStage stage,
  DateTime fireAt,
  int daysLeft,
});

/// When to remind about [document] (issue #2613): on the lead day and on
/// the expiry day, at the diver's reminder time, skipping any moment
/// already past. Built from calendar dates (`DateTime(y, m, d - n)`), so a
/// DST change never moves a reminder to another day.
List<DocumentReminder> documentReminderPlan(
  Document document,
  DateTime now,
  TimeOfDay at,
) {
  final expiry = document.expiryDate;
  if (!document.remindsOnExpiry || expiry == null) return const [];
  final lead = document.effectiveReminderLeadDays;
  final out = <DocumentReminder>[];
  if (lead > 0) {
    final fireAt = DateTime(
      expiry.year,
      expiry.month,
      expiry.day - lead,
      at.hour,
      at.minute,
    );
    if (fireAt.isAfter(now)) {
      out.add((
        stage: DocumentReminderStage.lead,
        fireAt: fireAt,
        daysLeft: lead,
      ));
    }
  }
  final expiryAt = DateTime(
    expiry.year,
    expiry.month,
    expiry.day,
    at.hour,
    at.minute,
  );
  if (expiryAt.isAfter(now)) {
    out.add((
      stage: DocumentReminderStage.expiryDay,
      fireAt: expiryAt,
      daysLeft: 0,
    ));
  }
  return out;
}
