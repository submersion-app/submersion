import 'package:flutter/material.dart';

import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/tag_scope_labels.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One "Use for ..." checkbox per scope in the registry (issues #1765,
/// #1942), with an error line while none is ticked. [onToggle] reports one
/// scope ticked or unticked; the caller applies it to its current set, so
/// two taps before a rebuild each keep their change. A scope in [locked]
/// shows its value but cannot be changed.
class TagScopeChecklist extends StatelessWidget {
  const TagScopeChecklist({
    super.key,
    required this.scopes,
    required this.onToggle,
    this.locked = const {},
  });

  final Set<TagScope> scopes;
  final void Function(TagScope scope, bool on) onToggle;
  final Set<TagScope> locked;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final scope in TagScope.values)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tagScopeUseForLabel(l10n, scope)),
            value: scopes.contains(scope),
            onChanged: locked.contains(scope)
                ? null
                : (v) => onToggle(scope, v ?? false),
          ),
        if (scopes.isEmpty)
          Text(
            l10n.tags_manage_scopeRequired,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}

/// The failed-save line, shown in a tag dialog itself: a page SnackBar would
/// render under the dialog's barrier, dimmed and out of reach (#1907). A
/// live region, so a screen reader announces it.
class TagSaveErrorLine extends StatelessWidget {
  const TagSaveErrorLine({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Semantics(
      liveRegion: true,
      child: Text(
        context.l10n.common_error_tryAgain,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  );
}
