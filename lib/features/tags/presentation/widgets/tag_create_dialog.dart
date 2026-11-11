import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_color_picker.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_dialog_save.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_scope_checklist.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens Manage Tags' Create tag dialog.
Future<void> showTagCreateDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const TagCreateDialog());

/// Manage Tags' Create tag dialog (issue #4407). A new tag starts offered
/// everywhere. A name another tag already holds reuses that tag, so until
/// the user changes them the scope boxes and the colour mirror it, and Save
/// adds only what is shown: never less than it has (Save cannot narrow),
/// and nothing it did not choose.
class TagCreateDialog extends ConsumerStatefulWidget {
  const TagCreateDialog({super.key});

  @override
  ConsumerState<TagCreateDialog> createState() => _TagCreateDialogState();
}

class _TagCreateDialogState extends ConsumerState<TagCreateDialog> {
  static const _uuid = Uuid();
  static final _defaultColor = TagColors.predefined.first;

  final _controller = TextEditingController();

  /// The tag already holding the typed name, if any.
  Tag? _existing;

  /// What the boxes show: the user's picks plus [_existing]'s own scopes.
  Set<TagScope> _scopes = TagScope.everywhere;

  /// The user's own ticks once they change a box, kept apart from a matched
  /// tag's locked scopes so a name edit drops those again. Null until then,
  /// while the boxes follow the name.
  Set<TagScope>? _picked;

  /// The id of the tag [_picked] was made against, null for a new name.
  /// Picks against a matched tag add uses to it, so they lapse once the
  /// name stops matching that tag; picks for a new name are the user's
  /// choice for it and stay.
  String? _pickedFor;

  String _color = _defaultColor;

  /// Whether the user picked [_color]. Until then it follows the name.
  bool _colorPicked = false;

  bool _saving = false;
  bool _failed = false;

  Set<TagScope> get _held => _existing?.scopes ?? const {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The diver's tag named [text], matched as the repository matches names:
  /// trimmed and ignoring case. Null for no match.
  ///
  /// The tag list drops its value while it reloads (after any add), so the
  /// page's statistics, which keep theirs, stand in meanwhile.
  Tag? _tagNamed(String text) {
    final wanted = text.trim().toLowerCase();
    if (wanted.isEmpty) return null;
    final tags =
        ref.read(tagListNotifierProvider).value ??
        [
          for (final stat
              in ref.read(tagStatisticsProvider).value ??
                  const <TagStatistic>[])
            stat.tag,
        ];
    for (final tag in tags) {
      if (tag.name.trim().toLowerCase() == wanted) return tag;
    }
    return null;
  }

  void _onNameChanged(String text) => setState(() {
    _existing = _tagNamed(text);
    if (_pickedFor != null && _pickedFor != _existing?.id) {
      _picked = null;
      _pickedFor = null;
    }
    _scopes = _picked == null
        ? (_existing?.scopes ?? TagScope.everywhere)
        : _picked!.union(_held);
    if (!_colorPicked) _color = _existing?.colorHex ?? _defaultColor;
  });

  // Applied to the current set, never replaced in place, so a Save already
  // under way keeps its own.
  void _onToggle(TagScope scope, bool on) => setState(() {
    if (_picked == null) _pickedFor = _existing?.id;
    final picked = _picked ?? _scopes.difference(_held);
    _picked = on ? picked.union({scope}) : picked.difference({scope});
    _scopes = _picked!.union(_held);
  });

  Future<void> _save() async {
    // A second tap in the same frame still reaches here: the disabled
    // button is only built next frame.
    if (_saving) return;
    final name = _controller.text.trim();
    if (name.isEmpty || _scopes.isEmpty) return;
    final notifier = ref.read(tagListNotifierProvider.notifier);
    final newTag = Tag.create(
      id: _uuid.v4(),
      name: name,
      colorHex: _color,
      scopes: _scopes,
    );
    // A tag already holding the name is widened to what the user ticked,
    // and recoloured only if they picked a colour: untouched defaults
    // change nothing, even if the tag list had not loaded to match it.
    final widen = _picked == null ? const <TagScope>{} : _scopes;
    final color = _color;
    final colorPicked = _colorPicked;
    await saveFromTagDialog(
      context,
      setSaving: (v) => setState(() => _saving = v),
      setFailed: (v) => setState(() => _failed = v),
      save: () async {
        final saved = await notifier.addTag(newTag, widenExistingTo: widen);
        // Colour alone: rewriting the whole tag would reset scopes widened
        // since [saved] was read, and remove their links.
        if (colorPicked && saved.colorHex != color) {
          await notifier.setTagColor(saved.id, color);
        }
        return true;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // The list can load or change after the name was typed (its first load,
    // or a sync), so the name is matched again and the boxes keep mirroring
    // the tag that holds it. Not while saving: the save's own reload would
    // show the new tag as one that already existed.
    ref.listen(tagListNotifierProvider, (_, next) {
      if (next.hasValue && !_saving) _onNameChanged(_controller.text);
    });
    final l10n = context.l10n;
    return PopScope(
      // The barrier, Back and Escape all ask before popping. A save in
      // flight says no, so a failure still has its dialog to report into.
      canPop: !_saving,
      child: AlertDialog(
        title: Text(l10n.tags_manage_createTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.tags_manage_nameLabel,
                  border: const OutlineInputBorder(),
                ),
                onChanged: _onNameChanged,
              ),
              const SizedBox(height: 16),
              Text(l10n.tags_manage_colorLabel),
              const SizedBox(height: 8),
              TagColorPicker(
                selectedColor: _color,
                // Each swatch previews this tag by name, so the colour
                // being chosen is the colour that will be seen.
                nameController: _controller,
                onColorSelected: (color) => setState(() {
                  _color = color;
                  _colorPicked = true;
                }),
              ),
              const SizedBox(height: 8),
              TagScopeChecklist(
                scopes: _scopes,
                // Save never narrows an existing tag (the edit dialog
                // does), so its own scopes cannot be unticked.
                locked: _held,
                onToggle: _onToggle,
              ),
              if (_existing != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.tags_manage_existingTagNote,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (_failed) const TagSaveErrorLine(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(l10n.common_action_cancel),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.common_action_save),
          ),
        ],
      ),
    );
  }
}
