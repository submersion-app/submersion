import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/features/certifications/presentation/utils/certification_group_by_display.dart';
import 'package:submersion/features/certifications/presentation/utils/certification_grouping.dart';
import 'package:submersion/features/dive_sites/domain/utils/site_grouping.dart';
import 'package:submersion/features/dive_sites/presentation/utils/site_group_by_display.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/diver_settings_fields.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A sync conflict over how a list was left (issue #3748) shows the sort and
/// grouping the way the list's own sheet names them, never the stored form.
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  String? label(String column, String stored) =>
      diverSettingsFields[column]!.enumLabel!(l10n, stored);

  test('every list sort and grouping column is labelled', () {
    for (final column in [
      'diveListSort',
      'divePlanListSort',
      'tripListSort',
      'courseListSort',
      'buddyListSort',
      'diveCenterListSort',
      'siteListSort',
      'certificationListSort',
      'equipmentListSort',
      'siteListGroupBy',
      'certificationListGroupBy',
    ]) {
      expect(
        diverSettingsFields[column]!.kind,
        FieldKind.enumValue,
        reason: column,
      );
      expect(diverSettingsFields[column]!.enumLabel, isNotNull, reason: column);
    }
  });

  test('a sort reads as its field and direction', () {
    expect(
      label('diveListSort', 'depth:descending'),
      l10n.settings_conflict_sortValue(
        DiveSortField.depth.localizedName(l10n),
        SortDirection.descending.localizedName(l10n),
      ),
    );
    expect(
      label('equipmentListSort', 'serviceDue:ascending'),
      l10n.settings_conflict_sortValue(
        EquipmentSortField.serviceDue.localizedName(l10n),
        SortDirection.ascending.localizedName(l10n),
      ),
    );
  });

  test('a grouping reads as the grouping sheet names it', () {
    expect(
      label('siteListGroupBy', 'water'),
      SiteGroupBy.water.localizedName(l10n),
    );
    expect(
      label('certificationListGroupBy', 'agency'),
      CertificationGroupBy.agency.localizedName(l10n),
    );
  });

  test('a value a newer build wrote has no label', () {
    expect(label('diveListSort', 'bogus:descending'), isNull);
    expect(label('siteListGroupBy', 'bogus'), isNull);
  });
}
