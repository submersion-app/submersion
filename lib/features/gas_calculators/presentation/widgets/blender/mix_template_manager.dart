import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/mix_template_messages.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Add and delete saved target-fill mixes (issue #1335 follow-up).
///
/// A section within the settings page rather than a dialog opened from the
/// calculator: managing these now lives entirely under Settings -> Trimix
/// Mixer, and the calculator's own template menu is a plain picker onto
/// whatever is saved here.
class MixTemplateManager extends ConsumerStatefulWidget {
  const MixTemplateManager({super.key});

  @override
  ConsumerState<MixTemplateManager> createState() => _MixTemplateManagerState();
}

class _MixTemplateManagerState extends ConsumerState<MixTemplateManager> {
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
  void _add() {
    final o2 = parseUserDecimal(_o2.text);
    final he = parseUserDecimal(_he.text);
    if (o2 == null || he == null) {
      // Not the same complaint as an impossible mix: a blank or half-typed
      // box is missing a number, and a silent no-op reads as a broken button.
      setState(
        () =>
            _message = context.l10n.gasCalculators_blender_templateNeedsNumbers,
      );
      return;
    }
    final candidate = MixTemplate(o2: o2, he: he);
    final existing = ref.read(blenderTemplatesProvider);
    final problem = describeTemplateRejection(
      context,
      rejectionFor(existing, candidate),
    );
    if (problem != null) {
      setState(() => _message = problem);
      return;
    }
    ref.read(blenderTemplatesProvider.notifier).state = [
      ...existing,
      candidate,
    ];
    saveBlenderPreferences(ref);
    setState(() => _message = null);
    _o2.clear();
    _he.clear();
  }

  void _delete(MixTemplate t) {
    ref.read(blenderTemplatesProvider.notifier).state = [
      ...ref.read(blenderTemplatesProvider).where((x) => x != t),
    ];
    saveBlenderPreferences(ref);
  }

  @override
  Widget build(BuildContext context) {
    final templates = ref.watch(blenderTemplatesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.gasCalculators_blender_templatesTitle,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (templates.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              context.l10n.gasCalculators_blender_templateNone,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          for (final t in templates)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(t.label),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: context.l10n.gasCalculators_blender_templateDelete(
                  t.label,
                ),
                onPressed: () => _delete(t),
              ),
            ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
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
