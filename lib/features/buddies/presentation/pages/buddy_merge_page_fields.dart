part of 'buddy_merge_page.dart';

/// The merge form's fields: each text value with the buddy it came from and
/// a button to cycle to the next buddy's.
extension _BuddyMergeFields on _BuddyMergeFormState {
  Widget _cycleButton(VoidCallback onPressed) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      tooltip: context.l10n.buddies_edit_merge_fieldSourceCycleTooltip,
      icon: const Icon(Icons.sync_alt, size: 18),
      iconSize: 18,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: const EdgeInsets.all(6),
      style: IconButton.styleFrom(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// [decoration] for the text value [key], naming the buddy its value came
  /// from, with the cycle button, when the buddies hold more than one.
  InputDecoration _cycled({
    required String key,
    required InputDecoration decoration,
  }) {
    final candidates = _merge.textCandidates[key];
    if (candidates == null || candidates.length < 2) return decoration;

    final currentIndex = _merge.fieldIndices[key] ?? 0;
    final current = candidates[currentIndex];
    final controller = switch (key) {
      'email' => _emailController,
      'phone' => _phoneController,
      'country' => _countryController,
      'notes' => _notesController,
      _ => _nameController,
    };

    return decoration.copyWith(
      helperText: context.l10n.buddies_edit_merge_fieldSourceLabel(
        current.buddyName,
        currentIndex + 1,
        candidates.length,
      ),
      suffixIcon: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: _cycleButton(
          () =>
              _update(() => _merge.cycleTextField(key, controller: controller)),
        ),
      ),
      suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 36),
    );
  }

  Widget _formBody(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The photo the survivor keeps: the first buddy's that has one.
            Center(
              child: ProfileAvatar(
                photo: _merge.mergedPhoto,
                initials: Buddy.initialsOf(_nameController.text),
                radius: 50,
                textStyle: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: _cycled(
                key: 'name',
                decoration: InputDecoration(
                  labelText: l10n.buddies_field_nameRequired,
                  prefixIcon: const Icon(Icons.person),
                  hintText: l10n.buddies_field_nameHint,
                ),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) => value == null || value.trim().isEmpty
                  ? l10n.buddies_validation_nameRequired
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: _cycled(
                key: 'email',
                decoration: InputDecoration(
                  labelText: l10n.buddies_field_email,
                  prefixIcon: const Icon(Icons.email),
                  hintText: l10n.buddies_field_emailHint,
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final emailRegex = RegExp(
                    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                  );
                  if (!emailRegex.hasMatch(value)) {
                    return l10n.buddies_validation_emailInvalid;
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: _cycled(
                key: 'phone',
                decoration: InputDecoration(
                  labelText: l10n.buddies_field_phone,
                  prefixIcon: const Icon(Icons.phone),
                  hintText: l10n.buddies_field_phoneHint,
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _socialController,
              decoration: InputDecoration(
                labelText: l10n.buddyShare_social,
                prefixIcon: const Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 16),
            BuddyCountryField(
              controller: _countryController,
              suggestions:
                  ref.watch(buddyCountrySuggestionsProvider).value ?? const [],
              decoration: _cycled(
                key: 'country',
                decoration: InputDecoration(
                  labelText: l10n.buddies_field_country,
                  prefixIcon: const Icon(Icons.public),
                  hintText: l10n.buddies_field_countryHint,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Starts on only if every merged buddy has it on (issue #3624).
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.buddies_field_excludedFromRankings),
              subtitle: Text(l10n.buddies_field_excludedFromRankingsHint),
              value: _excludedFromRankings,
              onChanged: (value) =>
                  _update(() => _excludedFromRankings = value),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.buddies_section_notes,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            MarkdownNotesField(
              controller: _notesController,
              decoration: _cycled(
                key: 'notes',
                decoration: InputDecoration(
                  labelText: l10n.buddies_field_notes,
                  prefixIcon: const Icon(Icons.notes),
                  hintText: l10n.buddies_field_notesHint,
                  alignLabelWithHint: true,
                ),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.buddies_edit_merge_title),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(l10n.common_action_cancel),
            ),
          ],
        ),
      ),
    );
  }
}
