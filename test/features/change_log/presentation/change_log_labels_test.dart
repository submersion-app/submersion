import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_operation.dart';
import 'package:submersion/features/change_log/presentation/change_log_labels.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l = AppLocalizationsEn();

  test('the agent source has a label and an icon', () {
    expect(changeLogSourceLabel(l, ChangeLogSource.agent), 'Agent');
    expect(
      changeLogSourceIcon(ChangeLogSource.agent),
      Icons.smart_toy_outlined,
    );
  });

  test('an agent operation is titled by its own label', () {
    final operation = ChangeLogOperation(
      id: 'op',
      source: ChangeLogSource.agent,
      label: 'Fix buddy names',
      startedAt: DateTime(2026, 11, 2),
      endedAt: DateTime(2026, 11, 2),
    );

    expect(changeLogTitle(l, operation), 'Fix buddy names');
  });
}
