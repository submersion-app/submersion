import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/mix_template_dialog.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/mix_template_messages.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Sentinels for the two actions at the foot of the menu. Plain objects rather
/// than a wrapper enum so the menu's value type stays the template itself.
final Object _saveAction = Object();
final Object _manageAction = Object();

/// Saved target mixes, offered as a menu beside the target fill fields.
///
/// A blender repeats the same handful of mixes, so retyping 10/70 on every
/// fill is the friction this removes. Templates carry a mix only: the same mix
/// gets blended into different cylinders at different pressures.
class MixTemplateMenu extends ConsumerWidget {
  const MixTemplateMenu({super.key, required this.onSelected});

  /// Called after the target mix providers are updated, so the caller can
  /// re-seed its text controllers.
  final void Function(MixTemplate) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(blenderTemplatesProvider);

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
          value: _saveAction,
          child: Text(context.l10n.gasCalculators_blender_saveTemplate),
        ),
        PopupMenuItem<Object>(
          value: _manageAction,
          child: Text(context.l10n.gasCalculators_blender_manageTemplates),
        ),
      ],
      onSelected: (value) {
        if (value is MixTemplate) {
          ref.read(blenderTargetMixProvider.notifier).state = GasMix(
            o2: value.o2,
            he: value.he,
          );
          onSelected(value);
          return;
        }
        if (identical(value, _saveAction)) {
          _saveCurrent(context, ref);
          return;
        }
        showMixTemplateDialog(context);
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

  /// Append the target mix, refusing a duplicate, an impossible mix, or one
  /// past the cap, each with its own reason. A silent no-op would read as the
  /// menu being broken.
  void _saveCurrent(BuildContext context, WidgetRef ref) {
    final mix = ref.read(blenderTargetMixProvider);
    final candidate = MixTemplate(o2: mix.o2, he: mix.he);
    final existing = ref.read(blenderTemplatesProvider);

    final problem = describeTemplateRejection(
      context,
      rejectionFor(existing, candidate),
    );

    if (problem == null) {
      ref.read(blenderTemplatesProvider.notifier).state = [
        ...existing,
        candidate,
      ];
      saveBlenderPreferences(ref);
    }

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          problem ??
              context.l10n.gasCalculators_blender_templateSaved(
                candidate.label,
              ),
        ),
      ),
    );
  }
}
