import 'package:flutter/material.dart';

/// One Set up this device step's layout (issue #3482, spec 6.4): a title,
/// a sentence or two, the controls, and a bottom row with a quiet back
/// action and a primary button that says what it does. Not a [Scaffold]: the
/// host (a Settings page now, the first-run wizard later) supplies that.
class SetUpStepScaffold extends StatelessWidget {
  const SetUpStepScaffold({
    super.key,
    required this.title,
    this.intro,
    required this.children,
    required this.backLabel,
    required this.onBack,
    required this.primaryLabel,
    required this.onPrimary,
    this.busy = false,
    this.secondary,
  });

  final String title;
  final String? intro;
  final List<Widget> children;
  final String backLabel;
  final VoidCallback onBack;
  final String primaryLabel;

  /// Null disables the primary button (the step cannot finish yet).
  final VoidCallback? onPrimary;

  /// The primary action is running: its button shows progress and every
  /// action waits.
  final bool busy;

  /// A second action beside the primary one, such as Not now or Skip.
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(title, style: textTheme.headlineSmall),
              if (intro != null) ...[
                const SizedBox(height: 8),
                Text(intro!, style: textTheme.bodyMedium),
              ],
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              TextButton(
                onPressed: busy ? null : onBack,
                child: Text(backLabel),
              ),
              const SizedBox(width: 8),
              // A long translated label wraps the buttons onto a second
              // line rather than overflowing the row.
              Expanded(
                child: OverflowBar(
                  alignment: MainAxisAlignment.end,
                  overflowAlignment: OverflowBarAlignment.end,
                  spacing: 8,
                  overflowSpacing: 8,
                  children: [
                    ?secondary,
                    FilledButton(
                      onPressed: busy ? null : onPrimary,
                      child: busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(primaryLabel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
