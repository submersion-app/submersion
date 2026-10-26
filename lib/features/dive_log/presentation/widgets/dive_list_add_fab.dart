import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_scrubber_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';

/// The add-dive button. It scales away and stops taking taps, focus and
/// semantics while the list scrubber is active, and watches that flag itself
/// so a flip rebuilds only this button.
class DiveListAddFab extends ConsumerWidget implements MasterDetailCreateFab {
  const DiveListAddFab({super.key, required this.onPressed});

  static const scaleKey = ValueKey('diveListAddFab.scale');
  static const pointerKey = ValueKey('diveListAddFab.pointer');

  final VoidCallback onPressed;

  @override
  Widget withOnPressed(VoidCallback onPressed) =>
      DiveListAddFab(key: key, onPressed: onPressed);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(diveListScrubbingProvider);
    return AnimatedScale(
      key: scaleKey,
      scale: hidden ? 0 : 1,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: IgnorePointer(
        key: pointerKey,
        ignoring: hidden,
        child: ExcludeSemantics(
          excluding: hidden,
          child: ExcludeFocus(
            excluding: hidden,
            child: FloatingActionButton.extended(
              onPressed: onPressed,
              tooltip: context.l10n.diveLog_listPage_fab_logDive,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.diveLog_listPage_fab_logDive),
            ),
          ),
        ),
      ),
    );
  }
}
