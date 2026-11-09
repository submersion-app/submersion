import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/features/change_log/presentation/change_log_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  test('a source removal is named in the change log', () {
    expect(
      changeLogStoredLabel(l, ChangeLogLabels.removeSource),
      'Removed a data source',
    );
  });

  test('a duplicate cylinder removal is named in the change log', () {
    expect(
      changeLogStoredLabel(l, ChangeLogLabels.removeDuplicateCylinders),
      'Removed duplicate cylinders',
    );
  });
}
