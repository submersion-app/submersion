import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/mix_template_messages.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Two quick actions offered below the saved templates, distinct from the
/// [MixTemplate] values the same menu also lists.
enum _TemplateAction { adjust, saveCurrent }

/// Saved target mixes, offered as a menu beside the target fill fields.
///
/// A blender repeats the same handful of mixes, so retyping 10/70 on every
/// fill is the friction this removes. Templates carry a mix only: the same mix
/// gets blended into different cylinders at different pressures.
///
/// Full management (add, delete, rename, reorder) still lives only under
/// Settings -> Trimix Mixer. This menu additionally offers "adjust values" on
/// whichever template matches the currently entered target mix, and "save
/// current fill" as a new template -- both without leaving the calculator
/// (issue #1359 follow-up).
class MixTemplateMenu extends ConsumerWidget {
  const MixTemplateMenu({super.key, required this.onSelected});

  /// Called after the target mix providers are updated, so the caller can
  /// re-seed its text controllers.
  final void Function(MixTemplate) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(blenderTemplatesProvider);
    final target = ref.watch(blenderTargetMixProvider);
    final selectedIndex = templates.indexOf(
      MixTemplate(o2: target.o2, he: target.he),
    );
    final selected = selectedIndex == -1 ? null : templates[selectedIndex];

    return PopupMenuButton<Object>(
      tooltip: context.l10n.gasCalculators_blender_templates,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        if (templates.isEmpty)
          PopupMenuItem<Object>(
            enabled: false,
            child: Text(context.l10n.gasCalculators_blender_templateNone),
          )
        else
          for (final t in templates)
            PopupMenuItem<Object>(value: t, child: Text(t.label)),
        const PopupMenuDivider(),
        PopupMenuItem<Object>(
          value: _TemplateAction.adjust,
          enabled: selected != null,
          child: Text(context.l10n.gasCalculators_blender_templateAdjust),
        ),
        PopupMenuItem<Object>(
          value: _TemplateAction.saveCurrent,
          child: Text(context.l10n.gasCalculators_blender_saveTemplate),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case final MixTemplate t:
            ref.read(blenderTargetMixProvider.notifier).state = GasMix(
              o2: t.o2,
              he: t.he,
            );
            onSelected(t);
            break;
          case _TemplateAction.adjust:
            if (selected != null) _adjustSelected(context, ref, selected);
            break;
          case _TemplateAction.saveCurrent:
            _saveCurrentFill(context, ref);
            break;
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.gasCalculators_blender_templates),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  /// Opens the edit dialog for [current], and on confirmation replaces it in
  /// place (keeping list order) and re-targets the calculator to the edited
  /// values, the same as picking a template from the menu does.
  Future<void> _adjustSelected(
    BuildContext context,
    WidgetRef ref,
    MixTemplate current,
  ) async {
    final others = ref
        .read(blenderTemplatesProvider)
        .where((t) => t != current)
        .toList();
    final edited = await showDialog<MixTemplate>(
      context: context,
      builder: (context) =>
          _TemplateEditDialog(initial: current, others: others),
    );
    if (edited == null) return;

    ref.read(blenderTemplatesProvider.notifier).state = [
      for (final t in ref.read(blenderTemplatesProvider))
        if (t == current) edited else t,
    ];
    ref.read(blenderTargetMixProvider.notifier).state = GasMix(
      o2: edited.o2,
      he: edited.he,
    );
    saveBlenderPreferences(ref);
    onSelected(edited);
  }

  /// Saves whatever the target O2/He fields currently hold as a new
  /// template, reusing the same acceptance rules the settings-page manager
  /// applies (issue #1215's `rejectionFor`/`describeTemplateRejection`).
  void _saveCurrentFill(BuildContext context, WidgetRef ref) {
    final target = ref.read(blenderTargetMixProvider);
    final candidate = MixTemplate(o2: target.o2, he: target.he);
    final existing = ref.read(blenderTemplatesProvider);
    final problem = describeTemplateRejection(
      context,
      rejectionFor(existing, candidate),
    );
    final messenger = ScaffoldMessenger.of(context);
    if (problem != null) {
      messenger.showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    ref.read(blenderTemplatesProvider.notifier).state = [
      ...existing,
      candidate,
    ];
    saveBlenderPreferences(ref);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.gasCalculators_blender_templateSaved(candidate.label),
        ),
      ),
    );
  }
}

/// Owns its own controllers, and disposes them in its own State -- the same
/// contract [BlenderInvoiceCard]'s line-edit dialog uses.
class _TemplateEditDialog extends StatefulWidget {
  const _TemplateEditDialog({required this.initial, required this.others});

  final MixTemplate initial;

  /// The other saved templates, i.e. every template except [initial] --
  /// what the edited value must not collide with.
  final List<MixTemplate> others;

  @override
  State<_TemplateEditDialog> createState() => _TemplateEditDialogState();
}

class _TemplateEditDialogState extends State<_TemplateEditDialog> {
  late final TextEditingController _o2;
  late final TextEditingController _he;

  /// The outcome of the last save attempt, shown under the fields.
  String? _message;

  @override
  void initState() {
    super.initState();
    _o2 = TextEditingController(text: formatDecimalForInput(widget.initial.o2));
    _he = TextEditingController(text: formatDecimalForInput(widget.initial.he));
  }

  @override
  void dispose() {
    _o2.dispose();
    _he.dispose();
    super.dispose();
  }

  void _submit() {
    final o2 = parseUserDecimal(_o2.text);
    final he = parseUserDecimal(_he.text);
    if (o2 == null || he == null) {
      setState(
        () =>
            _message = context.l10n.gasCalculators_blender_templateNeedsNumbers,
      );
      return;
    }
    final candidate = MixTemplate(o2: o2, he: he);
    final problem = describeTemplateRejection(
      context,
      rejectionFor(widget.others, candidate),
    );
    if (problem != null) {
      setState(() => _message = problem);
      return;
    }
    Navigator.of(context).pop(candidate);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.gasCalculators_blender_templateAdjust),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _numberField(
                  _o2,
                  context.l10n.gasCalculators_blender_o2,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _numberField(
                  _he,
                  context.l10n.gasCalculators_blender_he,
                ),
              ),
            ],
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _message!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_action_close),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(context.l10n.common_action_save),
        ),
      ],
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      autofocus: controller == _o2,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        labelText: '$label (%)',
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
