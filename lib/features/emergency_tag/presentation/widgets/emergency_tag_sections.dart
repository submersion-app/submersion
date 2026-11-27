import 'package:flutter/material.dart';

import 'package:submersion/features/emergency_tag/domain/entities/emergency_tag_choices.dart';
import 'package:submersion/features/emergency_tag/presentation/utils/emergency_tag_draft.dart';
import 'package:submersion/features/emergency_tag/presentation/utils/emergency_tag_l10n.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// That anyone who taps the tag can read it.
class EmergencyTagWarning extends StatelessWidget {
  const EmergencyTagWarning({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.visibility_outlined, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What a tap on the tag does, and with a call, which number it dials.
class EmergencyTagTapSection extends StatelessWidget {
  const EmergencyTagTapSection({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final EmergencyTagDraft draft;
  final ValueChanged<EmergencyTagChoices> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final choices = draft.choices;
    final canCall = draft.callTargets.isNotEmpty;
    void pick(EmergencyTagPrimary? primary) {
      if (primary != null) onChanged(choices.copyWith(primary: primary));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: RadioGroup<EmergencyTagPrimary>(
          groupValue: choices.primary,
          onChanged: pick,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  l10n.emergencyTag_tap_title,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              RadioListTile<EmergencyTagPrimary>(
                key: const Key('emergencyTag_tapLink'),
                value: EmergencyTagPrimary.link,
                title: Text(l10n.emergencyTag_tap_link),
                subtitle: Text(l10n.emergencyTag_tap_linkHint),
              ),
              RadioListTile<EmergencyTagPrimary>(
                key: const Key('emergencyTag_tapCall'),
                value: EmergencyTagPrimary.call,
                enabled: canCall,
                title: Text(l10n.emergencyTag_tap_call),
                subtitle: Text(
                  canCall
                      ? l10n.emergencyTag_tap_callHint
                      : l10n.emergencyTag_noCallNumber,
                ),
              ),
              if (choices.primary == EmergencyTagPrimary.call)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: DropdownButtonFormField<EmergencyCallTarget>(
                    key: const Key('emergencyTag_callTarget'),
                    initialValue: choices.callTarget,
                    decoration: InputDecoration(
                      labelText: l10n.emergencyTag_callTarget,
                    ),
                    items: [
                      for (final target in draft.callTargets)
                        DropdownMenuItem(
                          value: target,
                          child: Text(emergencyCallTargetName(l10n, target)),
                        ),
                    ],
                    onChanged: (target) {
                      if (target != null) {
                        onChanged(choices.copyWith(callTarget: target));
                      }
                    },
                  ),
                ),
              if (draft.callUri == null)
                SwitchListTile(
                  key: const Key('emergencyTag_includeText'),
                  title: Text(l10n.emergencyTag_includeText),
                  subtitle: Text(l10n.emergencyTag_includeText_hint),
                  value: choices.includeText,
                  onChanged: (on) =>
                      onChanged(choices.copyWith(includeText: on)),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    l10n.emergencyTag_tap_textNote,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A switch per detail the diver may put on the tag.
class EmergencyTagFieldsSection extends StatelessWidget {
  const EmergencyTagFieldsSection({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final EmergencyTagDraft draft;
  final ValueChanged<EmergencyTagChoices> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                l10n.emergencyTag_include_title,
                style: theme.textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                l10n.emergencyTag_include_nameAlways,
                style: theme.textTheme.bodySmall,
              ),
            ),
            for (final field in EmergencyTagField.values)
              _fieldSwitch(context, field),
          ],
        ),
      ),
    );
  }

  Widget _fieldSwitch(BuildContext context, EmergencyTagField field) {
    final l10n = context.l10n;
    final recorded = draft.available.contains(field);
    return SwitchListTile(
      key: Key('emergencyTag_field_${field.name}'),
      title: Text(emergencyTagFieldName(l10n, field)),
      subtitle: recorded ? null : Text(l10n.emergencyTag_notRecorded),
      value: recorded && draft.choices.fields.contains(field),
      onChanged: recorded
          ? (on) => onChanged(draft.choices.withField(field, on))
          : null,
    );
  }
}

/// The tag's text exactly as written, and how much room it takes.
class EmergencyTagPreview extends StatelessWidget {
  const EmergencyTagPreview({super.key, required this.draft});

  final EmergencyTagDraft draft;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final smallest = draft.smallestTag;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.emergencyTag_preview_title,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                draft.text,
                key: const Key('emergencyTag_previewText'),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.emergencyTag_size(draft.tagBytes)),
            Text(
              smallest == null
                  ? l10n.emergencyTag_size_tooBig
                  : l10n.emergencyTag_size_fits(smallest),
              style: smallest == null
                  ? theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    )
                  : theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
