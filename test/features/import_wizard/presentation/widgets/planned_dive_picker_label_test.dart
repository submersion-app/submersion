import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/planned_dive_picker_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The fill target picker names a draft (issue #637) by its taps, so the
/// diver can tell two drafts of one day apart.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const units = UnitFormatter(AppSettings());

  test('a closed draft reads from its entry to its exit', () {
    final draft = Dive(
      id: 'd',
      dateTime: DateTime(2026, 6, 1, 10, 2),
      entryTime: DateTime(2026, 6, 1, 10, 2),
      exitTime: DateTime(2026, 6, 1, 10, 54),
      isDraft: true,
    );

    final label = plannedDiveLabel(draft, units, l10n);

    expect(label, startsWith('Draft from '));
    expect(label, contains(units.formatTime(DateTime(2026, 6, 1, 10, 54))));
  });

  test('an open draft reads from its entry', () {
    final draft = Dive(
      id: 'd',
      dateTime: DateTime(2026, 6, 1, 10, 2),
      entryTime: DateTime(2026, 6, 1, 10, 2),
      isDraft: true,
    );

    expect(plannedDiveLabel(draft, units, l10n), isNot(contains(' to ')));
  });

  test('a plan reads as before', () {
    final plan = Dive(
      id: 'p',
      dateTime: DateTime(2026, 6, 1, 9),
      isPlanned: true,
    );

    expect(plannedDiveLabel(plan, units, l10n), isNot(startsWith('Draft')));
  });
}
