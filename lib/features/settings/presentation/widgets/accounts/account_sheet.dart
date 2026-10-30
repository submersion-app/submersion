import 'package:flutter/material.dart';

import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_chooser.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/own_server_form.dart';

export 'package:submersion/features/settings/presentation/widgets/accounts/account_chooser.dart'
    show AccountSheetChoice, ChoseAccount, ChoseNone;

/// The one account picker (spec section 7.4): the diver's accounts, then
/// the kinds that can be added here. Returns the chosen account, signed in
/// on this device, or null when the diver backs out.
///
/// [allowedKinds] restricts both sections (shared libraries allow only S3
/// and WebDAV). When [consequenceOf] returns text for the choice, the sheet
/// shows it with Cancel and Continue before returning, so a choice with
/// consequences is explained before it takes effect. [webdavCheck] is how an
/// own WebDAV server added or signed in here is checked (a library reaches
/// its folder read only).
Future<AccountGroup?> showAccountSheet(
  BuildContext context, {
  Set<AccountKind>? allowedKinds,
  String? currentKey,
  bool addOnly = false,
  String? Function(AccountGroup choice)? consequenceOf,
  WebDavCheck? webdavCheck,
}) async => switch (await _showSheet(
  context,
  allowedKinds: allowedKinds,
  currentKey: currentKey,
  addOnly: addOnly,
  consequenceOf: consequenceOf,
  webdavCheck: webdavCheck,
)) {
  ChoseAccount(:final group) => group,
  _ => null,
};

/// [showAccountSheet] with a first choice of no account, [noneLabel] (the
/// Backups copy's "No copy off this device", spec section 12), shown as
/// selected when [noneSelected]. Null when the diver backs out.
Future<AccountSheetChoice?> showAccountOrNoneSheet(
  BuildContext context, {
  required String noneLabel,
  required bool noneSelected,
  Set<AccountKind>? allowedKinds,
  String? currentKey,
  String? Function(AccountGroup choice)? consequenceOf,
}) => _showSheet(
  context,
  allowedKinds: allowedKinds,
  currentKey: currentKey,
  consequenceOf: consequenceOf,
  noneLabel: noneLabel,
  noneSelected: noneSelected,
);

Future<AccountSheetChoice?> _showSheet(
  BuildContext context, {
  Set<AccountKind>? allowedKinds,
  String? currentKey,
  bool addOnly = false,
  String? Function(AccountGroup choice)? consequenceOf,
  WebDavCheck? webdavCheck,
  String? noneLabel,
  bool noneSelected = false,
}) => showModalBottomSheet<AccountSheetChoice>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.75,
    maxChildSize: 0.95,
    builder: (sheetContext, controller) => AccountChooser(
      controller: controller,
      allowedKinds: allowedKinds,
      currentKey: currentKey,
      addOnly: addOnly,
      consequenceOf: consequenceOf,
      webdavCheck: webdavCheck,
      noneLabel: noneLabel,
      noneSelected: noneSelected,
      onChosen: (choice) => Navigator.of(sheetContext).pop(choice),
      onCancel: () => Navigator.of(sheetContext).pop(),
    ),
  ),
);
