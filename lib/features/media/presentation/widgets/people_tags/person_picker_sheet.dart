import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Who the diver picked for a people tag (issue #1745).
sealed class PersonChoice {
  const PersonChoice();
}

/// The diver themself: a Me tag on [diverId].
class MeChoice extends PersonChoice {
  final String diverId;

  const MeChoice(this.diverId);
}

/// A buddy; [isNew] when the picker just created them.
class BuddyChoice extends PersonChoice {
  final Buddy buddy;
  final bool isNew;

  const BuddyChoice(this.buddy, {this.isNew = false});
}

/// Asks who is in a photo or video: Me, the buddies logged on [diveId],
/// then everyone else by name, searchable, or a new buddy from a name.
/// Null when dismissed.
Future<PersonChoice?> showPersonPickerSheet(
  BuildContext context, {
  required String? diveId,
}) {
  return showModalBottomSheet<PersonChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PersonPickerSheet(diveId: diveId),
  );
}

class _PersonPickerSheet extends ConsumerStatefulWidget {
  final String? diveId;

  const _PersonPickerSheet({required this.diveId});

  @override
  ConsumerState<_PersonPickerSheet> createState() => _PersonPickerSheetState();
}

class _PersonPickerSheetState extends ConsumerState<_PersonPickerSheet> {
  static final _log = LoggerService.forClass(_PersonPickerSheet);

  String _query = '';
  bool _addingBuddy = false;
  bool _saving = false;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool _matches(Buddy b) =>
      _query.isEmpty || b.name.toLowerCase().contains(_query.toLowerCase());

  Future<void> _createBuddy(String? diverId) async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    try {
      final created = await ref
          .read(buddyRepositoryProvider)
          .createBuddy(
            Buddy(
              id: '',
              diverId: diverId,
              name: name,
              createdAt: now,
              updatedAt: now,
            ),
          );
      if (mounted) Navigator.of(context).pop(BuddyChoice(created, isNew: true));
    } catch (e, stackTrace) {
      _log.error('Failed to create a buddy', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.media_people_createBuddyFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final options = ref.watch(personPickerOptionsProvider(widget.diveId)).value;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );

    Widget person(Buddy b) => ListTile(
      leading: CircleAvatar(
        child: Text(b.name.isEmpty ? '?' : b.name.characters.first),
      ),
      title: Text(b.name),
      onTap: () => Navigator.of(context).pop(BuddyChoice(b)),
    );

    final meDiverId = options?.meDiverId;
    final onDive = options?.onThisDive.where(_matches).toList() ?? const [];
    final others = options?.everyoneElse.where(_matches).toList() ?? const [];

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.media_people_pickerTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.media_people_searchHint,
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (meDiverId != null &&
                      l10n.media_people_me.toLowerCase().contains(
                        _query.toLowerCase(),
                      ))
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(l10n.media_people_me),
                      onTap: () =>
                          Navigator.of(context).pop(MeChoice(meDiverId)),
                    ),
                  if (onDive.isNotEmpty) ...[
                    heading(l10n.media_people_onThisDive),
                    for (final b in onDive) person(b),
                  ],
                  if (others.isNotEmpty) ...[
                    heading(l10n.media_people_everyoneElse),
                    for (final b in others) person(b),
                  ],
                  if (!_addingBuddy)
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.add)),
                      title: Text(l10n.media_people_newBuddy),
                      onTap: () => setState(() {
                        _addingBuddy = true;
                        _nameController.text = _query;
                      }),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nameController,
                              autofocus: true,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: l10n.media_people_newBuddyName,
                                isDense: true,
                              ),
                              onSubmitted: (_) => _createBuddy(meDiverId),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: _saving
                                ? null
                                : () => _createBuddy(meDiverId),
                            child: Text(l10n.media_people_newBuddyAdd),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
