import 'package:flutter/material.dart';

/// Opens [SubmersionAboutDialog] the way Flutter's showAboutDialog opens its
/// own: on the root navigator, dismissible by tapping outside.
Future<void> showSubmersionAboutDialog({
  required BuildContext context,
  required String applicationName,
  required String applicationVersion,
  required Widget applicationIcon,
  String? builtOn,
  List<Widget> children = const [],
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (_) => SubmersionAboutDialog(
      applicationName: applicationName,
      applicationVersion: applicationVersion,
      applicationIcon: applicationIcon,
      builtOn: builtOn,
      children: children,
    ),
  );
}

/// The "About Submersion" dialog: Flutter's AboutDialog layout, with the
/// build date directly under the version (issue #4365).
///
/// Flutter's dialog has one small line under the version, its legalese slot,
/// and always sets it 18px below the version; a date placed there read as
/// detached from the version it describes. This keeps the rest of that
/// layout as it was, including the space above [children], and puts the date
/// right under the version in the quieter style the About pane uses.
class SubmersionAboutDialog extends StatelessWidget {
  const SubmersionAboutDialog({
    super.key,
    required this.applicationName,
    required this.applicationVersion,
    required this.applicationIcon,
    this.builtOn,
    this.children = const [],
  });

  final String applicationName;
  final String applicationVersion;
  final Widget applicationIcon;

  /// "Built 9 Nov 2026", or null for a build without a date: no line then.
  final String? builtOn;

  /// Shown below the name, version and date, as AboutDialog's children are.
  final List<Widget> children;

  /// The space AboutDialog leaves between its header and [children].
  static const double _headerSeparation = 18;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    String label(String text) => theme.useMaterial3 ? text : text.toUpperCase();

    return AlertDialog(
      scrollable: true,
      content: ListBody(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTheme(data: theme.iconTheme, child: applicationIcon),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ListBody(
                    children: [
                      Text(
                        applicationName,
                        style: theme.textTheme.headlineSmall,
                      ),
                      Text(
                        applicationVersion,
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (builtOn case final date?)
                        Text(
                          date,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: _headerSeparation),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ...children,
        ],
      ),
      actions: [
        TextButton(
          child: Text(label(localizations.viewLicensesButtonLabel)),
          onPressed: () => showLicensePage(
            context: context,
            applicationName: applicationName,
            applicationVersion: applicationVersion,
            applicationIcon: applicationIcon,
          ),
        ),
        TextButton(
          child: Text(label(localizations.closeButtonLabel)),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
