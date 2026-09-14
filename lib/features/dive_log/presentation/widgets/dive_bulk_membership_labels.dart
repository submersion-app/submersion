import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/bulk_edit/bulk_membership_editor.dart';

/// The dive bulk editor's row wording, for [BulkMembershipEditor]. These are
/// the keys the editor used before it moved to lib/shared (issue #1942), so
/// the dive screens read exactly as they did, in every locale.
BulkMembershipLabels diveBulkMembershipLabels(AppLocalizations l10n) =>
    BulkMembershipLabels(
      onAll: l10n.diveLog_bulkEdit_membership_onAll,
      onSome: l10n.diveLog_bulkEdit_membership_onSome,
      adding: l10n.diveLog_bulkEdit_membership_adding,
      removing: l10n.diveLog_bulkEdit_membership_removing,
      empty: l10n.diveLog_bulkEdit_membership_empty,
      add: l10n.diveLog_edit_add,
    );
