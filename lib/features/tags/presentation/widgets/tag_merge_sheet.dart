import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class TagMergeSheet extends ConsumerStatefulWidget {
  final List<TagStatistic> selectedStats;

  const TagMergeSheet({super.key, required this.selectedStats});

  @override
  ConsumerState<TagMergeSheet> createState() => _TagMergeSheetState();
}

class _TagMergeSheetState extends ConsumerState<TagMergeSheet> {
  late final TextEditingController _nameController;
  late String _selectedColor;
  late String _selectedNameFromTag;
  int? _totalAffectedDives;
  bool _isMerging = false;

  List<TagStatistic> get _sortedStats {
    final sorted = [...widget.selectedStats];
    sorted.sort((a, b) => b.diveCount.compareTo(a.diveCount));
    return sorted;
  }

  @override
  void initState() {
    super.initState();

    final sorted = _sortedStats;
    final mostUsed = sorted.first;

    _nameController = TextEditingController(text: mostUsed.tag.name);
    _selectedColor = mostUsed.tag.colorHex ?? TagColors.predefined.first;
    _selectedNameFromTag = mostUsed.tag.id;

    _loadAffectedDives();
  }

  Future<void> _loadAffectedDives() async {
    final repository = ref.read(tagRepositoryProvider);
    final tagIds = widget.selectedStats.map((s) => s.tag.id).toList();
    final count = await repository.getMergedDiveCount(tagIds);

    if (mounted) {
      setState(() {
        _totalAffectedDives = count;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _performMerge() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isMerging = true;
    });

    try {
      final survivingId = _selectedNameFromTag;
      final sourceIds = widget.selectedStats
          .map((s) => s.tag.id)
          .where((id) => id != survivingId)
          .toList();

      await ref
          .read(tagListNotifierProvider.notifier)
          .mergeTags(
            sourceTagIds: sourceIds,
            survivingTagId: survivingId,
            name: name,
            colorHex: _selectedColor,
          );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isMerging = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to merge tags: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sorted = _sortedStats;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              context.l10n.tags_manage_mergeTitle(widget.selectedStats.length),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Resulting name label and text field
            Text(
              context.l10n.tags_manage_mergeResultName,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: context.l10n.tags_manage_nameLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Keep name from radio buttons
            Text(
              context.l10n.tags_manage_mergeKeepFrom,
              style: theme.textTheme.titleSmall,
            ),
            RadioGroup<String>(
              groupValue: _selectedNameFromTag,
              onChanged: (value) {
                if (value == null) return;
                final stat = sorted.firstWhere((s) => s.tag.id == value);
                setState(() {
                  _selectedNameFromTag = value;
                  _nameController.text = stat.tag.name;
                  _selectedColor =
                      stat.tag.colorHex ?? TagColors.predefined.first;
                });
              },
              child: Column(
                children: sorted
                    .map(
                      (stat) => RadioListTile<String>(
                        value: stat.tag.id,
                        title: Text(stat.tag.name),
                        subtitle: Text(
                          context.l10n.tags_manage_diveCount(stat.diveCount),
                        ),
                        secondary: CircleAvatar(
                          radius: 12,
                          backgroundColor: stat.tag.color,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Color picker
            Text(
              context.l10n.tags_manage_colorLabel,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TagColorPicker(
              selectedColor: _selectedColor,
              onColorSelected: (color) {
                setState(() {
                  _selectedColor = color;
                });
              },
            ),
            const SizedBox(height: 16),

            // Affected dives summary
            if (_totalAffectedDives != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  context.l10n.tags_manage_mergeAffectedDives(
                    _totalAffectedDives!,
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isMerging ? null : () => Navigator.pop(context),
                  child: Text(context.l10n.common_action_cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isMerging ? null : _performMerge,
                  child: _isMerging
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.l10n.tags_manage_mergeAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
