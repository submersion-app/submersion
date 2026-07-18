import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/forms/form_section.dart';

/// Thin wrapper for the rare dive-form groups (training course, custom
/// fields) that hide behind the AddSectionRow until expanded or populated.
class RareSection extends StatelessWidget {
  const RareSection({
    super.key,
    required this.label,
    required this.icon,
    required this.expanded,
    required this.onToggle,
    required this.summary,
    required this.isEmpty,
    required this.emptyInvitation,
    required this.child,
  });

  final String label;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  final String summary;
  final bool isEmpty;
  final String emptyInvitation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      label: label,
      icon: icon,
      expanded: expanded,
      onToggle: onToggle,
      summary: summary,
      isEmpty: isEmpty,
      emptyInvitation: emptyInvitation,
      children: [child],
    );
  }
}
