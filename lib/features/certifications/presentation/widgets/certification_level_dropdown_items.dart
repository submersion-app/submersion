import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/presentation/iart_course_category.dart';
import 'package:submersion/features/certification_agencies/presentation/tdi_course_category.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_option.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The certification dropdown's grouped items for [agency], and whether
/// [extra] (a stored value outside the catalog, e.g. a legacy value the TDI
/// migration deliberately leaves unrewritten) was folded into one of those
/// groups rather than left for the caller to append on its own.
///
/// TDI and IART each group their own course names into their own categories
/// on their own websites, not into the generic progression/specialties
/// split every other agency uses (issues #3072, #3357). Display-only: the
/// stored value and the ladder/specialty split behind
/// ladderFor/specialtiesFor are unaffected.
///
/// A value with no TDI/IART category -- [extra], or a diver's own custom
/// level -- must not fall through to a headerless append after the last
/// group: with no header of its own there, it visually reads as belonging
/// to whichever category happens to render last (Professional), which is
/// actively misleading for a value that has nothing to do with that
/// category. It renders under a Specialties catch-all instead, same as the
/// generic agencies' own Specialties group.
({List<DropdownMenuItem<CertificationOption>> items, bool extraRenderedInGroup})
buildGroupedCertificationItems({
  required String agency,
  required List<LevelEntry> ladder,
  required List<LevelEntry> specialties,
  required LevelEntry? extra,
  required AppLocalizations l10n,
  required DropdownMenuItem<CertificationOption> Function(
    String key,
    String text,
  )
  header,
  required DropdownMenuItem<CertificationOption> Function(LevelEntry value)
  item,
}) {
  if (agency == CertificationAgency.tdi.name) {
    return _buildCategorizedItems(
      categories: TdiCourseCategory.values,
      grouped: groupLevelEntriesByTdiCategory([...ladder, ...specialties]),
      extra: extra,
      categoryKey: (c) => c.name,
      categoryLabel: (c) => c.label(l10n),
      l10n: l10n,
      header: header,
      item: item,
    );
  }

  if (agency == CertificationAgency.iart.name) {
    return _buildCategorizedItems(
      categories: IartCourseCategory.values,
      grouped: groupLevelEntriesByIartCategory([...ladder, ...specialties]),
      extra: extra,
      categoryKey: (c) => c.name,
      categoryLabel: (c) => c.label(l10n),
      l10n: l10n,
      header: header,
      item: item,
    );
  }

  return (
    items: [
      header('progression', l10n.certifications_edit_group_progression),
      ...ladder.map(item),
      header('specialties', l10n.certifications_edit_group_specialties),
      ...specialties.map(item),
    ],
    extraRenderedInGroup: false,
  );
}

/// Shared shape behind the TDI and IART branches above: render each
/// non-empty category in order under its own header, then fold anything
/// that has no category -- [extra] and a diver's own custom level alike --
/// into a single Specialties catch-all header at the end.
({List<DropdownMenuItem<CertificationOption>> items, bool extraRenderedInGroup})
_buildCategorizedItems<C>({
  required Iterable<C> categories,
  required ({
    Map<C, List<LevelEntry>> byCategory,
    List<LevelEntry> uncategorized,
  })
  grouped,
  required LevelEntry? extra,
  required String Function(C category) categoryKey,
  required String Function(C category) categoryLabel,
  required AppLocalizations l10n,
  required DropdownMenuItem<CertificationOption> Function(
    String key,
    String text,
  )
  header,
  required DropdownMenuItem<CertificationOption> Function(LevelEntry value)
  item,
}) {
  final uncategorized = [...grouped.uncategorized, ?extra];
  return (
    items: [
      for (final category in categories)
        if (grouped.byCategory[category] case final entries?
            when entries.isNotEmpty) ...[
          header(categoryKey(category), categoryLabel(category)),
          ...entries.map(item),
        ],
      if (uncategorized.isNotEmpty) ...[
        header('specialties', l10n.certifications_edit_group_specialties),
        ...uncategorized.map(item),
      ],
    ],
    extraRenderedInGroup: extra != null,
  );
}
