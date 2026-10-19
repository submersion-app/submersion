import 'package:flutter/material.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_group_by_selector.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_view_switch_selector.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';

/// Opens the certification sort sheet, shared by the list (phone, compact
/// bar and table mode) and the wallet page (#3359), so sort, grouping and
/// the List/Certification Wallet switch all live in one place.
///
/// [includeGroupBySelector] is false for table mode, which has no grouping
/// control (#3359's own scope decision) but still offers the view switch.
void showCertificationSortSheet(
  BuildContext context,
  WidgetRef ref, {
  required CertificationView currentView,
  bool includeGroupBySelector = true,
}) {
  final sort = ref.read(certificationSortProvider);
  showSortBottomSheet<CertificationSortField>(
    context: context,
    title: context.l10n.certifications_list_sort_title,
    currentField: sort.field,
    currentDirection: sort.direction,
    fields: CertificationSortField.values,
    getFieldDisplayName: (field) => field.localizedName(context.l10n),
    getFieldIcon: (field) => field.icon,
    onSortChanged: (field, direction) {
      ref.read(certificationSortProvider.notifier).state = SortState(
        field: field,
        direction: direction,
      );
    },
    footer: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (includeGroupBySelector) ...[
          const CertificationGroupBySelector(),
          const Divider(height: 1),
        ],
        CertificationViewSwitchSelector(currentView: currentView),
      ],
    ),
  );
}
