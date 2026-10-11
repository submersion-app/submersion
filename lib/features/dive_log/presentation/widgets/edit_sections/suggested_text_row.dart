import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_text_suggestion_field.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_text_suggestion_providers.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

/// A free-text dive form row that suggests the active diver's earlier
/// values of [field] (#3229): operator, boat, captain, surface conditions.
class SuggestedTextRow extends ConsumerWidget {
  const SuggestedTextRow({
    super.key,
    required this.label,
    required this.controller,
    required this.field,
    this.capitalization = TextCapitalization.words,
  });

  final String label;
  final TextEditingController controller;
  final DiveTextSuggestionField field;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SuggestionFormRow(
      label: label,
      controller: controller,
      suggestions:
          ref.watch(diveTextSuggestionsProvider(field)).value ?? const [],
      textCapitalization: capitalization,
    );
  }
}
