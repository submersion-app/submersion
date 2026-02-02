import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Dialog for quickly creating a dive site from GPS coordinates extracted
/// from a photo.
///
/// Shows the coordinates and allows the user to enter a site name.
/// Returns the created [DiveSite] on success, or null if cancelled.
class QuickSiteFromGpsDialog extends StatefulWidget {
  final double latitude;
  final double longitude;

  const QuickSiteFromGpsDialog({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  /// Show the dialog and return the created site, or null if cancelled.
  static Future<DiveSite?> show(
    BuildContext context, {
    required double latitude,
    required double longitude,
  }) {
    return showDialog<DiveSite>(
      context: context,
      builder: (context) =>
          QuickSiteFromGpsDialog(latitude: latitude, longitude: longitude),
    );
  }

  @override
  State<QuickSiteFromGpsDialog> createState() => _QuickSiteFromGpsDialogState();
}

class _QuickSiteFromGpsDialogState extends State<QuickSiteFromGpsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _uuid = const Uuid();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_location_alt, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Text('Create Dive Site'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create a new dive site using GPS coordinates from your photo.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.latitude.toStringAsFixed(5)}, '
                      '${widget.longitude.toStringAsFixed(5)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Site Name',
                hintText: 'Enter a name for this site',
                prefixIcon: Icon(Icons.edit),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a site name';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _createSite, child: const Text('Create Site')),
      ],
    );
  }

  void _createSite() {
    if (!_formKey.currentState!.validate()) return;

    final site = DiveSite(
      id: _uuid.v4(),
      name: _nameController.text.trim(),
      location: GeoPoint(widget.latitude, widget.longitude),
    );

    Navigator.of(context).pop(site);
  }
}
