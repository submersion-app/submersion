import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Which certification view the sort sheet was opened from (#3359). Driven
/// by the current route, not a provider: it is whichever page is on screen,
/// not a choice that persists.
enum CertificationView { list, wallet }

/// The certification sort sheet's List/Certification Wallet switch (#3359).
/// Picking the other view navigates the same way the existing wallet icon
/// does (those icons stay as an additional entry point, per the issue) and
/// closes the sheet. [RadioGroup] (non-toggleable) never calls [onChanged]
/// for a tap on the view already selected, so that tap does nothing at all
/// -- the sheet stays open, like tapping the already-selected option on any
/// other radio list in the app.
class CertificationViewSwitchSelector extends ConsumerWidget {
  const CertificationViewSwitchSelector({super.key, required this.currentView});

  final CertificationView currentView;

  void _navigateTo(BuildContext context, CertificationView target) {
    Navigator.of(context).pop();
    switch (target) {
      case CertificationView.wallet:
        context.push('/certifications/wallet');
      case CertificationView.list:
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/certifications');
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RadioGroup<CertificationView>(
            groupValue: currentView,
            onChanged: (value) {
              if (value == null) return;
              _navigateTo(context, value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<CertificationView>(
                  value: CertificationView.list,
                  title: Text(l10n.certifications_sortSheet_view_list),
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<CertificationView>(
                  value: CertificationView.wallet,
                  title: Text(l10n.certifications_sortSheet_view_wallet),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
