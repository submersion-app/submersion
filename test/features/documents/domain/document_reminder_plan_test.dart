import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/domain/document_reminder_plan.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

Document _d(
  DateTime? expiry, {
  int? lead,
  DocumentType type = DocumentType.permit,
}) => Document(
  id: 'x',
  diverId: 'd',
  owner: const DocumentOwner.personal(),
  type: type,
  expiryDate: expiry,
  reminderLeadDays: lead,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  const at = TimeOfDay(hour: 9, minute: 0);
  final now = DateTime(2026, 10, 10, 12);

  test('lead day and expiry day, at the reminder time', () {
    final plan = documentReminderPlan(_d(DateTime(2026, 12, 31)), now, at);
    expect(plan.map((e) => e.fireAt), [
      DateTime(2026, 12, 1, 9),
      DateTime(2026, 12, 31, 9),
    ]);
    expect(plan.map((e) => e.stage), [
      DocumentReminderStage.lead,
      DocumentReminderStage.expiryDay,
    ]);
    expect(plan.first.daysLeft, 30);
    expect(plan.last.daysLeft, 0);
  });

  test('a lead day already past is skipped, the expiry day kept', () {
    final plan = documentReminderPlan(_d(DateTime(2026, 10, 20)), now, at);
    expect(plan.single.stage, DocumentReminderStage.expiryDay);
  });

  test('lead 0 keeps only the expiry day', () {
    final plan = documentReminderPlan(_d(DateTime(2027), lead: 0), now, at);
    expect(plan.single.stage, DocumentReminderStage.expiryDay);
  });

  test('no expiry, a card, or an expired document plan nothing', () {
    expect(documentReminderPlan(_d(null), now, at), isEmpty);
    expect(
      documentReminderPlan(
        _d(DateTime(2027), type: DocumentType.certificationCard),
        now,
        at,
      ),
      isEmpty,
    );
    expect(documentReminderPlan(_d(DateTime(2026, 1, 1)), now, at), isEmpty);
  });

  test('the lead day is a calendar day across a DST change', () {
    // 30 days before 2026-11-15 is 2026-10-16, whatever the clocks do.
    final plan = documentReminderPlan(
      _d(DateTime(2026, 11, 15)),
      DateTime(2026, 10, 1),
      at,
    );
    expect(plan.first.fireAt, DateTime(2026, 10, 16, 9));
  });
}
