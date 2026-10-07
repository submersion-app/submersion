import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/presentation/tdi_course_category.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_option.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The certification dropdown's grouped items for [agency], and whether
/// [extra] (a stored value outside the catalog, e.g. a legacy value the TDI
/// migration deliberately leaves unrewritten) was folded into one of those
/// groups rather than left for the caller to append on its own.
///
/// TDI groups its own course names into five categories on its own website,
/// not into the generic progression/specialties split every other agency
/// uses (issue #3072). Display-only: the stored value and the ladder/
/// specialty split behind ladderFor/specialtiesFor are unaffected.
///
/// A value with no TDI category -- [extra], or a diver's own custom level --
/// must not fall through to a headerless append after the last group: with
/// no header of its own there, it visually reads as belonging to whichever
/// category happens to render last (Professional), which is actively
/// misleading for a value that has nothing to do with that category. It
/// renders under a Specialties catch-all instead, same as the generic
/// agencies' own Specialties group.
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
  if (agency != CertificationAgency.tdi.name) {
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

  final grouped = groupLevelEntriesByTdiCategory([...ladder, ...specialties]);
  final uncategorized = [...grouped.uncategorized, ?extra];
  return (
    items: [
      for (final category in TdiCourseCategory.values)
        if (grouped.byCategory[category] case final entries?
            when entries.isNotEmpty) ...[
          header(category.name, category.label(l10n)),
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
