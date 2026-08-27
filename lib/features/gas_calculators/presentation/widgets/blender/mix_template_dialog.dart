import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/mix_template_messages.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Add and delete saved target mixes.
Future<void> showMixTemplateDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _MixTemplateDialog(),
  );
}

/// A consumer in its own right rather than a borrower of the opener's ref.
/// Watching through someone else's ref registers the dependency on THEIR
/// element: the dialog never rebuilds, and the parent rebuilds for changes it
/// does not care about (PR #1215 review).
class _MixTemplateDialog extends ConsumerStatefulWidget {
  const _MixTemplateDialog();

  @override
  ConsumerState<_MixTemplateDialog> createState() => _MixTemplateDialogState();
}

class _MixTemplateDialogState extends ConsumerState<_MixTemplateDialog> {
  final _o2 = TextEditingController();
  final _he = TextEditingController();

  /// The outcome of the last add attempt, shown under the entry row.
  String? _message;

  @override
  void dispose() {
    _o2.dispose();
    _he.dispose();
    super.dispose();
  }

  /// Add the typed mix, saying why when it cannot be added.
  ///
  /// Returning quietly reads as a broken button, and the menu's save action
  /// already explains itself (PR #1215 review).
  void _add() {
    final o2 = parseUserDecimal(_o2.text);
    final he = parseUserDecimal(_he.text);
    if (o2 == null || he == null) {
      // Not the same complaint as an impossible mix: a blank or half-typed
      // box is missing a number, and saying "O2 + He cannot exceed 100%"
      // sends the user looking for a problem that is not there.
      _say(context.l10n.gasCalculators_blender_templateNeedsNumbers);
      return;
    }
    final candidate = MixTemplate(o2: o2, he: he);
    final existing = ref.read(blenderTemplatesProvider);
    final problem = describeTemplateRejection(
      context,
      rejectionFor(existing, candidate),
    );
    if (problem != null) {
      _say(problem);
      return;
    }
    ref.read(blenderTemplatesProvider.notifier).state = [
      ...existing,
      candidate,
    ];
    saveBlenderPreferences(ref);
    _say(context.l10n.gasCalculators_blender_templateSaved(candidate.label));
    _o2.clear();
    _he.clear();
  }

  /// The dialog sits above the page's ScaffoldMessenger, so a SnackBar posted
  /// from here would slide in behind it. Say it in the dialog instead.
  void _say(String message) => setState(() => _message = message);

  void _delete(MixTemplate t) {
    ref.read(blenderTemplatesProvider.notifier).state = [
      ...ref.read(blenderTemplatesProvider).where((x) => x != t),
    ];
    saveBlenderPreferences(ref);
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(blenderTemplatesProvider);
    return AlertDialog(
      title: Text(context.l10n.gasCalculators_blender_templatesTitle),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (templates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(context.l10n.gasCalculators_blender_templateNone),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final t in templates)
                      ListTile(
                        dense: true,
                        title: Text(t.label),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: context.l10n
                              .gasCalculators_blender_templateDelete(t.label),
                          onPressed: () => _delete(t),
                        ),
                      ),
                  ],
                ),
              ),
            const Divider(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _message!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Row(
              children: [
                Expanded(child: _numberField(_o2, 'O₂')),
                const SizedBox(width: 8),
                Expanded(child: _numberField(_he, 'He')),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: context.l10n.gasCalculators_blender_templateAdd,
                  onPressed: _add,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_action_close),
        ),
      ],
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText: '$label (%)',
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
